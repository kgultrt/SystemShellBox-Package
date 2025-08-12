cd .
cd ndk

tar --no-same-owner -vxf "android-ndk-r28c-aarch64-linux-musl.tar.xz" --warning=no-unknown-keyword

mkdir -p /data/data/com.termux/files/home/android-sdk/ndk/

mv android-ndk-r28c /data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358

echo "Succees."