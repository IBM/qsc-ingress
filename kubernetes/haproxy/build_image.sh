#!/bin/bash

work_dir=$(pwd)
image_name=ingress_haproxy_qsc
controller_version=v1.4.7

cd "$work_dir" || exit 1
rm -rf kubernetes-ingress
git clone --depth 1 --branch $controller_version https://github.com/haproxytech/kubernetes-ingress.git

# Use HAproxy v2.2.2 instead of 2.1
sed -i 's#FROM haproxytech/haproxy-alpine:2.1#FROM haproxytech/haproxy-alpine:2.2.2#' $work_dir/kubernetes-ingress/build/Dockerfile

# Have some shortcuts to files
CFG_FILE=$work_dir/kubernetes-ingress/fs/etc/haproxy/haproxy.cfg
QSC_DOCKERFILE=$work_dir/kubernetes-ingress/build/Dockerfile_qsc

# Changes in the Dockerfile: Add the qsc-enablement build stage ...
cat "$work_dir"/Dockerfile.qsc_openssl "$work_dir"/kubernetes-ingress/build/Dockerfile > "$QSC_DOCKERFILE"
# ...and use HAproxy v2.2.2 instead of 2.1...
sed -i 's#FROM haproxytech/haproxy-alpine:2.1#FROM haproxytech/haproxy-alpine:2.2.2#' "$QSC_DOCKERFILE"
# ...and make sure the qsc enabled OpenSSL libs are copied to replace the non-QSC libs...
sed -i '/ENTRYPOINT.*/i # We override the OpenSSL libs with their QSC-enabled versions' "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i COPY --from=qsc_openssl /thirdparty/OQSopenssl/libcrypto.so.1.1 /thirdparty/OQSopenssl/libssl.so.1.1 /usr/local/lib/' "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i COPY --from=qsc_openssl /thirdparty/OQSopenssl/libcrypto.so.1.1 /thirdparty/OQSopenssl/libssl.so.1.1 /usr/lib/' "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i COPY --from=qsc_openssl /thirdparty/OQSopenssl/libcrypto.so.1.1 /thirdparty/OQSopenssl/libssl.so.1.1 /lib/' "$QSC_DOCKERFILE"

# Changes in the HAproxy config file: Replace the default bind ciphers and add default curves...
#HAPROXY_DEFAULT_CURVES="p256_kyber512:prime256v1:secp384r1:secp521r1:X25519:X448:kyber512:kyber768:kyber1024:p384_kyber768:p521_kyber1024"
HAPROXY_DEFAULT_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"
sed -i "s#ssl-default-bind-ciphers.*#ssl-default-bind-ciphers $HAPROXY_DEFAULT_CIPHERS#" "$CFG_FILE"
# ...and don't allow TLSv1.1 (read: only TLSv1.2 & TLSv1.3 are supported, of which only TLSv1.3 supports QSC)...
sed -i 's#ssl-default-bind-options.*#ssl-default-bind-options no-tls-tickets no-sslv3 no-tlsv10 no-tlsv11#' "$CFG_FILE"

# Additions to the Dockerfile: Make sure that some default values for HAPROXY_DEFAULT_CIPHERS and  HAPROXY_DEFAULT_CURVES  are defined...
sed -i '/ENTRYPOINT.*/i \\n# We set the ENV variable for HAPROXY_DEFAULT_CIPHERS by default to only use (a selection of) TLSv1.2 & TLSv1.3 ciphers' "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i # (see here: https://wiki.mozilla.org/Security/Server_Side_TLS#Recommended_configurations )'  "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i ENV HAPROXY_DEFAULT_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"' "$QSC_DOCKERFILE"
sed -i '/ENTRYPOINT.*/i \\n# Get some insights\nRUN haproxy -vv\n\n' "$QSC_DOCKERFILE"

# build the image
cd "$work_dir"/kubernetes-ingress || exit 1
sudo docker build -f build/Dockerfile_qsc -t $image_name:$controller_version .