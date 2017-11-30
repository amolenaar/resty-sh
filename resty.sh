#!/bin/sh

set -e

VERSION=1

libs=":"
main_includes=
http_includes=
nameserver=$(cat /etc/resolv.conf | grep nameserver | head -1 | cut -f2 -d' ')
nginx_path=nginx
nginx_conf="${TMPDIR:-/tmp}/nginx-rest-sh-$$.conf"
errlog_level=info

function die() {
	echo "$@" >&2
	exit 1
}

function debug () {
	[ -n "$DEBUG" ] && echo "DEBUG: $@"
}

function abspath() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# Arguments can be provided multiple times, in which case they're appended in a
# list, separated by colon.
while getopts 'VdI:m:s:h' OPTION
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
	I)
		libs="${libs}${libs:+:}$OPTARG"
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
	h)
		echo "script usage: $(basename $0) [-I libdir] [-m main-config] [-s http-config] [-n nginx] [-h] file.lua" >&2
		exit 0
		;;
	esac
done
shift $(($OPTIND - 1))

# Append default path (';;')
libs="${libs};;"

debug "main-includes $main_includes"
debug "http-includes $http_includes"
debug "nginx config  $nginx_conf"
debug "test files    $*"

#File in lua block:

#	local fname = $quoted_luafile
#	local f = assert(io.open(fname, "r"))
#	local chunk = f:read("*a")
#	local file_gen = assert(loadstring(chunk, $chunk_name))

filename=$1
[ -f $filename ] || die "Could not find Lua file \"$filename\""

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

io_redirect=$(cat << EOF
	ngx.print = output
	ngx.say = function (...)
		local ok, err = output(...)
		if ok then
			return output("\\n")
		end
		return ok, err
	end
	print = ngx.say
EOF
)

cat > "${nginx_conf}" << EOF
daemon off;
master_process off;
worker_processes 1;
pid logs/nginx.pid;

error_log stderr $errlog_level;
#error_log stderr debug;

events {
    worker_connections 64;
}

$main_includes

http {
    access_log off;
    lua_socket_log_errors off;
    resolver $nameserver;
    lua_regex_cache_max_entries 40960;
    lua_package_path "$libs";
    $http_includes
    init_by_lua_block {
        local stdout = io.stdout
        local ngx_null = ngx.null
        local maxn = table.maxn
        local unpack = unpack
        local concat = table.concat

        local expand_table
        function expand_table(src, inplace)
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

        local function output(...)
            local args = {...}

            return stdout:write(expand_table(args, true))
        end

        ngx.flush = function (...) return stdout:flush() end
        -- we cannot close stdout here due to a bug in Lua:
        ngx.eof = function (...) return true end
    }

    init_worker_by_lua_block {
        local exit = os.exit
        local stderr = io.stderr
        local ffi = require "ffi"

        local function handle_err(err)
            if err then
                err = string.gsub(err, "^init_worker_by_lua:%d+: ", "")
                stderr:write("ERROR: ", err, "\\n")
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
            -- print("calling timer.at...")
            local ok, err = ngx.timer.at(0, function ()
                -- io.stderr:write("timer firing")
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
            -- print("timer created")
        end)

        if not ok then
            return handle_err(err)
        end
    }
}
EOF

"$nginx_path" -c "$nginx_conf"

