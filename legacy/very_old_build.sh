#!/data/data/com.termux/files/usr/bin/bash
echo "Super Development Environment 编译程序"
sleep 2
echo "将在3秒后开始..."
sleep 1
echo "将在2秒后开始..."
sleep 1
echo "将在1秒后开始..."
sleep 1


export BUILD_PROG_WORKING_DIR=$PWD

# 安装必要依赖
echo "正在安装依赖..."
pkg update -y
pkg install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip

cd $BUILD_PROG_WORKING_DIR
echo "克隆..."
git clone https://github.com/termux/termux-elf-cleaner.git
cd termux-elf-cleaner
echo "补丁..."
patch -p1 < ../patch/RealignFile/fixcleaner.patch
bash ../cleaneif.sh
cd $BUILD_PROG_WORKING_DIR

# 配置参数并构建安装程序
export ANDROID_NDK="/data/data/com.termux/files/home/android-sdk/ndk/27.2.12479018"
export APP_INSTALL_DIR="/data/data/com.manager.ssb/files/usr"
export TARGET_ARCH="aarch64"  # 可选: aarch64, arm, x86, x86_64
export ANDROID_API=21

cd installer/jni
echo "构建环境安装程序 (注意: 非跨平台)..."
gcc main.c -o installer
cp installer $BUILD_PROG_WORKING_DIR/base/home/.term
cd $BUILD_PROG_WORKING_DIR

export ac_cv_func_getpwent=no
export ac_cv_func_endpwent=no
export ac_cv_func_getpwnam=no
export ac_cv_func_getpwuid=no
export ac_cv_func_sigsetmask=no
export ac_cv_c_bigendian=no

# 设置工具链
TOOLCHAIN_ROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
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

# 配置编译器
export CC="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang"
export CXX="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang++"
export AR="${TOOLCHAIN_ROOT}/bin/llvm-ar"
export RANLIB="${TOOLCHAIN_ROOT}/bin/llvm-ranlib"
export STRIP="${TOOLCHAIN_ROOT}/bin/llvm-strip"
export LD="${TOOLCHAIN_ROOT}/bin/ld.lld"

# 设置编译标志
export CFLAGS="-fPIE -fPIC -Os -static \
-DNO_MKTIME_Z -D__USE_ANDROID_STDIO -DANDROID_USER_FUNCTIONS \
-DHAVE_WORKING_GETPWENT=0"
export LDFLAGS="-static -fPIE -pie"

# 获取coreutils源码（更快的方式）
echo "下载coreutils源码..."
COREUTILS_VERSION="9.7"
COREUTILS_TAR="coreutils-${COREUTILS_VERSION}.tar.xz"
if [ ! -f "${COREUTILS_TAR}" ]; then
    wget -c "https://mirrors.ustc.edu.cn/gnu/coreutils/${COREUTILS_TAR}" \
      || wget -c "https://ftp.gnu.org/gnu/coreutils/${COREUTILS_TAR}"
fi

# 解压并进入目录
echo "解压源码..."
tar xf "${COREUTILS_TAR}"
cd "coreutils-${COREUTILS_VERSION}"

echo "应用Android补丁... (from termux and me)"
echo "1/9"
patch -p1 < ../patch/coreutils/configure.patch
echo "2/9"
patch -p1 < ../patch/coreutils/date.c.patch
echo "3/9"
patch -p1 < ../patch/coreutils/fix-paths.patch
echo "4/9"
patch -p1 < ../patch/coreutils/nohup.c.patch
echo "5/9"
patch -p1 < ../patch/coreutils/pwd.c.patch
echo "6/9"
patch -p1 < ../patch/coreutils/selinux.patch
echo "7/9"
patch -p1 < ../patch/coreutils/src-hostid.c.patch
echo "8/9"
patch -p1 < ../patch/coreutils/src-ls.c.patch
echo "9/9"
patch -p1 < ../patch/coreutils/fix-time.patch

echo "补丁应用完成"

# 配置编译参数
echo "配置coreutils..."
# (╯‵□′)╯︵┻━┻
./configure \
    --host="${TARGET_HOST}" \
    --prefix="${APP_INSTALL_DIR}" \
    --enable-single-binary=symlinks \
    --disable-xattr \
    --with-gnu-ld \
    --disable-year2038 \
    --enable-no-install-program=pinky,df,users,who,uptime,stdbuf \
    --with-packager=SuperDevelopmentEnvironment_$(date '+%Y-%m-%d-%H:%M:%S') \
    ac_cv_func_malloc_0_nonnull=yes \
    ac_cv_func_realloc_0_nonnull=yes \
    gl_cv_header_working_stdint_h=yes \
    gl_cv_host_operating_system=Android \
    ac_cv_func_getpass=yes \
    gl_cv_func_isnanl_works=yes \
    ac_cv_func_getpwent=no \
    ac_cv_func_getgrent=no \
    ac_cv_func_endpwent=no \
    ac_cv_func_endgrent=no \
    ac_cv_func_getpwnam=no \
    ac_cv_func_getgrnam=no \
    ac_cv_func_getpwuid=no \
    ac_cv_func_sigsetmask=no \
    ac_cv_func_statx=no \
    ac_cv_func_nl_langinfo=no \
    ac_cv_func_syncfs=no \
    ac_cv_func_sethostname=no \
    ac_cv_c_bigendian=no \
    ac_cv_func_getnameinfo=no \
    ac_cv_func_tzfree=yes \
    ac_cv_func_tzalloc=yes


# 编译安装
echo "开始编译..."
make -j$(nproc)

echo "复制已编译文件..."
cd $BUILD_PROG_WORKING_DIR
mkdir -p output
cd output
cp ../coreutils-${COREUTILS_VERSION}/src/coreutils .

echo "重新对齐..."
cd $BUILD_PROG_WORKING_DIR/termux-elf-cleaner
./termux-elf-cleaner ../output/*

echo "打包..."
cd $BUILD_PROG_WORKING_DIR
cp ./output/* ./base/bin
cd base
zip -r base.zip *
cd $BUILD_PROG_WORKING_DIR
rm -rf ./output
mkdir -p output
mv base/base.zip output

echo "针对${APP_INSTALL_DIR}的Super Development Environment环境已编译完成"
echo "你可以在 output 目录下找到zip文件"