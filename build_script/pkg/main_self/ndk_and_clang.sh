#!/usr/bin/bash

build_clang() {
    echo "download ndk!"
    
    cd $BUILD_PROG_WORKING_DIR
    
    if [ ! -f "ndk/${NDK_FILE}" ]; then
        cd ndk
        wget https://github.com/kgultrt/SystemShellBox-Package/releases/download/ndk/${NDK_FILE}
    fi
    cd $BUILD_PROG_WORKING_DIR/ndk
    tar --no-same-owner -vxf "${NDK_FILE}" --warning=no-unknown-keyword
    mv -v android-ndk-r28c ndk-env
    
    mv -v ndk-env $BUILD_PROG_WORKING_DIR/output/

}