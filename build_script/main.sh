#!/usr/bin/bash

# ===================== 构建步骤函数 =====================

install_dependencies() {
    echo "更新包索引..."
    apt update -y
    
    echo "安装依赖包..."
    apt install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip dialog xz-utils tar
    
    export BUILD_PROG_WORKING_DIR=$PWD
}

install_dir() {
    cd $BUILD_PROG_WORKING_DIR
    
    mkdir -p $BUILD_PROG_WORKING_DIR/output
    mkdir -p $BUILD_PROG_WORKING_DIR/output/lib
    mkdir -p $BUILD_PROG_WORKING_DIR/output/bin
    mkdir -p $BUILD_PROG_WORKING_DIR/output/etc
    mkdir -p $BUILD_PROG_WORKING_DIR/output/etc/tls
    
    cp -r home $BUILD_PROG_WORKING_DIR/output
}

clone_termux_elf_cleaner() {
    case ${NEED_CLEAN_ELF} in
        "true")
            echo "克隆termux-elf-cleaner仓库..."
            git clone https://github.com/termux/termux-elf-cleaner.git
            echo "应用补丁..."
            cd termux-elf-cleaner
            patch -p1 < ../patch/RealignFile/fixcleaner.patch
            echo "编译..."
            cmake .
            make
            ;;
        "false")
            echo "Skip!"
    esac
    
    cd $BUILD_PROG_WORKING_DIR
}

build_installer() {
    echo "构建环境安装程序..."
    cd installer/jni
    ${NDK_BUILD}
    
    case "${TARGET_ARCH}" in
        aarch64)
            export INSTALLER_PATH="${BUILD_PROG_WORKING_DIR}/installer/libs/arm64-v8a/installer"
            ;;
        arm)
            export INSTALLER_PATH="${BUILD_PROG_WORKING_DIR}/installer/libs/armeabi-v7a/installer"
            ;;
        x86)
            export INSTALLER_PATH="${BUILD_PROG_WORKING_DIR}/installer/libs/x86/installer"
            ;;
        x86_64)
            export INSTALLER_PATH="${BUILD_PROG_WORKING_DIR}/installer/libs/x86_64/installer"
            ;;
    esac
    
    cp -r $INSTALLER_PATH $BUILD_PROG_WORKING_DIR/output/home/.term
    unset INSTALLER_PATH
    cd $BUILD_PROG_WORKING_DIR
}

download_coreutils() {
    echo "下载coreutils源码..."
    COREUTILS_TAR="coreutils-${PKG_VERSIONS[coreutils]}.tar.xz"
    
    if [ ! -f "${COREUTILS_TAR}" ]; then
        wget -c "https://mirrors.ustc.edu.cn/gnu/coreutils/${COREUTILS_TAR}" || \
        wget -c "https://ftp.gnu.org/gnu/coreutils/${COREUTILS_TAR}"
    fi
}

setup_coreutils() {
    echo "解压源码..."
    tar xf "coreutils-${PKG_VERSIONS[coreutils]}.tar.xz"
    cd "coreutils-${PKG_VERSIONS[coreutils]}"
    
    setup_toolchain
}

