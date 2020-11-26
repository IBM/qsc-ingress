
# Enable the choice to override the ingress-controller base image, e.g. when having it built from sources locally
#ARG BASE_IMAGE=us.gcr.io/k8s-artifacts-prod/ingress-nginx/controller:v0.34.1@sha256:0e072dddd1f7f8fc8909a2ca6f65e76c5f0d2fcfb8be47935ae3457e8bbceb20
ARG BASE_IMAGE=k8s.gcr.io/ingress-nginx/controller:v0.40.2@sha256:46ba23c3fbaafd9e5bd01ea85b2f921d9f2217be082580edc22e6c704a83f02f
#==============================================================================
# First stage build

# Build OQS QSC OpenSSL
FROM alpine:3.11 as qsc_openssl_lib_builder

LABEL stage=builder

USER root

# -----------------------------------------------------
# ==> VERSION CONTROL via ARG

# OpenSSL (see here: https://www.openssl.org/source/)
ARG OpenSSL_version=openssl-1.1.1g
# PGP KeyID Matt Caswell & Richard Levitte (see here: https://www.openssl.org/community/omc.html)
ARG OpenSSL_KeyID1=8657ABB260F056B1E5190839D9C4D26D0E604491
ARG OpenSSL_KeyID2=7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C

# Open Quantum Safe stuff
# lib oqs related
ARG OQS_liboqs_Branch=master
ARG OQS_liboqs_Commit=9ed69af2c5c8923ea2674558dd1d37f5d498ee51
# OQS OpenSSL related
ARG OQS_OpenSSL_Branch=OQS-OpenSSL_1_1_1-stable
ARG OQS_OpenSSL_Commit=824d0cf7be97f9ab717e4bc92bbce2759ca7c26c
# Github verification key 
ARG OQS_KeyID_github=4AEE18F83AFDEB23

# -----------------------------------------------------
# ==> PREREQUISITES USED DURING BUILD PROCESS

RUN apk update && apk upgrade && \
    apk add linux-headers build-base gnupg perl curl  \
            libcurl grpc gcompat git bash zlib zlib-dev dpkg cmake ninja doxygen && \
    mkdir /thirdparty && mkdir /thirdparty/install && \
    mkdir /thirdparty/install/openssl_oqs

# improve compilation times
ARG CORES=16

# -----------------------------------------------------
# ==> LOAD VERIFICATION KEYS
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys $OpenSSL_KeyID1 && \
    gpg --keyserver pool.sks-keyservers.net --recv-keys $OpenSSL_KeyID2


# ----------------SYSTEM_UPDATES-----------------------
# -----------------------------------------------------
# ==> OPENSSL BUILD FROM SOURCE (for SYSTEM)
RUN cd /thirdparty &&  \
    wget https://www.openssl.org/source/${OpenSSL_version}.tar.gz && \
    wget https://www.openssl.org/source/${OpenSSL_version}.tar.gz.asc && \
        gpg --verify $OpenSSL_version.tar.gz.asc ${OpenSSL_version}.tar.gz && \
        tar -xzf ${OpenSSL_version}.tar.gz && \
        rm ${OpenSSL_version}.tar* && \
    cd /thirdparty/${OpenSSL_version} && \
    ./config \
        --release \
        -DFAST_PCLMUL -DECP_NISTZ256_ASM -DO3 \
        -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' \
        --with-rand-seed=rdcpu,os \
        enable-ec_nistp_64_gcc_128 \
        enable-tls1_3 no-ssl no-tls1 no-tls1_1 \
        no-afalgeng no-tests && \
    make -j${CORES} && make -j${CORES} install

# ----------------QSC_RELATED_UPDATES------------------
# -----------------------------------------------------
# ==> OQS-OpenSSL BUILD FROM SOURCE (with QSC capabilities)
#git checkout 24570943eca60e26246227f899f428757351ca4e && \

RUN cd /thirdparty && \
    git clone --single-branch --branch OQS-OpenSSL_1_1_1-stable \
              https://github.com/open-quantum-safe/openssl.git OQSopenssl && \
    cd OQSopenssl && mkdir oqs && \
    git clone --branch master https://github.com/open-quantum-safe/liboqs.git && \
         cd liboqs && \
         git checkout $OQS_liboqs_Commit && \
         mkdir build && cd build && \
         printf "\033[1;33m" && cmake -LAH .. && printf "\033[0m" && rm -rf * && \
         cmake -GNinja \
               -DBUILD_SHARED_LIBS=OFF \
               -DCMAKE_INSTALL_PREFIX=/thirdparty/OQSopenssl/oqs \
#               -DOQS_ENABLE_KEM_bike1_l1_cpa=OFF \ 
#               -DOQS_ENABLE_KEM_bike1_l1_fo=OFF \
#               -DOQS_ENABLE_KEM_bike1_l3_cpa=OFF \
#               -DOQS_ENABLE_KEM_bike1_l3_fo=OFF \
               -DOQS_USE_OPENSSL=ON \
               .. && \
         ninja  && ninja install

RUN cd /thirdparty/OQSopenssl && \
    git checkout $OQS_OpenSSL_Commit && \
   ./Configure linux-x86_64 \
        --prefix=/thirdparty/install/openssl_oqs \
        -I/thirdparty/OQSopenssl/liboqs/build/include \
        -L/thirdparty/OQSopenssl/liboqs/build/lib -loqs \
        -DFAST_PCLMUL -DECP_NISTZ256_ASM -DO3 \
        -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' \
        --with-rand-seed=rdcpu,os \
        enable-ec_nistp_64_gcc_128 \
        enable-tls1_3 no-ssl no-tls1 no-tls1_1 \ 
        no-aria no-bf no-blake2 no-camellia no-cast \
        no-dsa no-idea no-md4 no-mdc2 no-ocb \
        no-poly1305 no-rc2 no-rc4 no-rmd160 no-scrypt \
        no-siphash no-sm2 no-sm3 no-sm4 no-whirlpool no-gost \
 #       no-ec2m \
        no-afalgeng no-tests \
        shared threads \
        -lm \
        && \
    make -j${CORES} && make -j${CORES} install_sw


#==============================================================================
# Second stage build

# We start the second stage build with the ingress-controller base image
# Which either is pulled from k8s.gcr.io/ingress-nginx, or is a locally generated image (from sources)
# specified via --build-arg BASE_IMAGE=$CONTROLLER_BASE_IMAGE

FROM ${BASE_IMAGE}

# Override (read: replace) openssl libraries in the base image 
# by copying the libs from the builder stage above
COPY --from=qsc_openssl_lib_builder /thirdparty/install/openssl_oqs/lib/libcrypto.so.1.1 /lib
COPY --from=qsc_openssl_lib_builder /thirdparty/install/openssl_oqs/lib/libssl.so.1.1 /lib

# All the rest comes from the base image

#EXPOSE 80 443

#CMD ["nginx", "-g", "daemon off;"]

#USER root
#RUN apk update && apk upgrade && \
#    apk add bash

#CMD [ "/bin/bash" ]

#ENTRYPOINT /bin/bash

