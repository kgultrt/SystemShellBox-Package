#!/usr/bin/bash

export BUILD_PROG_VERSION="v1.0.4"

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
    [androidndk]="androidndk"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [xdps]="false"
    [coreutils]="true"
    [bash]="true"
    [zlib]="true"
    [cacertificates]="true"
    [openssl]="true"
    [androidndk]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [xdps]="0.0"
    [coreutils]="9.7"
    [bash]="5.2.37"
    [zlib]="1.3.1"
    [cacertificates]="1:2025.08.12"
    [openssl]="1:3.5.0"
    [androidndk]="r28c"
)

# 包构建步骤映射
declare -A PKG_STEPS=(
    [xdps]="5 6 7"
    [coreutils]="8 9 10 11 12"
    [bash]="13 14 15"
    [zlib]="16 17 18"
    [cacertificates]="19"
    [openssl]="20 21 22 23"
    [androidndk]="24"
)

# 步骤定义
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    "下载xpds源码"
    "应用xpds补丁"
    "编译xdps"
    "下载Coreutils源码"
    "解压并配置Coreutils"
    "应用Coreutils补丁"
    "配置Coreutils"
    "编译Coreutils"
    "下载和配置 Bash"
    "应用bash补丁"
    "编译 Bash"
    "下载和配置 zlib"
    "应用 zlib 补丁"
    "编译 zlib"
    "打包 ca-certificates"
    "下载 openssl"
    "应用 openssl 补丁"
    "配置 openssl"
    "编译 openssl"
    "下载和打包 androidndk"
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
    "build_androidndk"
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
echo ${TOTAL_STEPS}
PKG_TO_BUILD=0

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

load_build_script() {
    for script_file in $BUILD_PROG_WORKING_DIR/build_script/*.sh; do
        echo "loading $script_file!"
        source $script_file
    done
}

load_build_script

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