#!/bin/sh

# Stop this script whenever something goes wrong -- returns non-0 exit status
set -e

VERSION=1

libs=""
main_includes=
http_includes=
io_redirect=
nameserver=$(cat /etc/resolv.conf | grep nameserver | head -1 | cut -f2 -d' ')
nginx_path=nginx
nginx_conf="${TMPDIR:-/tmp}/nginx-rest-sh-$$.conf"
# One of debug, info, notice, warn, error, crit, alert, or emerg
errlog_level=warn

function die() {
	echo "$@" >&2
	exit 1
}

function usage() {
	cat << EOF >&2
usage: $(basename $0) [-I libdir] [-m main-config] [-s http-config] [-n nginx]
	[-l log-level] [-r] [-h] file.lua
  -h			This help message
  -I libdir		Include library directory in path
  -m main-config	Include extra Nginx configuration at top level
  -s http-config	Include extra Nginx configuration in the http block
  -n nginx		Point to nginx binary, in case it's not on the path
  -l log-level		Change log level to one of
			debug, info, notice, warn, error, crit, alert, or emerg
  -r			Change configuration to print everything to the console
EOF
}

function debug () {
	[ -n "$DEBUG" ] && echo "DEBUG: $@" || true
}

function abspath() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# Arguments can be provided multiple times, in which case they're appended in a
# list, separated by colon.
while getopts 'Vdl:I:m:s:h' OPTION
do
	case "$OPTION" in
	V)
		echo "resty.sh $VERSION"
		$nginx_path -V
		exit 0
		;;
	d)
		DEBUG=1
		errlog_level=debug
		;;
	l)
		errlog_level=$OPTARG
		;;
	I)
		libs="${libs}${libs:+;}$OPTARG/?.lua"
		;;
	m)
                [ -f $OPTARG ] || die "Could not find file main include file \"$OPTARG\""
		main_includes="${main_includes} include \"$(abspath $OPTARG)\";"
		;;
	s)
                [ -f $OPTARG ] || die "Could not find file http include file \"$OPTARG\""
		http_includes="${http_includes} include \"$(abspath $OPTARG)\";"
		;;
	n)
                [ -f $OPTARG ] || die "Couls not find nginx binary at \"$OPTARG\""
		nginx_path="$(abspath $OPTARG)"
		;;
        r)
		io_redirect="ngx.print, ngx.say = output, outputln"
		;;
	h)
		usage
		exit 0
		;;
	esac
done
shift $(($OPTIND - 1))

# Append default path (';;')
libs="${libs};;"

debug "main-includes $main_includes"
debug "http-includes $http_includes"
debug "nginx binary  $nginx_path"
debug "nginx config  $nginx_conf"
debug "test files    $*"

filename=$1
[ -f "$filename" ] || die "Could not find Lua file \"$filename\""

loader=$(cat << EOF
    local gen
    do
        local fname = "$filename"
        local f = assert(io.open(fname, "r"))
        local chunk = f:read("*a")
        local file_gen = assert(loadstring(chunk, "$filename"))
        gen = function()
            if file_gen then file_gen() end
        end
    end
EOF
)

cat > "${nginx_conf}" << EOF
daemon off;
master_process off;
worker_processes 1;
pid logs/nginx.pid;

error_log stdout $errlog_level;

events {
    worker_connections 64;
}

$main_includes

http {
    access_log off;
    resolver $nameserver;

    lua_package_path "$libs";

    $http_includes

    init_by_lua_block {
        local ngx_null = ngx.null
        local maxn = table.maxn
        local unpack = unpack
        local concat = table.concat

        local function expand_table(src, inplace)
            local n = maxn(src)
            local dst = inplace and src or {}
            for i = 1, n do
                local arg = src[i]
                local typ = type(arg)
                if arg == nil then
                    dst[i] = "nil"

                elseif typ == "boolean" then
                    if arg then
                        dst[i] = "true"
                    else
                        dst[i] = "false"
                    end

                elseif arg == ngx_null then
                    dst[i] = "null"

                elseif typ == "table" then
                    dst[i] = expand_table(arg, false)

                elseif typ ~= "string" then
                    dst[i] = tostring(arg)

                else
                    dst[i] = arg
                end
            end
            return concat(dst)
        end

        print = function (...)
            return io.stdout:write(expand_table({...}, true).."\n")
        end

        -- we cannot close stdout here due to a bug in Lua:
        -- ngx.eof = function (...) return true end
    }

    init_worker_by_lua_block {
        local exit = os.exit
        local ffi = require "ffi"

	$io_redirect

        local function handle_err(err)
            if err then
                err = string.gsub(err, "^init_worker_by_lua:%d+: ", "")
                ngx.log(ngx.ERR, err)
            end
            return exit(1)
        end

        local ok, err = pcall(function ()
            if not ngx.config
               or not ngx.config.ngx_lua_version
               or ngx.config.ngx_lua_version < 10009
            then
                error("at least ngx_lua 0.10.9 is required")
            end

            local signal_graceful_exit =
                require("ngx.process").signal_graceful_exit
            if not signal_graceful_exit then
                error("lua-resty-core library is too old; "
                      .. "missing the signal_graceful_exit() function "
                      .. "in ngx.process")
            end

            $loader

            local ok, err = ngx.timer.at(0, function ()
                local ok, err = xpcall(gen, function (err)
                    -- level 3: we skip this function and the
                    -- error() call itself in our stacktrace
                    local trace = debug.traceback(err, 3)
                    return handle_err(trace)
                end)
                if not ok then
                    return handle_err(err)
                end
                if ffi.abi("win") then
                    return exit(0)
                end
                signal_graceful_exit()
            end)
            if not ok then
                return handle_err(err)
            end
        end)

        if not ok then
            return handle_err(err)
        end
    }
}
EOF

"$nginx_path" -c "$nginx_conf"

# TODO: do something with test aggregation

