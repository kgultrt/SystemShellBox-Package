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
    mkdir -p $BUILD_PROG_WORKING_DIR/output/include
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