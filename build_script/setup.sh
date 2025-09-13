case "${TARGET_ARCH}" in
    aarch64)
        export NDK_FILE="android-ndk-r28c-aarch64-linux-musl.tar.xz"
        ;;
    arm)
        export NDK_FILE="android-ndk-r28c-arm-linux-musleabi.tar.xz"
        ;;
    x86)
        export NDK_FILE="android-ndk-r28c-x86-linux-musl.tar.xz"
        ;;
    x86_64)
        export NDK_FILE="android-ndk-r28c-x86_64-linux-musl.tar.xz"
        ;;
esac