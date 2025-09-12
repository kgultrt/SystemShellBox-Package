#!/usr/bin/bash

export BUILD_PROG_VERSION="v1.0.3"

# ===================== 配置部分 =====================
export ANDROID_NDK="/data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358"
export NDK_BUILD="${ANDROID_NDK}/ndk-build"
export APP_INSTALL_DIR="/data/data/com.manager.ssb/files/usr"
export TARGET_ARCH="aarch64"
export ANDROID_API=21
export BUILD_PROG_WORKING_DIR=$PWD
export OUTPUT_LIB_DIR=$BUILD_PROG_WORKING_DIR/output/lib
export CLEAN_TOOLS=$PWD/termux-elf-cleaner/termux-elf-cleaner
export NEED_CLEAN_ELF="false"
export IS_QUIET=0
export WRITE_LOG=1
export LOG_FILE="progress_$(date +%Y%m%d_%H%M%S).log"
export CONFIG_FILE="config.conf"
export PKG_CONFIG_FILE="pkg_config.conf"
export PKG_MGR="xdps"

# ===================== 包管理系统 =====================

# 包定义结构
declare -A PACKAGES=(
    [xdps]="xdps"
    [coreutils]="coreutils"
    [bash]="bash"
    [zlib]="zlib"
    [cacertificates]="cacertificates"
    [openssl]="openssl"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [xdps]="false"
    [coreutils]="true"
    [bash]="true"
    [zlib]="true"
    [cacertificates]="true"
    [openssl]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [xdps]="0.0"
    [coreutils]="9.7"
    [bash]="5.2.37"
    [zlib]="1.3.1"
    [cacertificates]="1:2025.08.12"
    [openssl]="1:3.5.0"
)

# 包构建步骤映射
declare -A PKG_STEPS=(
    [xdps]="5 6 7"
    [coreutils]="8 9 10 11 12"
    [bash]="13 14 15"
    [zlib]="16 17 18"
    [cacertificates]="19"
    [openssl]="20 21 22 23"
)

# 步骤定义
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "下载xpds源码" #5
    "应用xpds补丁" #6
    "编译xdps" #7
    
    "下载Coreutils源码" #8
    "解压并配置Coreutils" #9
    "应用Coreutils补丁" #10
    "配置Coreutils" #11
    "编译Coreutils" #12
    
    "下载和配置 Bash" #13
    "应用bash补丁" #14
    "编译 Bash" #15
    
    "下载和配置 zlib" #16
    "应用 zlib 补丁" #17
    "编译 zlib" #18
    
    "打包 ca-certificates"
    
    "下载 openssl"
    "应用 openssl 补丁"
    "配置 openssl"
    "编译 openssl"
    
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "clone_termux_elf_cleaner"
    "build_installer"
    
    "configure_xdps"
    "apply_patches_xdps"
    "build_xdps"
    
    "download_coreutils"
    "setup_coreutils"
    "apply_patches"
    "configure_coreutils"
    "build_coreutils"
    
    "configure_bash"
    "apply_patches_bash"
    "build_bash"
    
    "configure_zlib"
    "apply_patches_zlib"
    "build_zlib"
    
    "build_ca-certificates"
    
    "configure_openssl"
    "apply_patches_openssl"
    "configure_configure_openssl"
    "build_openssl"
    
    "copy_and_realign"
    "package_output"
)

# 配置项定义：变量=描述
declare -A CONFIG_ITEMS=(
    [ANDROID_NDK]="Android NDK路径"
    [APP_INSTALL_DIR]="安装目录"
    [TARGET_ARCH]="目标架构"
    [ANDROID_API]="Android API级别"
    [NEED_CLEAN_ELF]="是否对齐 ELF 头"
    [IS_QUIET]="安静输出"
    [WRITE_LOG]="安静模式下保存日志"
)

# 类型定义：变量=输入方式
declare -A CONFIG_TYPES=(
    [ANDROID_NDK]="path"
    [APP_INSTALL_DIR]="path"
    [TARGET_ARCH]="arch"
    [ANDROID_API]="number"
    [NEED_CLEAN_ELF]="bool"
    [IS_QUIET]="boolnum"
    [WRITE_LOG]="boolnum"
)

