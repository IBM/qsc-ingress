
#=========================================================
# BUILD STAGE 1
# -------------

# we build OpenSSL and OQS OpenSSL (v1.1.1g), and we build HAproxy v.2.2.2 LTS

#We start with fedora version 29 
#Fedora 28 is the foundation for RedHat v8, but fedora v29 gives us GLIBCv2.28 which is the one used in UBIv8.2)
FROM fedora:29 AS builder
LABEL stage=builder

USER root

# -----------------------------------------------------
# ==> VERSION CONTROL via ARG
# OpenSSL (see here: https://www.openssl.org/source/)
ARG OpenSSL_version=openssl-1.1.1g
# PGP KeyID Matt Caswell & Richard Levitte (see here: https://www.openssl.org/community/omc.html)
ARG OpenSSL_KeyID1=8657ABB260F056B1E5190839D9C4D26D0E604491
ARG OpenSSL_KeyID2=7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C

# -----------------------------------------------------
# ==> Create directories
RUN mkdir -p /opt && \
    mkdir -p /src && \
    mkdir /thirdparty && mkdir /thirdparty/install && \
    mkdir /thirdparty/install/openssl_oqs

# -----------------------------------------------------
# ==> PREREQUISITES USED DURING BUILD PROCESS
# openssl-devel not installed
RUN yum groupinstall -y 'Development Tools'
RUN yum install -y pcre-devel pcre-devel make gcc rpm-build systemd-devel sed wget gnupg cmake zlib-devel

RUN cd /thirdparty && \ 
    wget http://mirror.centos.org/centos/8/PowerTools/x86_64/os/Packages/ninja-build-1.8.2-1.el8.x86_64.rpm && \
    yum localinstall -y ninja-build-1.8.2-1.el8.x86_64.rpm && \
    rm -rf ninja-build-1.8.2-1.el8.x86_64.rpm

# In case you need the latest cmake
#RUN cd /thirdparty && \ 
#    wget https://cmake.org/files/v3.18/cmake-3.18.1.tar.gz && \
#    tar zxvf cmake-3.* && \
#    rm -rf cmake-3.18.1.tar.gz && \
#    cd cmake-3.* && \
#    ./bootstrap --prefix=/usr/local && \
#    make -j$(nproc) && \
#    make install && \
#    cmake --version 

# -----------------------------------------------------
# ==> LOAD VERIFICATION KEYS
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys $OpenSSL_KeyID1 && \
    gpg --keyserver pool.sks-keyservers.net --recv-keys $OpenSSL_KeyID2

# -----------------------------------------------------
# ==> OPENSSL BUILD FROM SOURCE (for SYSTEM)
RUN cd /thirdparty &&  \
    wget https://www.openssl.org/source/${OpenSSL_version}.tar.gz && \
    wget https://www.openssl.org/source/${OpenSSL_version}.tar.gz.asc && \
        gpg --verify $OpenSSL_version.tar.gz.asc ${OpenSSL_version}.tar.gz && \
        tar -xzf ${OpenSSL_version}.tar.gz && \
        rm ${OpenSSL_version}.tar* && \
    cd /thirdparty/${OpenSSL_version} && \
    cp ./Configurations/10-main.conf . && \
    ./config \
        --release \
        -DFAST_PCLMUL -DECP_NISTZ256_ASM -DO3 \
        -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' \
        --with-rand-seed=rdcpu,os \
        enable-ec_nistp_64_gcc_128 \
        enable-tls1_3 no-ssl no-tls1 no-tls1_1 \
        no-afalgeng no-tests && \
    make -j$(nproc) && make -j$(nproc) install



# ----------------QSC_RELATED_UPDATES------------------
# -----------------------------------------------------
# ==> OQS-OpenSSL BUILD FROM SOURCE (with QSC capabilities)
#git checkout 24570943eca60e26246227f899f428757351ca4e && \

RUN cd /thirdparty && \
    git clone --single-branch --branch OQS-OpenSSL_1_1_1-stable \
              https://github.com/open-quantum-safe/openssl.git OQSopenssl && \
    cd OQSopenssl && mkdir oqs && \
    sed -i  '/"linux-generic32"*/ a shlib_variant =>"_oqs",' Configurations/10-main.conf && \
    git clone --branch master https://github.com/open-quantum-safe/liboqs.git && \
         cd liboqs && \
         mkdir build && cd build && \
         printf "\033[1;33m" && cmake -LAH .. && printf "\033[0m" && rm -rf * && \
         cmake -GNinja \
               -DBUILD_SHARED_LIBS=OFF \
               -DCMAKE_INSTALL_PREFIX=/thirdparty/OQSopenssl/oqs \
