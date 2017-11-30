# Resty-sh

Shell script based alternative to
[resty-cli](https://github.com/openresty/resty-cli), the fancy command-line
utility for OpenResty.

This is a deviation on the official resty CLI:

 * It's written in shell script, so does not require Perl.
 * It's optimized to run unit tests in an Nginx container.
 * Outputs are not redirected, so you can actually test nested server calls.
 * Not all features, such as Valgrind, are support.
 * Only allows for execution of files.
 * TODO: Adds test aggregation.


Description
===========

(copied from resty-cli)

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



Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2014-2016, by Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, CloudFlare Inc.
Copyright (C) 2014-2016, by Guanlan Dai <guanlan@cloudflare.com>, CloudFlare Inc.
Copyright (C) 2017, by Arjan Molenaar <gaphor@gmail.com>, Xebia b.v.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


