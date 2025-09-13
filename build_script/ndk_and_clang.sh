#!/usr/bin/bash

build_androidndk() {
    echo "download ndk!"
    
    cd $BUILD_PROG_WORKING_DIR
    
    if [ ! -f "${NDK_FILE}" ]; then
        wget https://github.com/kgultrt/SystemShellBox-Package/releases/download/ndk/${NDK_FILE}
    fi
    
    cd $BUILD_PROG_WORKING_DIR
    tar --no-same-owner -vxf ${NDK_FILE} --warning=no-unknown-keyword

}