#               -DOQS_ENABLE_KEM_bike1_l1_cpa=OFF \ 
#               -DOQS_ENABLE_KEM_bike1_l1_fo=OFF \
#               -DOQS_ENABLE_KEM_bike1_l3_cpa=OFF \
#               -DOQS_ENABLE_KEM_bike1_l3_fo=OFF \
               .. && \
         ninja  && ninja install
RUN cd /thirdparty/OQSopenssl && \
   ./Configure linux-x86_64 \
        --prefix=/thirdparty/install/openssl_oqs \
        -I/thirdparty/OQSopenssl/liboqs/build/include \
        -L/thirdparty/OQSopenssl/liboqs/build/lib -loqs \
        -DFAST_PCLMUL -DECP_NISTZ256_ASM -DO3 \
        -DOQS_DEFAULT_GROUPS="kyber512:prime256v1:secp384r1:secp521r1:X25519:X448:kyber768:kyber1024:p256_kyber512:p384_kyber768:p521_kyber1024" \
        -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' \
        --with-rand-seed=rdcpu,os \
        enable-ec_nistp_64_gcc_128 \
        enable-tls1_3 no-ssl no-tls1 no-tls1_1 \ 
        no-aria no-bf no-blake2 no-camellia no-cast \
        no-dsa no-idea no-md4 no-mdc2 no-ocb \
        no-poly1305 no-rc2 no-rc4 no-rmd160 no-scrypt \
        no-siphash no-sm2 no-sm3 no-sm4 no-whirlpool no-gost \
#        no-ec2m \
        no-afalgeng no-tests \
        shared threads \
        -lm \
        && \
    make -j$(nproc) && make -j$(nproc) install_sw && \
#        cp /thirdparty/OQSopenssl/libcrypto_oqs.so.1.1 /usr/local/lib && \
#        cp /thirdparty/OQSopenssl/libssl_oqs.so.1.1 /usr/local/lib && \
#        ln -s /usr/local/lib/libcrypto_oqs.so.1.1 \
#              /usr/local/lib/libcrypto_oqs.so  && \
#        ln -s /usr/local/lib/libssl_oqs.so.1.1 \
#              /usr/local/lib/libssl_oqs.so && \
        cp /thirdparty/OQSopenssl/libcrypto_oqs.so.1.1 /usr/local/lib/libcrypto.so.1.1  && \
        cp /thirdparty/OQSopenssl/libssl_oqs.so.1.1 /usr/local/lib/libssl.so.1.1 && \
        ln -s /usr/local/lib/libcrypto.so.1.1 \
              /usr/local/lib/libcrypto.so  && \
        ln -s /usr/local/lib/libssl.so.1.1 \
              /usr/local/lib/libssl.so
    



# -----------------------HAPROXY-----------------------
# -----------------------------------------------------
# ==> BUILD HAPROXY (FROM SOURCE)
RUN cd /thirdparty && \
    wget http://www.haproxy.org/download/2.2/src/haproxy-2.2.4.tar.gz && \
    tar -xzf haproxy-2.2.4.tar.gz && \
    rm haproxy-2.2.4.tar.gz && \
    cd /thirdparty/haproxy-2.2.4 && mkdir OpenSSL && \
        cp /thirdparty/OQSopenssl/libcrypto_oqs.so.1.1 ./OpenSSL/libcrypto.so.1.1 && \
        cp /thirdparty/OQSopenssl/libssl_oqs.so.1.1 ./OpenSSL/libssl.so.1.1 && \
        cp /thirdparty/OQSopenssl/libcrypto_oqs.so.1.1 /usr/lib64  && \
        cp /thirdparty/OQSopenssl/libssl_oqs.so.1.1 /usr/lib64 && \
        ln -s /thirdparty/haproxy-2.2.4/OpenSSL/libcrypto.so.1.1 \
              /thirdparty/haproxy-2.2.4/OpenSSL/libcrypto.so  && \
        ln -s /thirdparty/haproxy-2.2.4/OpenSSL/libssl.so.1.1 \
              /thirdparty/haproxy-2.2.4/OpenSSL/libssl.so && \
    make clean && \
    make -j$(nproc) TARGET=linux-glibc CPU=generic \
                     CFLAGS="-O2 -g -fno-strict-aliasing -Wdeclaration-after-statement -fwrapv -Wno-unused-label -Wno-sign-compare -Wno-unused-parameter -Wno-old-style-declaration -Wno-ignored-qualifiers -Wno-clobbered -Wno-missing-field-initializers -Wtype-limits -DTCP_USER_TIMEOUT=18" \
                     USE_OPENSSL=1 SSL_INC=/thirdparty/install/openssl_oqs/include/openssl SSL_LIB=/usr/local/lib \
                     USE_ZLIB=1 \
                     USE_LUA= \
                     USE_PCRE=1 \
                     USE_SYSTEMD= \
                     USE_REGPARM=1 USE_LINUX_TPROXY=1 && \
    make install && \
    PATH=$PATH:/usr/local/lib && \
    haproxy -v && haproxy -vv

