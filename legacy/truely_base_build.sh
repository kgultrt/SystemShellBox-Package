#!/data/data/com.termux/files/usr/bin/bash

# 安装TUI依赖
install_tui_deps() {
    if ! command -v dialog &>/dev/null; then
        echo "安装dialog..."
        pkg install -y dialog
    fi
}

# 主菜单
main_menu() {
    while true; do
        choice=$(dialog --backtitle "Super Development Environment 编译程序" \
                        --title "主菜单" \
                        --menu "请选择操作：" 15 50 5 \
                        1 "完整构建流程" \
                        2 "手动构建步骤" \
                        3 "配置设置" \
                        4 "清理输出" \
                        0 "退出" \
                        3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1) full_build_process ;;
            2) manual_build_steps ;;
            3) configure_settings ;;
            4) clean_output ;;
            0) exit 0 ;;
            *) return ;;
        esac
    done
}

# 完整构建流程
full_build_process() {
    (
        install_dependencies
        # clone_and_patch
        build_installer
        download_coreutils
        apply_patches
        configure_and_build
        package_output
    ) | dialog --backtitle "构建进度" --title "完整构建" --progressbox "正在执行完整构建流程..." 20 70
    result_dialog
}

# 手动构建步骤
manual_build_steps() {
    while true; do
        step=$(dialog --backtitle "构建步骤" \
                     --title "手动构建" \
                     --menu "选择要执行的步骤：" 17 50 8 \
                     1 "安装依赖" \
                     2 "克隆和打补丁" \
                     3 "构建安装程序" \
                     4 "下载Coreutils" \
                     5 "应用补丁" \
                     6 "配置和编译" \
                     7 "打包输出" \
                     0 "返回主菜单" \
                     3>&1 1>&2 2>&3 3>&-)
        
        case $step in
            1) install_dependencies | dialog --progressbox "安装依赖..." 12 70 ;;
            2) clone_and_patch | dialog --progressbox "克隆和打补丁..." 12 70 ;;
            3) build_installer | dialog --progressbox "构建安装程序..." 12 70 ;;
            4) download_coreutils | dialog --progressbox "下载Coreutils..." 12 70 ;;
            5) apply_patches | dialog --progressbox "应用补丁..." 12 70 ;;
            6) configure_and_build | dialog --progressbox "配置和编译..." 15 70 ;;
            7) package_output | dialog --progressbox "打包输出..." 12 70 ;;
            0) break ;;
            *) ;;
        esac
    done
}

# 配置设置
configure_settings() {
    while true; do
        config_choice=$(dialog --backtitle "配置设置" \
                       --title "配置选项" \
                       --menu "选择要修改的配置：" 15 50 4 \
                       1 "Android NDK路径 [$ANDROID_NDK]" \
                       2 "安装目录 [$APP_INSTALL_DIR]" \
                       3 "目标架构 [$TARGET_ARCH]" \
                       4 "Android API级别 [$ANDROID_API]" \
                       0 "返回" \
                       3>&1 1>&2 2>&3 3>&-)
        
        case $config_choice in
            1) 
                new_ndk=$(dialog --inputbox "输入Android NDK路径:" 8 50 "$ANDROID_NDK" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_ndk" ] && export ANDROID_NDK="$new_ndk"
                ;;
            2)
                new_dir=$(dialog --inputbox "输入安装目录:" 8 50 "$APP_INSTALL_DIR" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_dir" ] && export APP_INSTALL_DIR="$new_dir"
                ;;
            3)
                new_arch=$(dialog --menu "选择目标架构:" 12 30 5 \
                    aarch64 "ARM64 (推荐)" \
                    arm "ARM32" \
                    x86 "x86" \
                    x86_64 "x86_64" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_arch" ] && export TARGET_ARCH="$new_arch"
                ;;
            4)
                new_api=$(dialog --inputbox "输入Android API级别:" 8 50 "$ANDROID_API" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_api" ] && export ANDROID_API="$new_api"
                ;;
            0) break ;;
            *) ;;
        esac
        setup_toolchain
    done
}

# 清理输出
clean_output() {
    if dialog --yesno "确定要清理所有输出文件吗?" 7 50; then
        rm -rf termux-elf-cleaner coreutils-* output
        dialog --msgbox "输出文件已清理！" 6 40
    fi
}