TOTAL_STEPS=${#STEP_NAMES[@]}
PKG_TO_BUILD=0

# ===================== 通用功能函数 =====================

# 带进度条的显示函数
show_progress() {
    local width=50
    local percent=$1
    local completed=$((width * percent / 100))
    local remaining=$((width - completed))
    
    # 创建进度条字符串
    local progress_bar="\e[44m"
    for ((i=0; i<completed; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m\e[47m"
    for ((i=0; i<remaining; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m"
    
    # 显示进度条
    tput sc  # 保存光标位置
    tput cup 0 0  # 移动到屏幕顶部
    echo -ne "\r[${progress_bar}] ${percent}%"
    tput rc  # 恢复光标位置
}

# 更新进度并显示
update_progress() {
    local current_step=$1
    local percent=$((100 * current_step / TOTAL_STEPS))
    
    show_progress $percent
    
    # 完成后换行
    if [[ $current_step -eq $TOTAL_STEPS ]]; then
        echo
    fi
}

# 旋转动画函数（安静模式使用）
spinner() {
    local pid=$1
    local delay=1
    local spinstr='/-\|'
    local i=0
    
    echo
    
    while ps -p $pid > /dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        printf "\rPlease wait... $temp ($is)"
        sleep $delay
    done
    
    printf "\rPlease wait... "
}

# 执行命令并显示进度
run_step() {
    local step_name="$1"
    local step_func="$2"
    local step_num=$3
    pkg_check ${step_num}
    local check_result=$?
    
    echo $check_result
    
    # 记录开始时间
    local start_time=$(date +%s.%N)
    
    # 显示步骤开始
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\n\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}...\e[0m"
    else
        # 安静模式下显示步骤名称和spinner
        printf "\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}\e[0m "
    fi
    
    if [ $check_result -eq 1 ]; then
        echo "Skip it because it has been disabled!"
        # 更新进度条
        update_progress $step_num
        return
    fi
    
    # 执行步骤函数
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        # 非安静模式：显示命令输出
        $step_func
    else
        if [ -z "$WRITE_LOG" ] || [ "$WRITE_LOG" -ne 1 ]; then
            # 安静模式：重定向输出到日志文件并显示spinner
            ($step_func >> "$LOG_FILE" 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        else
            ($step_func>/dev/null 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        fi
    fi
    
    # 计算并显示步骤耗时
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc | awk '{printf "%.2f", $0}')
    
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m"
        echo
    else
        printf "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m\n"
        echo
    fi
    
    # 更新进度条
    update_progress $step_num
    
    # 刷新，清除可能多余的构建参数
    unsetup_toolchain
    setup_toolchain
}

pkg_check() {
    local step_num=$1
    local return_num=0
    
    for pkg in "${!PKG_STEPS[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "false" ]; then
            # 检查步骤是否属于这个包
            if echo "${PKG_STEPS[$pkg]}" | grep -q "\<$step_num\>"; then
                return_num=1
                break
            fi
        fi
    done
    
    return ${return_num}
}

# ===================== 工具链函数 =====================

# 设置工具链
setup_toolchain() {
    TOOLCHAIN_ROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
    case "${TARGET_ARCH}" in
        aarch64)
            export TARGET_HOST="aarch64-linux-android"
            export TOOL_PREFIX="${TARGET_HOST}${ANDROID_API}-"
            ;;
        arm)
            export TARGET_HOST="armv7a-linux-androideabi"
            export TOOL_PREFIX="${TARGET_HOST}${ANDROID_API}-"
            ;;
        x86)
            export TARGET_HOST="i686-linux-android"
            export TOOL_PREFIX="${TARGET_HOST}${ANDROID_API}-"
            ;;
        x86_64)
            export TARGET_HOST="x86_64-linux-android"
            export TOOL_PREFIX="${TARGET_HOST}${ANDROID_API}-"
            ;;
    esac

    export CC="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang"
    export CXX="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang++"
    export AR="${TOOLCHAIN_ROOT}/bin/llvm-ar"
    export OBJCOPY="${TOOLCHAIN_ROOT}/bin/llvm-objcopy"
    export OBJDUMP="${TOOLCHAIN_ROOT}/bin/llvm-objdump"
    export RANLIB="${TOOLCHAIN_ROOT}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN_ROOT}/bin/llvm-strip"
    export LD="${TOOLCHAIN_ROOT}/bin/ld.lld"
    
    export CFLAGS="-fPIE -fPIC -Os \
    -DNO_MKTIME_Z -D__USE_ANDROID_STDIO -DANDROID_USER_FUNCTIONS \
    -DHAVE___FPURGE=0 -DHANDLE_MULTIBYTE -Wno-everything"
    export LDFLAGS="-fPIE -pie"
    
    export LDSHARED="${CC} -fPIE -pie -shared"
    
    if [ "$TARGET_ARCH" = "aarch64" ]; then
        CFLAGS+=" -march=armv8-a+crc"
        CXXFLAGS+=" -march=armv8-a+crc"
    fi
    
    # 设置环境变量
    export ac_cv_func_getpwent=no
    export ac_cv_func_endpwent=no
    export ac_cv_func_getpwnam=no
    export ac_cv_func_getpwuid=no
    export ac_cv_func_sigsetmask=no
    export ac_cv_c_bigendian=no
    export ac_cv_func_setgrent=no
    export ac_cv_func_getgrent=no
    export ac_cv_func_endgrent=no
}

unsetup_toolchain() {
    unset CC
    unset CXX
    unset AR
    unset OBJCOPY
    unset OBJDUMP
    unset RANLIB
    unset STRIP
    unset LD
    unset CFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset LDSHARED
}

# ===================== 构建步骤函数 =====================

install_dependencies() {
    echo "更新包索引..."
    apt update -y
    
    echo "安装依赖包..."
    apt install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip dialog
    
    export BUILD_PROG_WORKING_DIR=$PWD
}

install_dir() {
    mkdir -p $BUILD_PROG_WORKING_DIR/output
    mkdir -p $BUILD_PROG_WORKING_DIR/output/lib
    mkdir -p $BUILD_PROG_WORKING_DIR/output/bin
    mkdir -p $BUILD_PROG_WORKING_DIR/output/etc
    mkdir -p $BUILD_PROG_WORKING_DIR/output/etc/tls
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
    
    cp $INSTALLER_PATH $BUILD_PROG_WORKING_DIR/base/home/.term
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
    cp $BUILD_PROG_WORKING_DIR/zlib-${PKG_VERSIONS[zlib]}/libz.so* $OUTPUT_LIB_DIR
}

configure_xdps() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
}

apply_patches_xdps() {
    echo "应用Android补丁..."
}

build_xdps() {
    echo "编译..."
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
    
    patch -p1 < ../patch/openssl/afterc/1.patch
    
    make install
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
    
    if [ "${PKG_ENABLE[coreutils]}" = "true" ]; then
        cp coreutils-${PKG_VERSIONS[coreutils]}/src/coreutils output/bin
    fi
    
    if [ "${PKG_ENABLE[bash]}" = "true" ]; then
        cp bash-${PKG_VERSIONS[bash]}/bash output/bin
    fi
    
    if [ "${PKG_ENABLE[zlib]}" = "true" ]; then
        cp -r $BUILD_PROG_WORKING_DIR/zlib-${PKG_VERSIONS[zlib]}/libz.so* output/lib
    fi
    
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

package_output() {
    echo "打包..."
    
    cd $BUILD_PROG_WORKING_DIR
    cp -r ./output/* ./base
    cd base
    zip -r base.zip *
    cd ..
    mv base/base.zip output/
    
    echo "运行事务后清理..."
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rf coreutils-${PKG_VERSIONS[coreutils]}
    rm -rf bash-${PKG_VERSIONS[bash]}
    rm -rf zlib-${PKG_VERSIONS[zlib]}
    rm -rf openssl-${PKG_VERSIONS[openssl]}
    rm -rf termux-elf-cleaner
    
    echo "完成"
}

# ===================== UI 函数 =====================

# 结果显示
result_display() {
    echo "========================================================"
    if [ -f "output/base.zip" ]; then
        echo -e "\e[1;32m编译完成！\e[0m"
        echo "输出文件: output/base.zip"
        echo "目标架构: $TARGET_ARCH"
        echo "安装目录: $APP_INSTALL_DIR"
        echo "构建的包:"
        for pkg in "${!PACKAGES[@]}"; do
            if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
                echo "  - ${PACKAGES[$pkg]} (${PKG_VERSIONS[$pkg]})"
            fi
        done
    else
        echo -e "\e[1;31m编译未完成或出错！请检查日志。\e[0m"
    fi
    echo "========================================================"
    
    # 安静模式：显示总耗时
    if [ -n "$IS_QUIET" ] && [ "$IS_QUIET" -eq 1 ]; then
        local total_end_time=$(date +%s.%N)
        local total_elapsed_time=$(echo "$total_end_time - $total_start_time" | bc | awk '{printf "%.2f", $0}')
        echo -e "\n\e[1;32m[OK] 所有步骤完成! 总耗时: ${total_elapsed_time}秒\e[0m"
    fi
    
    sleep 5 #给用户留时间查看
}

# 完整构建流程
full_build_process() {
    # 显示开始信息
    clear
    echo "==========================================="
    echo " Super Development Environment 编译程序"
    echo "==========================================="
    echo "总包: ${#PACKAGES[@]} 个包"
    echo "将要构建: ${PKG_TO_BUILD} 个包"
    echo -e "\n\e[1;33m将在3秒后开始...\e[0m"
    sleep 3
    
    clear
    
    # 准备进度显示
    local current_step=0
    
    # 记录总开始时间（安静模式用）
    export total_start_time=$(date +%s.%N)
    trap 'echo -e "\rPlease wait... \e[1;31m[FAILED]\e[0m 用户取消操作!" && echo && exit' SIGINT SIGTERM
    
    echo -e "\n"  # 为进度条留出空间
    
    # 显示初始进度条
    echo -e "\n\e[1;32m编译进度:\e[0m"
    show_progress 0
    
    # 按顺序执行各步骤
    for ((cstep=0; cstep<TOTAL_STEPS; cstep++)); do
        ((current_step++))
        run_step "${STEP_NAMES[cstep]}" "${STEP_FUNCTIONS[cstep]}" $current_step
    done
    
    # 显示完成信息
    result_display
}

# 手动构建步骤
manual_build_steps() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        for ((i=0; i<TOTAL_STEPS; i++)); do
            options+=("$((i+1))" "${STEP_NAMES[i]}")
        done
        
        choice=$(dialog --backtitle "构建步骤" \
                     --title "手动构建" \
                     --menu "选择要执行的步骤：" 17 50 8 \
                     "${options[@]}" \
                     3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -ge 1 && $choice -le $TOTAL_STEPS ]]; then
            local step_index=$((choice-1))
            echo -e "\n\e[1;34m步骤: ${STEP_NAMES[step_index]}...\e[0m"
            run_step "手动" ${STEP_FUNCTIONS[step_index]} 99999
        fi
    done
}

# ==================== 保存/加载配置 ====================

# 保存配置到文件
save_config() {
    > "$CONFIG_FILE"
    for key in "${!CONFIG_ITEMS[@]}"; do
        echo "$key=\"${!key}\"" >> "$CONFIG_FILE"
    done
    dialog --msgbox "配置已保存到 $CONFIG_FILE" 7 50
}

# 从文件加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "NO CONFIG!"
    fi
}

# ==================== 编辑配置 ====================

edit_config() {
    local var="$1"
    local type="${CONFIG_TYPES[$var]}"
    local current="${!var}"
    local new_value

    case "$type" in
        path|number)
            new_value=$(dialog --inputbox "输入 ${CONFIG_ITEMS[$var]}:" 8 50 "$current" 3>&1 1>&2 2>&3 3>&-)
            ;;
        bool)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 30 5 \
                true "启用" \
                false "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        boolnum)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 50 5 \
                1 "启用" \
                0 "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        arch)
            new_value=$(dialog --menu "选择目标架构:" 12 30 5 \
                aarch64 "ARM64 (推荐)" \
                arm "ARM32" \
                x86 "x86" \
                x86_64 "x86_64" 3>&1 1>&2 2>&3 3>&-)
            ;;
    esac

    [ -n "$new_value" ] && export "$var=$new_value"
}

configure_settings() {
    while true; do
        menu_items=()
        menu_items+=("0" "返回")
        menu_items+=("S" "保存配置")
        i=1
        for key in "${!CONFIG_ITEMS[@]}"; do
            value="${!key}"
            menu_items+=("$i" "${CONFIG_ITEMS[$key]} [$value]")
            keys[$i]="$key"
            ((i++))
        done
        
        choice=$(dialog --menu "选择要修改的配置：" 20 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3 3>&-)

        case "$choice" in
            0|"") break ;;
            S) save_config ;;
            *) edit_config "${keys[$choice]}" ;;
        esac
    done
}

# ==================== 包管理函数 ====================

# 保存包配置
save_pkg_config() {
    > "$PKG_CONFIG_FILE"
    for pkg in "${!PACKAGES[@]}"; do
        echo "PKG_ENABLE_${pkg}=\"${PKG_ENABLE[$pkg]}\"" >> "$PKG_CONFIG_FILE"
    done
    for pkg in "${!PACKAGES[@]}"; do
        echo "PKG_VERSION_${pkg}=\"${PKG_VERSIONS[$pkg]}\"" >> "$PKG_CONFIG_FILE"
    done
    echo "PKG_TO_BUILD=${PKG_TO_BUILD}" >> "$PKG_CONFIG_FILE"
    dialog --msgbox "包配置已保存到 $PKG_CONFIG_FILE" 7 50
}

# 加载包配置
load_pkg_config() {
    if [[ -f "$PKG_CONFIG_FILE" ]]; then
        source "$PKG_CONFIG_FILE"
        # 将加载的配置应用到数组
        for pkg in "${!PACKAGES[@]}"; do
            local enable_var="PKG_ENABLE_${pkg}"
            local version_var="PKG_VERSION_${pkg}"
            if [ -n "${!enable_var}" ]; then
                PKG_ENABLE["$pkg"]="${!enable_var}"
            fi
            if [ -n "${!version_var}" ]; then
                PKG_VERSIONS["$pkg"]="${!version_var}"
            fi
        done
    else
        echo "NO PKG CONFIG!"
    fi
    
    # 计算要构建的包数量
    PKG_TO_BUILD=0
    for pkg in "${!PACKAGES[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
            ((PKG_TO_BUILD++))
        fi
    done
}

# 包管理菜单
package_management_menu() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        options+=("1" "保存配置")
        
        local i=2
        for pkg in "${!PACKAGES[@]}"; do
            local status="禁用"
            [ "${PKG_ENABLE[$pkg]}" = "true" ] && status="启用"
            options+=("$i" "${PACKAGES[$pkg]} [$status]")
            pkg_keys[$i]="$pkg"
            ((i++))
        done
        
        choice=$(dialog --menu "包管理 - 选择要配置的包：" 17 50 8 \
                 "${options[@]}" \
                 3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -eq 1 ]]; then
            save_pkg_config
        elif [[ -n "${pkg_keys[$choice]}" ]]; then
            configure_package "${pkg_keys[$choice]}"
        fi
    done
}

# 配置单个包
configure_package() {
    local pkg=$1
    local current_enable="${PKG_ENABLE[$pkg]}"
    local current_version="${PKG_VERSIONS[$pkg]}"
    
    while true; do
        choice=$(dialog --menu "配置 ${PACKAGES[$pkg]}：" 12 40 5 \
                 1 "启用状态: $current_enable" \
                 2 "版本: $current_version" \
                 3 "返回" \
                 3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1)
                new_value=$(dialog --menu "选择启用状态：" 10 30 3 \
                          "true" "启用" \
                          "false" "禁用" \
                          3>&1 1>&2 2>&3 3>&-)
                if [ -n "$new_value" ]; then
                    PKG_ENABLE[$pkg]="$new_value"
                    current_enable="$new_value"
                    # 更新构建计数
                    if [ "$new_value" = "true" ]; then
                        ((PKG_TO_BUILD++))
                    else
                        ((PKG_TO_BUILD--))
                    fi
                fi
                ;;
            2)
                new_value=$(dialog --inputbox "输入版本号：" 8 40 "$current_version" \
                          3>&1 1>&2 2>&3 3>&-)
                if [ -n "$new_value" ]; then
                    PKG_VERSIONS[$pkg]="$new_value"
                    current_version="$new_value"
                fi
                ;;
            3|"") break ;;
        esac
    done
}

# 清理输出
clean_output() {
    if dialog --yesno "确定要清理所有输出文件吗?" 7 50; then
        echo "清理输出文件..."
        
        rm -rf termux-elf-cleaner coreutils-* output bash-* zlib-* \
            openssl-*
        
        cd installer
        rm -rf libs obj
        cd $BUILD_PROG_WORKING_DIR
        rm -rf base
        
        unzip base.zip
        
        dialog --msgbox "输出文件已清理！" 6 40
    fi
}

# 主菜单
main_menu() {
    while true; do
        choice=$(dialog --backtitle "Super Development Environment 编译程序 (${BUILD_PROG_VERSION}, ${#PACKAGES[@]}个包可用, 构建${PKG_TO_BUILD}个包)" \
                        --title "主菜单" \
                        --menu "请选择操作：" 15 50 6 \
                        1 "完整构建流程" \
                        2 "手动构建步骤" \
                        3 "配置设置" \
                        4 "清理输出" \
                        5 "包管理" \
                        0 "退出" \
                        3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1) full_build_process ;;
            2) manual_build_steps ;;
            3) configure_settings ;;
            4) clean_output ;;
            5) package_management_menu ;;
            0) clear && exit 0 ;;
            *) return ;;
        esac
    done
}

# ===================== 初始化和主程序 =====================

# 检查并安装dialog
if ! command -v dialog &>/dev/null; then
    echo "安装dialog..."
    apt install -y dialog
fi

if ! command -v bc &>/dev/null; then
    echo "安装bc..."
    apt install -y bc
fi

# 加载主配置
load_config
load_pkg_config

# 启动主菜单
main_menu