apply_patches() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/coreutils-${PKG_VERSIONS[coreutils]}
    for patch_file in ../patch/coreutils/*.patch; do
        patch -p1 < $patch_file
    done
}

configure_coreutils() {
    echo "配置coreutils..."
    
    cd $BUILD_PROG_WORKING_DIR/coreutils-${PKG_VERSIONS[coreutils]}
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-single-binary=symlinks \
        --disable-xattr \
        --with-gnu-ld \
        --disable-year2038 \
        --enable-no-install-program=pinky,df,users,who,uptime,stdbuf \
        --with-packager=SuperDevelopmentEnvironment \
        --enable-shared \
        ac_cv_func_malloc_0_nonnull=yes \
        ac_cv_func_realloc_0_nonnull=yes \
        gl_cv_header_working_stdint_h=yes \
        gl_cv_host_operating_system=Android \
        ac_cv_func_getpass=yes \
        gl_cv_func_isnanl_works=yes \
        ac_cv_func_getpwent=no \
        ac_cv_func_getgrent=no \
        ac_cv_func_endpwent=no \
        ac_cv_func_endgrent=no \
        ac_cv_func_getpwnam=no \
        ac_cv_func_getgrnam=no \
        ac_cv_func_getpwuid=no \
        ac_cv_func_sigsetmask=no \
        ac_cv_func_statx=no \
        ac_cv_func_nl_langinfo=no \
        ac_cv_func_syncfs=no \
        ac_cv_func_sethostname=no \
        ac_cv_func_mbrlen=no \
        ac_cv_c_bigendian=no \
        ac_cv_func_getnameinfo=no \
        ac_cv_func_tzfree=yes \
        ac_cv_func_tzalloc=yes
}

build_coreutils() {
    echo "开始编译..."
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR/coreutils-${PKG_VERSIONS[coreutils]}
    make -j$(nproc)
    make install prefix=../output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv coreutils-*
}

configure_bash() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "下载bash源码..."
    BASH_TAR="bash-${PKG_VERSIONS[bash]}.tar.gz"
    
    if [ ! -f "${BASH_TAR}" ]; then
        wget -c "https://mirrors.ustc.edu.cn/gnu/bash/${BASH_TAR}" || \
        wget -c "https://ftp.gnu.org/gnu/bash/${BASH_TAR}"
    fi
    
    tar -zxvf ${BASH_TAR}
    cd $BUILD_PROG_WORKING_DIR/bash-${PKG_VERSIONS[bash]}
    
    setup_toolchain
    
    echo "配置bash..."
    
    ./configure --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --disable-nls \
        --enable-multibyte \
        --enable-static-link \
        --without-bash-malloc \
        bash_cv_dev_fd=whacky \
        bash_cv_job_control_missing=present \
        bash_cv_sys_siglist=yes \
        bash_cv_unusable_rtsigs=no \
        ac_cv_func_mbsnrtowcs=no \
        ac_cv_func_getpwent=no \
        ac_cv_func_getgrent=no \
        ac_cv_func_setgrent=no \
        ac_cv_func_endpwent=no \
        ac_cv_func_mblen=no \
        ac_cv_func_mbrlen=no \
        ac_cv_func_endgrent=no \
        ac_cv_func_getpwnam=no \
        ac_cv_func_getgrnam=no \
        ac_cv_func_getpwuid=no \
        ac_cv_func_mempcpy=no \
        ac_cv_func___fpurge=no \
        ac_cv_func_strchrnul=no \
        ac_cv_func_sigsetmask=no \
        ac_cv_c_bigendian=no \
        bash_cv_getcwd_malloc=yes \
        bash_cv_func_sigsetjmp=present
}

apply_patches_bash() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/bash-${PKG_VERSIONS[bash]}
    for patch_file in ../patch/bash/*.patch; do
        patch -p1 < $patch_file
    done
}

build_bash() {
    echo "开始编译..."
    cd $BUILD_PROG_WORKING_DIR/bash-${PKG_VERSIONS[bash]}
    setup_toolchain
    
    make -j$(nproc)
    make install prefix=../output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv bash-*
    
    unsetup_toolchain
    setup_toolchain
}

configure_zlib() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
    ZLIB_FILE="zlib-${PKG_VERSIONS[zlib]}.tar.gz"
    
    if [ ! -f "${ZLIB_FILE}" ]; then
        wget "https://zlib.net/${ZLIB_FILE}" || \
        wget "https://github.com/madler/zlib/releases/download/v${PKG_VERSIONS[zlib]}/${ZLIB_FILE}"
    fi
    
    tar -zxvf ${ZLIB_FILE}
    
    cd $BUILD_PROG_WORKING_DIR/zlib-${PKG_VERSIONS[zlib]}
    
    echo "配置zlib..."
    
    unsetup_toolchain
    setup_toolchain
    
    LDFLAGS+=" -Wl,--undefined-version"
    echo ${LDFLAGS}
    
    ./configure --prefix="${APP_INSTALL_DIR}" --shared
}

apply_patches_zlib() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/zlib-${PKG_VERSIONS[zlib]}
    
    patch -p1 < ../patch/zlib/1.patch
}

build_zlib() {
    echo "编译..."
    cd $BUILD_PROG_WORKING_DIR/zlib-${PKG_VERSIONS[zlib]}
    
    unsetup_toolchain
    setup_toolchain
    
    LDFLAGS+=" -Wl,--undefined-version"
    
    make -j$(nproc)
    
    unsetup_toolchain
    
    mkdir -p $BUILD_PROG_WORKING_DIR/output
    echo "安装..."
    make install prefix=../output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv zlib-*
}



configure_openssl() {
    cd $BUILD_PROG_WORKING_DIR
    echo "get src..."
    OPENSSL_FILE="openssl-${PKG_VERSIONS[openssl]:2}.tar.gz"
    
    if [ ! -f "${OPENSSL_FILE}" ]; then
        wget https://github.com/openssl/openssl/releases/download/openssl-${PKG_VERSIONS[openssl]:2}/${OPENSSL_FILE}
    fi
    
    tar -zxvf ${OPENSSL_FILE}
    
    cd openssl-${PKG_VERSIONS[openssl]:2}
}

apply_patches_openssl() {
    echo "应用Android补丁..."
    
    cd $BUILD_PROG_WORKING_DIR/openssl-${PKG_VERSIONS[openssl]:2}
    
    for patch_file in ../patch/openssl/*.patch; do
        patch -p1 < $patch_file
    done
}

configure_configure_openssl() {
    cd $BUILD_PROG_WORKING_DIR/openssl-${PKG_VERSIONS[openssl]:2}
    
    CFLAGS+=" -DNO_SYSLOG"
    
    local PLATFORM="android-${TARGET_ARCH}"
    case "$TARGET_ARCH" in
        "arm"|"x86_64");;
        "aarch64") PLATFORM="android-arm64";;
        "i686") PLATFORM="android-x86";;
    esac
    
    ./Configure "$PLATFORM" \
        --prefix="$APP_INSTALL_DIR" \
        --openssldir="$APP_INSTALL_DIR/etc/tls" \
        shared \
        zlib-dynamic \
        no-ssl \
        no-hw \
        no-srp \
        no-tests \
        enable-tls1_3
}

build_openssl() {
    echo "编译..."
    
    CFLAGS+=" -DNO_SYSLOG"
    
    cd $BUILD_PROG_WORKING_DIR/openssl-${PKG_VERSIONS[openssl]:2}
    make depend
    make -j$(nproc) all
    make install OPENSSLDIR=../output/etc/tls INSTALLTOP=../output
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv openssl-*
}

build_ca-certificates() {
    cd $BUILD_PROG_WORKING_DIR
    
    wget "https://curl.se/ca/cacert-$(sed 's/\./-/g' <<< ${PKG_VERSIONS[cacertificates]:2}).pem"
    
    mv $BUILD_PROG_WORKING_DIR/cacert-$(sed 's/\./-/g' <<< ${PKG_VERSIONS[cacertificates]:2}).pem cacert.pem
    
    install_dir
    
    mv cacert.pem $BUILD_PROG_WORKING_DIR/output/etc/tls
}

copy_and_realign() {
    echo "复制已编译文件..."
    cd $BUILD_PROG_WORKING_DIR
    mkdir -p output
    
    case ${NEED_CLEAN_ELF} in
        "true")
            echo "重新对齐ELF..."
            cd termux-elf-cleaner
            
            if [ "${PKG_ENABLE[coreutils]}" = "true" ]; then
                ./termux-elf-cleaner ../output/bin/coreutils
            fi
            
            if [ "${PKG_ENABLE[bash]}" = "true" ]; then
                ./termux-elf-cleaner ../output/bin/bash
            fi
            ;;
        "false")
            echo "Skip!"
            ;;
    esac
}