# resty-sh

Shell script based alternative to
[resty-cli](https://github.com/openresty/resty-cli), the fancy command-line
utilities for OpenResty.

This is a deviation on the official resty CLI:

 * It's written in shell script, so does not require Perl
 * outputs are not redirected, so you can actually test nested server calls
 * Not all features, such as Valgrind support
 * Only allows for execution of files
 * TODO: Adds test aggregation


Description
===========

(partially copied from resty-cli)

The `resty.sh` command-line utility can be used to run OpenResty's Lua scripts
directly off the command-line just like the `lua` or `luajit` command-line
utilities. It can be used to create various command-line utilities using
OpenResty Lua.

This tool works by creating a head-less `nginx` instance,
disabling [daemon](http://nginx.org/en/docs/ngx_core_module.html#daemon), [master_process](http://nginx.org/en/docs/ngx_core_module.html#master_process), [access_log](http://nginx.org/en/docs/http/ngx_http_log_module.html#access_log), and other things it does
not need. No `server {}` is configured hence *no* listening sockets
are involved at all.

The Lua code is initiated by the [init_worker_by_lua](https://github.com/openresty/lua-nginx-module#init_worker_by_lua)
directive and run in the context of [ngx.timer](https://github.com/openresty/lua-nginx-module#ngxtimerat) callback. So all of
[ngx_lua](https://github.com/openresty/lua-nginx-module#readme)'s Lua APIs available in the [ngx.timer](https://github.com/openresty/lua-nginx-module#ngxtimerat) callback context are
also available in the `resty` utility. We may remove some of the
remaining limitations in the future though.

