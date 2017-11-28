#!/bin/sh

libs=":"
main_configs=
http_configs=

function debug () {
	if [ -n "$DEBUG" ]
	then
		echo "$@"
	fi
}

# Arguments can be provided multiple times, in which case they're appended in a
# list, separated by colon.
while getopts 'dI:m:s:h' OPTION
do
	case "$OPTION" in
	d)
		DEBUG=1
		;;
	I)
		debug "include $OPTARG"
		libs="${libs}${libs:+:}$OPTARG"
		;;
	m)
		debug "main-config $OPTARG"
		main_configs="${main_configs}${main_configs:+:}$OPTARG"
		;;
	s)
		debug "http-config $OPTARG"
		http_configs="${http_configs}${http_configs:+:}$OPTARG"
		;;
	h)
		echo "script usage: $(basename $0) [-I libdir] [-m main-config] [-s http-config] [-h]" >&2
		exit 0
		;;
	esac
done
shift $(($OPTIND - 1))

debug "main-configs $main_configs"
debug "http-configs $http_configs"
debug "files $*"