RUN printf "\033[1;33m" && \
    echo " " && \
    echo "==========================" && \
    echo "Status after build stage 1" && \
    echo "--------------------------" && \
    haproxy -v && \
    haproxy -vv && \
    ldd -v /usr/local/sbin/haproxy && \
    echo " " && \
    /usr/lib64/libc.so.6 -version && \
    ldd -v /usr/lib64/libc.so.6 && \
    echo " " && \
    printf "\033[0m"


#=========================================================
# BUILD STAGE 2
# -------------

# We grab the haproxy-router for openshift from the OKD distribution: 
# See here https://github.com/openshift/okd/releases, in the 'Images:' list for the version you're interested in, 
# search for 'haproxy-router' and copy related image path to the FROM line below: 

# For 4.5.0 (October 2020) distribution use:
FROM quay.io/openshift/okd-content@sha256:9c40cb7dc99bcdb4e2aefe46a76da293e7f6a8165e9951fd17ba11791c33cce2 AS configuration_provider

# v4.5.0 (August 2020) distribution
#FROM quay.io/openshift/okd-content@sha256:9bdaf99356376cbb73a4ff72105d3582dc90b557e76a93a921358e9fbc081799 AS configuration_provider

# For a 4.4 version, use: 
# FROM quay.io/openshift/okd-content@sha256:5908265eb0041cea9a9ec36ad7b2bc82dd45346fc9e0f1b34b0e38a0f43f9f18 AS configuration_provider

LABEL stage=configuration_provider

# For information about how to use the ingress controller for v4.5 see here: 
# https://docs.openshift.com/container-platform/4.5/networking/ingress-operator.html

# Note; We've chosen OKD version 4.5.0-0.okd-2020-08-12-020541 (August 2020), 
# which is based on Red Hat Enterprise Linux Server 7.8 (Maipo)
# which is based on fedora 19
# which includes:
# (A): HAPROXY:
# HAproxy version is 'HA-Proxy version 2.0.14'
#Build options :
#  TARGET  = linux-glibc
#  CPU     = generic
#  CC      = gcc
#  CFLAGS  = -O2 -g -fno-strict-aliasing -Wdeclaration-after-statement -fwrapv -Wno-unused-label -Wno-sign-compare -Wno-unused-parameter -Wno-old-style-declaration -Wno-ignored-qualifiers -Wno-clobbered -Wno-missing-field-initializers -Wtype-limits -DTCP_USER_TIMEOUT=18
#  OPTIONS = USE_PCRE=1 USE_REGPARM=1 USE_LINUX_TPROXY=1 USE_OPENSSL=1 USE_ZLIB=1
#Feature list : +EPOLL -KQUEUE -MY_EPOLL -MY_SPLICE +NETFILTER +PCRE -PCRE_JIT -PCRE2 -PCRE2_JIT +POLL -PRIVATE_CACHE +THREAD -PTHREAD_PSHARED +REGPARM -STATIC_PCRE -STATIC_PCRE2 +TPROXY +LINUX_TPROXY +LINUX_SPLICE +LIBCRYPT +CRYPT_H -VSYSCALL +GETADDRINFO +OPENSSL -LUA +FUTEX +ACCEPT4 -MY_ACCEPT4 +ZLIB -SLZ +CPU_AFFINITY +TFO +NS +DL +RT -DEVICEATLAS -51DEGREES -WURFL -SYSTEMD -OBSOLETE_LINKER +PRCTL +THREAD_DUMP -EVPORTS
# (B) GLIBC:
# Note: Here the glibc characteristics: 
#GNU C Library (GNU libc) stable release version 2.17, by Roland McGrath et al.
#Copyright (C) 2012 Free Software Foundation, Inc.
#This is free software; see the source for copying conditions.
#There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
#PARTICULAR PURPOSE.
#Compiled by GNU CC version 4.8.5 20150623 (Red Hat 4.8.5-39).
#Compiled on a Linux 3.10.0 system on 2020-01-22.
#Available extensions:
# The C stubs add-on version 2.1.2.
# crypt add-on version 2.1 by Michael Glad and others
# GNU Libidn by Simon Josefsson
# Native POSIX Threads Library by Ulrich Drepper et al
# BIND-8.2.3-T5B
# RT using linux kernel aio
#libc ABIs: UNIQUE IFUNC

