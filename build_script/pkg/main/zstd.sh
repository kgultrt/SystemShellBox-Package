#!/usr/bin/bash

configure_zstd() {
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    
    if [[ ! -f v${PKG_VERSIONS[zstd]}.tar.gz ]]; then
        wget https://github.com/facebook/zstd/archive/refs/tags/v${PKG_VERSIONS[zstd]}.tar.gz
    fi
    
    tar -zxvf v${PKG_VERSIONS[zstd]}.tar.gz
}

apply_patches_zstd() {
    echo "应用Android补丁..."
    
    cd $BUILD_PROG_WORKING_DIR/zstd-${PKG_VERSIONS[zstd]}
    general_apply_patch zstd
}

build_zstd() {
    echo "编译..."
    setup_toolchain
    
    LDFLAGS+=" -DZSTD_BUILD_CONTRIB=ON \
        -DZSTD_BUILD_PROGRAMS=ON \
        -DZSTD_BUILD_STATIC=OFF \
        -DZSTD_BUILD_TESTS=OFF \
        -DZSTD_LZ4_SUPPORT=OFF \
        -DZSTD_LZMA_SUPPORT=ON \
        -DZSTD_PROGRAMS_LINK_SHARED=ON \
        -DZSTD_ZLIB_SUPPORT=ON \
        -DCMAKE_SYSTEM_NAME=Linux"
    cd $BUILD_PROG_WORKING_DIR/zstd-${PKG_VERSIONS[zstd]}
    
    # 在编译 zstd 之前
    local local_saved_arch="$TARGET_ARCH"
    unset TARGET_ARCH
    
    make -j
    
    export TARGET_ARCH="$local_saved_arch"  # 恢复原值
    
    echo
    echo "install.."
    echo
    
    make install PREFIX=$BUILD_PROG_WORKING_DIR/output LIBDIR=$BUILD_PROG_WORKING_DIR/output/lib
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv zstd-* *.tar.gz
}

configure_liblzma() {
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    
    if [[ ! -f xz-${PKG_VERSIONS[liblzma]}.tar.xz ]]; then
        wget https://github.com/tukaani-project/xz/releases/download/v${PKG_VERSIONS[liblzma]}/xz-${PKG_VERSIONS[liblzma]}.tar.xz
    fi
    
    tar xfv xz-${PKG_VERSIONS[liblzma]}.tar.xz
    
    cd xz-${PKG_VERSIONS[liblzma]}
}

apply_patches_liblzma() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/xz-${PKG_VERSIONS[liblzma]}
    
    general_apply_patch liblzma
}

build_liblzma() {
    echo "编译..."
    setup_toolchain
    cd $BUILD_PROG_WORKING_DIR/xz-${PKG_VERSIONS[liblzma]}
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-sandbox=no
    
    make -j
    
    general_install
    
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rfv xz-*
}