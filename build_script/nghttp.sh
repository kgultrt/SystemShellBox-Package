#!/usr/bin/bash

configure_libnghttp2() {
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    
    if [[ ! -f nghttp2-${PKG_VERSIONS[libnghttp2]}.tar.xz ]]; then
        wget https://github.com/nghttp2/nghttp2/releases/download/v${PKG_VERSIONS[libnghttp2]}/nghttp2-${PKG_VERSIONS[libnghttp2]}.tar.xz
    fi
    
    tar xfv nghttp2-${PKG_VERSIONS[libnghttp2]}.tar.xz
    
    cd nghttp2-${PKG_VERSIONS[libnghttp2]}
    
    local _SOVERSION=14
    local a
    
    for a in LT_CURRENT LT_AGE; do
        local _${a}=$(sed -En 's/^AC_SUBST\('"${a}"',\s*([0-9]+).*/\1/p' \
                configure.ac)
    done
    local v=$(( _LT_CURRENT - _LT_AGE ))
    if [ ! "${_LT_CURRENT}" ] || [ "${v}" != "${_SOVERSION}" ]; then
        echo "SOVERSION guard check failed."
        exit
    fi
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-lib-only
}

build_libnghttp2() {
    echo "编译..."
    
    setup_toolchain
    cd $BUILD_PROG_WORKING_DIR/nghttp2-${PKG_VERSIONS[libnghttp2]}
    
    make -j
    
    echo
    echo "install.."
    echo
    
    make install prefix=$BUILD_PROG_WORKING_DIR/output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv nghttp2-*
}


configure_libnghttp3() {
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    
    if [[ ! -f nghttp3-${PKG_VERSIONS[libnghttp3]}.tar.xz ]]; then
        wget https://github.com/ngtcp2/nghttp3/releases/download/v${PKG_VERSIONS[libnghttp3]}/nghttp3-${PKG_VERSIONS[libnghttp3]}.tar.xz
    fi
    
    tar xfv nghttp3-${PKG_VERSIONS[libnghttp3]}.tar.xz
    
    cd nghttp3-${PKG_VERSIONS[libnghttp3]}
    
    local _SOVERSION=9
    local a
    
    for a in LT_CURRENT LT_AGE; do
        local _${a}=$(sed -En 's/^AC_SUBST\('"${a}"',\s*([0-9]+).*/\1/p' \
                configure.ac)
    done
    local v=$(( _LT_CURRENT - _LT_AGE ))
    if [ ! "${_LT_CURRENT}" ] || [ "${v}" != "${_SOVERSION}" ]; then
        echo "SOVERSION guard check failed."
        exit
    fi
    
    autoreconf
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-lib-only
}

build_libnghttp3() {
    echo "编译..."
    
    setup_toolchain
    cd $BUILD_PROG_WORKING_DIR/nghttp3-${PKG_VERSIONS[libnghttp3]}
    
    make -j
    
    echo
    echo "install.."
    echo
    
    make install prefix=$BUILD_PROG_WORKING_DIR/output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv nghttp3-*
}