# ==> As we can see, the above are all fairly old versions - hence we'll only grab the configuration 
#     files from this image, but replace all the rest with new stuff.
#     However, we'll then need to make sure in the next stage that the user and workdir exists and 
#     we'll copy stuff otherwise not available (e.g. openshift-router, python helpers, etc) 
#     from this 'configuration_provider' build stage

# we nevertheless want to get some insights of what's in this 'configuration_provider' image
USER root
RUN printf "\033[1;33m" && \
    echo " " && \
    echo "==========================" && \
    echo "Status after build stage 2" && \
    echo "--------------------------" && \
    cat /etc/os-release && \
    echo "Current directory: $(pwd)" && echo "  " && \
    haproxy -v && \
    haproxy -vv && \
    ldd -v /usr/sbin/haproxy && \
    echo " " && \
    /usr/lib64/libc.so.6 -version && \
    ldd -v /usr/lib64/libc.so.6 && \
    cd / && find -name haproxy* && \
    echo " " && echo "List of users:" && tail -1 /etc/passwd && lslogins --user-accs --supp-groups --acc-expiration && \
    echo " " && ls -l /etc/alternatives && \
    echo " " && \
    printf "\033[0m"

#=========================================================
# BUILD STAGE 3
# -------------

# Now, we bring everything together, based on RedHat UBI v8.2

FROM registry.access.redhat.com/ubi8/ubi:8.2

# we need to fix a couple of things, which we do as root
USER root

# install some missing components 
# (note: for rhel8, we install procps-ng and util-linux instead of sysvinit-tools)
RUN INSTALL_PKGS="rsyslog procps-ng util-linux python2" && \
    yum install -y $INSTALL_PKGS && \
#    yum module -y install go-toolset && \
    yum clean all

# We copy various stuff from configuration_provider but without overwriting exising (=newer) file versions:

