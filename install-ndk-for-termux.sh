mkdir -p ndk

export TARGET_ARCH="aarch64"

source build_script/setup.sh
source build_script/cil_utils.sh

if [[ -d /data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358 ]]; then
    cil_yesandno 1 "You have installed ndk, do you want to continue? (Will be reinstalled)"
    if [[ $? -eq 0 ]]; then
        rm -rfv /data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358
    else
        exit
    fi
fi

if [ ! -f "ndk/${NDK_FILE}" ]; then
    wget https://github.com/kgultrt/SystemShellBox-Package/releases/download/ndk/${NDK_FILE}
    mv ${NDK_FILE} ndk/${NDK_FILE}
fi

cd ndk

tar --no-same-owner -vxf "${NDK_FILE}" --warning=no-unknown-keyword

mkdir -p /data/data/com.termux/files/home/android-sdk/ndk/

mv android-ndk-r28c /data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358

echo "Succees."