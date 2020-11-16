#!/bin/bash
sed -i  s:\</body\>:\<p\>\<em\>\<b\>Pod\ \namespace\</b\>\ \ ${POD_NAMESPACE}\</em\>\</p\>\\n\<p\>\<em\>\<b\>Pod\ \name\</b\>\ \ ${POD_NAME}\</em\>\</p\>\\n\</body\>:g /usr/share/nginx/html/index.html
./docker-entrypoint.sh nginx -g "daemon off;"