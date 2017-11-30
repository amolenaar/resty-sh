docker run -t -v $(pwd):/work -w /work --entrypoint sh openresty/openresty:1.11.2.3-alpine resty.sh dummy.lua
