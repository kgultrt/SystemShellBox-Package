#!/usr/bin/bash

export BUILD_PROG_VERSION="v1.0.6.004"

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
export PROGRESS_FILE="progress_saved.conf"
export PKG_MGR="xdps"

export TOO_LONG_TIME_BREAK=1
export TO_BREAK_TIME=5

export TOO_LONG_TIME_BREAK_WARN_TIMES=1 #全局计数器
export IS_PROGRESS_FILE=0

load_build_script() {
    for script_file in $BUILD_PROG_WORKING_DIR/build_script/*.sh; do
        echo "LOADING $script_file!"
        source $script_file
    done
}


# ===================== 初始化和主程序 =====================

echo
echo "Super Development Environment Build Program ${BUILD_PROG_VERSION}!"
echo

source $BUILD_PROG_WORKING_DIR/build_script/list/pkg_list.sh
echo "LOADED PKG LIST!"

TOTAL_STEPS=${#STEP_NAMES[@]}
echo "TOTAL_STEPS: ${TOTAL_STEPS}"
PKG_TO_BUILD=0

load_build_script

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
load_progress_file

# 启动
echo "Starting..."
main $@