# 结果对话框
result_dialog() {
    if [ -f "output/base.zip" ]; then
        dialog --msgbox "编译完成！\n\n输出文件: output/base.zip\n\n目标架构: $TARGET_ARCH\n安装目录: $APP_INSTALL_DIR" 10 60
    else
        dialog --msgbox "编译未完成或出错！请检查日志。" 7 50
    fi
}

# 函数化封装
install_dependencies() {
    echo "正在更新包索引..."
    pkg update -y
    
    echo "正在安装依赖..."
    pkg install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip dialog
    
    export BUILD_PROG_WORKING_DIR=$PWD
}

clone_and_patch() {
    echo "克隆termux-elf-cleaner..."
    git clone https://github.com/termux/termux-elf-cleaner.git
    cd termux-elf-cleaner
    
    echo "应用补丁..."
    patch -p1 < ../patch/RealignFile/fixcleaner.patch
    bash ../cleaneif.sh
    
    cd $BUILD_PROG_WORKING_DIR
}

build_installer() {
    echo "构建环境安装程序..."
    cd installer/jni
    gcc main.c -o installer
    cp installer $BUILD_PROG_WORKING_DIR/base/home/.term
    cd $BUILD_PROG_WORKING_DIR
}

download_coreutils() {
    echo "下载coreutils源码..."
    COREUTILS_VERSION="9.7"
    COREUTILS_TAR="coreutils-${COREUTILS_VERSION}.tar.xz"
    
    if [ ! -f "${COREUTILS_TAR}" ]; then
        wget -c "https://mirrors.ustc.edu.cn/gnu/coreutils/${COREUTILS_TAR}" || \
        wget -c "https://ftp.gnu.org/gnu/coreutils/${COREUTILS_TAR}"
    fi
}

apply_patches() {
    echo "解压源码..."
    tar xf "coreutils-${COREUTILS_VERSION}.tar.xz"
    cd "coreutils-${COREUTILS_VERSION}"

    echo "应用Android补丁..."
    for i in {1..9}; do
        echo "应用补丁 $i/9"
        patch -p1 < ../patch/coreutils/patch$i.patch
    done
}

configure_and_build() {
    # 环境变量配置
    export ac_cv_func_getpwent=no
    export ac_cv_func_endpwent=no
    export ac_cv_func_getpwnam=no
    export ac_cv_func_getpwuid=no
    export ac_cv_func_sigsetmask=no
    export ac_cv_c_bigendian=no
    
    setup_toolchain
    
    echo "配置coreutils..."
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

    echo "开始编译..."
    make -j$(nproc)
}

package_output() {
    echo "复制已编译文件..."
    cd $BUILD_PROG_WORKING_DIR
    mkdir -p output
    cp coreutils-*/src/coreutils output/
    
    echo "重新对齐ELF..."
    cd termux-elf-cleaner
    ./termux-elf-cleaner ../output/coreutils
    
    echo "打包..."
    cd $BUILD_PROG_WORKING_DIR
    cp ./output/coreutils ./base/bin
    cd base
    zip -r base.zip *
    cd ..
    mv base/base.zip output/
    rm -rf base/bin/coreutils
}

# 设置工具链
setup_toolchain() {
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

    export CC="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang"
    export CXX="${TOOLCHAIN_ROOT}/bin/${TOOL_PREFIX}clang++"
    export AR="${TOOLCHAIN_ROOT}/bin/llvm-ar"
    export RANLIB="${TOOLCHAIN_ROOT}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN_ROOT}/bin/llvm-strip"
    export LD="${TOOLCHAIN_ROOT}/bin/ld.lld"
    
    export CFLAGS="-fPIE -fPIC -Os -static \
    -DNO_MKTIME_Z -D__USE_ANDROID_STDIO -DANDROID_USER_FUNCTIONS \
    -DHAVE_WORKING_GETPWENT=0"
    export LDFLAGS="-static -fPIE -pie"
}

# 默认配置
export ANDROID_NDK="/data/data/com.termux/files/home/android-sdk/ndk/27.2.12479018"
export APP_INSTALL_DIR="/data/data/com.manager.ssb/files/usr"
export TARGET_ARCH="aarch64"
export ANDROID_API=21
export BUILD_PROG_WORKING_DIR=$PWD

# 初始化
install_tui_deps
setup_toolchain

# 启动TUI
main_menu
