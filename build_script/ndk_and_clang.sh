#!/usr/bin/bash

build_androidndk() {
    echo "download ndk!"
    
    cd $BUILD_PROG_WORKING_DIR
    
    case "${TARGET_ARCH}" in
        aarch64)
            NDK_FILE="android-ndk-r28c-aarch64-linux-musl.tar.xz"
            ;;
        arm)
            NDK_FILE="android-ndk-r28c-arm-linux-musleabi.tar.xz"
            ;;
        x86)
            NDK_FILE="android-ndk-r28c-x86-linux-musl.tar.xz"
            ;;
        x86_64)
            NDK_FILE="android-ndk-r28c-x86_64-linux-musl.tar.xz"
            ;;
    esac
    
    if [ ! -f "${NDK_FILE}" ]; then
        wget https://github.com/kgultrt/SystemShellBox-Package/releases/download/ndk/${NDK_FILE}
    fi
    
    cd $BUILD_PROG_WORKING_DIR
    tar --no-same-owner -vxf ${NDK_FILE} --warning=no-unknown-keyword

}