#!/usr/bin/bash

configure_libssh2() {
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    
    if [[ ! -f libssh2-${PKG_VERSIONS[libssh2]}.tar.gz ]]; then
        wget https://www.libssh2.org/download/libssh2-${PKG_VERSIONS[libssh2]}.tar.gz
    fi
    
    tar -zxvf libssh2-${PKG_VERSIONS[libssh2]}.tar.gz
    
    cd libssh2-${PKG_VERSIONS[libssh2]}
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --with-crypto=openssl \
        --libdir=$BUILD_PROG_WORKING_DIR/output/lib
}

build_libssh2() {
    echo "编译..."
    
    setup_toolchain
    cd $BUILD_PROG_WORKING_DIR/libssh2-${PKG_VERSIONS[libssh2]}
    
    make -j
    
    echo
    echo "install.."
    echo
    
    make install prefix=$BUILD_PROG_WORKING_DIR/output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv libssh2-*
}