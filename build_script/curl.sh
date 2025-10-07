#!/usr/bin/bash

configure_curl() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
    
    if [[ ! -f curl-${PKG_VERSIONS[curl]}.tar.xz ]]; then
        wget https://github.com/curl/curl/releases/download/curl-${PKG_VERSIONS[curl]//./_}/curl-${PKG_VERSIONS[curl]}.tar.xz
    fi
    
    tar xfv curl-${PKG_VERSIONS[curl]}.tar.xz
    
    cd curl-${PKG_VERSIONS[curl]}
    
    local _SOVERSION=4
    local a
    for a in VERSIONCHANGE VERSIONDEL; do
        local _${a}=$(sed -En 's/^'"${a}"'=([0-9]+).*/\1/p' \
                lib/Makefile.soname)
    done
    local v=$(( _VERSIONCHANGE - _VERSIONDEL ))
    if [ ! "${_VERSIONCHANGE}" ] || [ "${v}" != "${_SOVERSION}" ]; then
        echo "SOVERSION guard check failed."
        exit
    fi
    
    LDFLAGS+=" -Wl,-z,nodelete"
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-ntlm-wb=$APP_INSTALL_DIR/bin/ntlm_auth \
        --with-ca-bundle=$APP_INSTALL_DIR/etc/tls/cert.pem \
        --with-ca-path=$APP_INSTALL_DIR/etc/tls/certs \
        --with-nghttp2 \
        --without-libidn \
        --without-libidn2 \
        --without-librtmp \
        --without-brotli \
        --without-libpsl \
        --with-libssh2 \
        --with-ssl \
        --with-openssl \
        --with-openssl-quic \
        --with-nghttp3 \
        --disable-ares \
        ac_cv_func_getpwuid=yes
}

apply_patches_curl() {
    echo "应用Android补丁..."
    echo "NO PATCH!"
}

build_curl() {
    echo "编译..."
    
    setup_toolchain
    LDFLAGS+=" -Wl,-z,nodelete"
    cd curl-${PKG_VERSIONS[curl]}
    make -j
    general_install
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv curl-*
}