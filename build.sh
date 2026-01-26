#!/usr/bin/bash

export BUILD_PROG_VERSION="v1.0.9"

# ===================== 配置部分 =====================
export APP_DIR="/data/data/com.manager.ssb/files"
export APP_INSTALL_DIR="$APP_DIR/usr"
export APP_HOME_DIR="$APP_INSTALL_DIR/home"
export APP_LIB_DIR="$APP_INSTALL_DIR/lib"
export TARGET_ARCH="aarch64"
export ANDROID_API=21
export BUILD_PROG_WORKING_DIR=$PWD
export ANDROID_NDK="${BUILD_PROG_WORKING_DIR}/ndk/28.2.13676358"
export NDK_BUILD="${ANDROID_NDK}/ndk-build"
export OUTPUT_LIB_DIR=$BUILD_PROG_WORKING_DIR/output/lib
export OUTPUT_INC_DIR=$BUILD_PROG_WORKING_DIR/output/include
export CLEAN_TOOLS=$PWD/termux-elf-cleaner/termux-elf-cleaner
export NEED_CLEAN_ELF="false"
export IS_QUIET=0
export WRITE_LOG=1
export PKG_MGR="pacman"
export TOO_LONG_TIME_BREAK=1
export TO_BREAK_TIME=5
export DISADIE_PROGRESS=1

# 全局计数器/变量
export TOO_LONG_TIME_BREAK_WARN_TIMES=1
export IS_PROGRESS_FILE=0
export LOG_FILE="progress_$(date +%Y%m%d_%H%M%S).log"
export CONFIG_FILE="config.conf"
export PKG_CONFIG_FILE="pkg_config.conf"
export PROGRESS_FILE="progress_saved.conf"
export SYSTEM_CHECK_FILE="build_script/system.sh"
export IS_LIUNX=0
export LIUNX_TYPE=0
export BRANCH=$(cat $BUILD_PROG_WORKING_DIR/branch)
export NDK_HAS_PATCHED=0
export SPM_HAS_BUILDED=false
export LOCALE_HAS_BUILDED=false

load_build_script() {
    local files_count=0
    
    for script_file in $BUILD_PROG_WORKING_DIR/build_script/*.sh; do
        echo "LOADING $script_file!"
        source $script_file
        files_count=$((files_count+1))
    done
    
    echo
    echo "Successfully loaded $files_count files!"
    echo
    
    local files_count=0
    
    if [ ! -d $BUILD_PROG_WORKING_DIR/build_script/pkg/$BRANCH ]; then
        cil_yesandno 0 "这个分支 ($BRANCH) 是无效的，你想要修改它吗？"
        local choose=$?
        if [[ $choose -eq 0 ]]; then
            change_branch
        else
            echo "将退出程序"
            prog_exit 0
        fi
    fi
    
    for script_file in $BUILD_PROG_WORKING_DIR/build_script/pkg/$BRANCH/*.sh; do
        echo "LOADING $script_file!"
        source $script_file
        files_count=$((files_count+1))
    done
    
    echo
    echo "Successfully loaded $files_count files!"
    echo
}

prog_exit() {
    local num=$1
    
    save_prog_data
    
    if [[ num -eq "" ]]; then
        exit 0
    fi
    
    exit $num
}

# ===================== 初始化和主程序 =====================

echo
echo "Super Development Environment Build Program ${BUILD_PROG_VERSION}!"
echo

if [ ! -d "build_script" ]; then
    echo
    echo "程序不完整!"
    echo "请检查:"
    echo "1. build_script 文件夹是否存在"
    echo "2. 你所在的运行目录, 当前的运行目录是: $BUILD_PROG_WORKING_DIR"
    echo
    prog_exit 255
else
    echo
    echo "START LOADING!"
    echo
fi


load_build_script

export WILL_LOAD_BRANCH_FILE="${BRANCH}.sh"
source $BUILD_PROG_WORKING_DIR/build_script/list/${WILL_LOAD_BRANCH_FILE}
echo "LOADED PKG LIST!"
source $BUILD_PROG_WORKING_DIR/build_script/config/config.sh
echo "LOADED CONFIG LIST!"

TOTAL_STEPS=${#STEP_NAMES[@]}
echo "TOTAL_STEPS: ${TOTAL_STEPS}"
PKG_TO_BUILD=0

echo

if [[ ! -f ${SYSTEM_CHECK_FILE} ]]; then
    echo
    check_system
fi

if [ -f $BUILD_PROG_WORKING_DIR/build_script/config/data.txt ]; then
    source $BUILD_PROG_WORKING_DIR/build_script/config/data.txt
    rm -rf $BUILD_PROG_WORKING_DIR/build_script/config/data.txt
fi

# 检查并安装dialog
if ! command -v dialog &>/dev/null; then
    echo "安装dialog..."
    if [[ $IS_LIUNX -eq 1 ]]; then
        sudo apt install -y dialog
    else
        apt install -y dialog
    fi
fi

if ! command -v bc &>/dev/null; then
    echo "安装bc..."
    if [[ $IS_LIUNX -eq 1 ]]; then
        sudo apt install -y bc
    else
        apt install -y bc
    fi
fi

# 加载主配置
load_config
load_pkg_config
load_progress_file

# 启动
echo "load Complete! we will start it!"
echo "Starting..."

main $@