# (A) Copy everything from /usr/sbin of the configuration_provider to a temp directory, and from there 
# without overwriting (-n option) to the current /usr/sbin, and finally remove the temp folder
RUN mkdir /usr/sbin/tmp
COPY --from=configuration_provider /usr/sbin /usr/sbin/tmp
RUN cp -n -r /usr/sbin/tmp/* /usr/sbin && \
    rm -rf /usr/sbin/tmp 
# (B) Copy everything from /usr/bin of the configuration_provider to a temp directory, and from there 
# without overwriting (-n option) to the current /usr/bin, and finally remove the temp folder
RUN mkdir /usr/bin/tmp
COPY --from=configuration_provider /usr/bin /usr/bin/tmp
RUN cp -n -r /usr/bin/tmp/* /usr/bin && \
    rm -rf /usr/bin/tmp 
# (C) Copy everything from /usr/lib of the configuration_provider to a temp directory, and from there 
# without overwriting (-n option) to the current /usr/lib, and finally remove the temp folder
RUN mkdir /usr/lib/tmp
COPY --from=configuration_provider /usr/lib /usr/lib/tmp
RUN cp -n -r /usr/lib/tmp/* /usr/lib && \
    rm -rf /usr/lib/tmp 


# Copy oqs openssl libraries and haproxy plus its config stuff
# by copying the libs & haproxy executable from the builder stage above
# and by copying the config files from the configuration_provider above
COPY --from=builder /usr/lib64/libcrypto_oqs.so.1.1 /usr/lib64
COPY --from=builder /usr/lib64/libssl_oqs.so.1.1 /usr/lib64
COPY --from=builder /usr/local/sbin/haproxy /usr/sbin
COPY --from=configuration_provider /var/lib/haproxy /var/lib/haproxy

# We chose the same workdir as used in build stage 2
WORKDIR /var/lib/haproxy/conf

# we need a user and group haproxy
RUN groupadd --gid 188 --system haproxy && \
    useradd -c "haproxy" -u 188 -d /var/lib/haproxy -g "haproxy" -s /sbin/nologin haproxy

# make sure an arbitrary user has the right access
RUN chown -R :0 /var/lib/haproxy && \
    chmod -R g+w /var/lib/haproxy

# we add the possibility to define default curves by adding a hook for a
# corresponding environment variable (ROUTER_DEFAULT_BIND_CURVES, must be a colon 
# separated list) in the config template file
#RUN sed -i '/defaults/ i # add default bind curves (colon separated list) if provided in env variable ROUTER_DEFAULT_BIND_CURVES\n{{- if ne (env "ROUTER_DEFAULT_BIND_CURVES") "" }}\n  ssl-default-bind-curves {{env "ROUTER_DEFAULT_BIND_CURVES"}} \n{{- end }}\n\n' /var/lib/haproxy/conf/haproxy-config.template 
# We set the ENV variable ROUTER_DEFAULT_BIND_CURVES to a QSC enabled default (Note: This overrides the default curves of OpenSSL)
#ENV ROUTER_DEFAULT_BIND_CURVES="kyber512:prime256v1:secp384r1:secp521r1:X25519:X448:kyber768:kyber1024:p256_kyber512:p384_kyber768:p521_kyber1024"
ENV ROUTER_DEFAULT_BIND_CURVES=""

# We set the ENV variable for ROUTER_CIPHERS by default to only use (a selection of) TLSv1.2 & TLSv1.3 ciphers (see
# here: https://wiki.mozilla.org/Security/Server_Side_TLS#Recommended_configurations )
ENV ROUTER_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"

# We get us some insights of what's going on
RUN printf "\033[1;33m" && \
    echo " " && \
    echo "==========================" && \
    echo "Status after build stage 3" && \
    echo "--------------------------" && \
    cat /etc/os-release && \
    echo "Current directory: $(pwd)" && echo "  " && \
    haproxy -v && \
    haproxy -vv && \
    ldd -v /usr/sbin/haproxy && \
    echo " " && \
    /usr/lib64/libc.so.6 -version && \
    ldd -v /usr/lib64/libc.so.6 && \
    echo " " && echo "List of users:" && tail -1 /etc/passwd && lslogins --user-accs --supp-groups --acc-expiration  && \
#    yum list installed && \
#    ls /usr/bin && \
    chardetect /var/lib/haproxy/conf/haproxy-config.template && \
    cd / && find -name *.go  && \
    echo " " && \
    printf "\033[0m"

LABEL io.k8s.display-name="OpenShift HAProxy Router" \
      io.k8s.description="This component offers ingress to an OpenShift cluster via Ingress and Route rules." \
      io.openshift.tags="openshift,router,haproxy"

# Adding NET_BIND_SERVICE capabilities to the HApoxy executable such that 
# it can bind to ports despite being executed by an unprivileged user
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/haproxy && \
    getcap /usr/sbin/haproxy

# we switch to an 'arbitrary' user
USER 1001

# we expose the ports for HAproxy
EXPOSE 80 443

# we chose the same workdir as provided by build stage 2
WORKDIR /var/lib/haproxy/conf

# some environement variables which are required
ENV TEMPLATE_FILE=/var/lib/haproxy/conf/haproxy-config.template 
ENV RELOAD_SCRIPT=/var/lib/haproxy/reload-haproxy

# we start HAproxy openshift-router
ENTRYPOINT ["/usr/bin/openshift-router", "--v=2"]



# ======================================================================
# REMAINDER OF FILE ARE LEFTOVERS FROM DEVELOPMENT (= ALL COMMENTED OUT)

# We debug as root
#USER root
# we use a shell during develoment
#ENTRYPOINT ["/bin/bash"]

#RUN INSTALL_PKGS="haproxy20 rsyslog sysvinit-tools" && \
#    yum install -y $INSTALL_PKGS && \
#    rpm -V $INSTALL_PKGS && \
#    yum clean all && \
#    mkdir -p /var/lib/haproxy/router/{certs,cacerts,whitelists} && \
#    mkdir -p /var/lib/haproxy/{conf/.tmp,run,bin,log} && \
#    touch /var/lib/haproxy/conf/{{os_http_be,os_edge_reencrypt_be,os_tcp_be,os_sni_passthrough,os_route_http_redirect,cert_config,os_wildcard_domain}.map,haproxy.config} && \
#    setcap 'cap_net_bind_service=ep' /usr/sbin/haproxy && \
#    chown -R :0 /var/lib/haproxy && \
#   chmod -R g+w /var/lib/haproxy
#COPY images/router/haproxy/ /var/lib/haproxy/


#LABEL io.k8s.display-name="OpenShift HAProxy Router" \
#      io.k8s.description="This component offers ingress to an OpenShift cluster via Ingress and Route rules." \
#      io.openshift.tags="openshift,router,haproxy"
#USER 1001
#EXPOSE 80 443
#WORKDIR /var/lib/haproxy/conf
#ENV TEMPLATE_FILE=/var/lib/haproxy/conf/haproxy-config.template \
#    RELOAD_SCRIPT=/var/lib/haproxy/reload-haproxy
#ENTRYPOINT ["/usr/bin/openshift-router", "--v=2"]
