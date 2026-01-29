#!/usr/bin/bash

# ===================== 工具链函数 =====================

# 设置工具链
setup_toolchain() {
    local toolchain_load_function=$1
    
    if [[ toolchain_load_function -ne "" ]]; then
        $toolchain_load_function
        return 0
    fi
    
    export TOOLCHAIN_ROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
    
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
    export LDFLAGS="-fPIE -pie -Wl,-rpath=$APP_INSTALL_DIR/lib"
    export CPPFLAGS=""
    
    export CPPFLAGS+=" -isystem$APP_INSTALL_DIR/include/c++/v1 -isystem$APP_INSTALL_DIR/include"
    export LDSHARED="${CC} -fPIE -pie -shared"
    
    if $LOCALE_HAS_BUILDED; then
        LDFLAGS="-L$OUTPUT_LIB_DIR -llocal $LDFLAGS"
        CPPFLAGS="-I$OUTPUT_INC_DIR $CPPFLAGS"
    fi
    
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
    
    echo
    echo "__TOOLCHAIN__"
    echo "======================================="
    echo "info:"
    echo "CFLAGS= ${CFLAGS}"
    echo "CPPFLAGS= ${CPPFLAGS}"
    echo "LDFLAGS= ${LDFLAGS}"
    echo "LDSHARED= ${LDSHARED}"
    echo "CXXFLAGS= ${CXXFLAGS}"
    echo "======================================="
    echo
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
    
    echo "__UNSET_TOOLCHAIN__"
}