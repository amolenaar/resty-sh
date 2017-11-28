#!/bin/sh


while getopts 'I:m:s:h' OPTION
do
	case "$OPTION" in
	I)
		echo "include $OPTARG"
		libs="${libs}${libs:+:}$OPTARG"
		;;
	m)
		echo "main-config $OPTARG"
		main_configs="${main_configs}${main_configs:+:}$OPTARG"
		;;
	s)
		echo "http-config $OPTARG"
		http_configs="${http_configs}${http_configs:+:}$OPTARG"
		;;
	h)
		echo "script usage: $(basename $0) [-I libdir] [-m main-config] [-s http-config] [-h]" >&2
		exit 0
		;;
	esac
done

echo "main-config $main_configs"
echo "http-config $http_configs"
echo "files $*"
