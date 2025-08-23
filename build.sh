#!/usr/bin/bash

# set -e

# 带进度条的显示函数（统一实现）
show_progress() {
    local width=50
    local percent=$1
    local completed=$((width * percent / 100))
    local remaining=$((width - completed))
    
    # 创建进度条字符串（统一实现）
    local progress_bar="\e[44m"
    for ((i=0; i<completed; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m\e[47m"
    for ((i=0; i<remaining; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m"
    
    # 显示进度条（统一位置）
    tput sc  # 保存光标位置
    tput cup 0 0  # 移动到屏幕顶部
    echo -ne "\r[${progress_bar}] ${percent}%"
    tput rc  # 恢复光标位置
}

# 更新进度并显示
update_progress() {
    local current_step=$1
    local total_steps=$2
    local percent=$((100 * current_step / total_steps))
    
    show_progress $percent
    
    # 完成后换行
    if [[ $current_step -eq $total_steps ]]; then
        echo
    fi
}

# 执行命令并显示进度
run_step() {
    local step_name="$1"
    local step_func="$2"
    local step_num=$3
    local total_steps=$4
    
    # 记录开始时间
    local start_time=$(date +%s.%N)
    
    # 显示步骤开始
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\n\e[1;34mStep ${step_num}/${total_steps}: ${step_name}...\e[0m"
    else
        # 安静模式下显示步骤名称和spinner
        printf "\e[1;34mStep ${step_num}/${total_steps}: ${step_name}\e[0m "
    fi
    
    # 执行步骤函数
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        # 非安静模式：显示命令输出
        $step_func
    else
        if [ -z "$WRITE_LOG" ] || [ "$WRITE_LOG" -ne 1 ]; then
            # 安静模式：重定向输出到日志文件并显示spinner
            ($step_func >> "$LOG_FILE" 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        else
            ($step_func>/dev/null 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        fi
    fi
    
    # 计算并显示步骤耗时
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc | awk '{printf "%.2f", $0}')
    
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\e[1;32m✓\e[0m \e[2m(${elapsed_time}s)\e[0m"
    else
        printf "\e[1;32m✓\e[0m \e[2m(${elapsed_time}s)\e[0m\n"
    fi
    
    # 更新进度条
    update_progress $step_num $total_steps
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
            0) clear && exit 0 ;;
            *) return ;;
        esac
    done
}

# 完整构建流程
full_build_process() {
    # 显示开始信息
    clear
    echo "======================================"
    echo " Super Development Environment 编译程序"
    echo "======================================"
    echo -e "\n\e[1;33m将在3秒后开始...\e[0m"
    sleep 3
    
    clear
    
    # 准备进度显示
    local total_steps=16
    local current_step=0
    
    # 记录总开始时间（安静模式用）
    export total_start_time=$(date +%s.%N)
    trap 'exit' SIGINT SIGTERM
    
    echo -e "\n\n"  # 为进度条留出空间
    
    # 显示初始进度条
    echo -e "\n\e[1;32m编译进度:\e[0m"
    show_progress 0
    
    # 按顺序执行各步骤
    ((current_step++))
    run_step "安装依赖" install_dependencies $current_step $total_steps
    
    ((current_step++))
    run_step "克隆termux-elf-cleaner" clone_termux_elf_cleaner $current_step $total_steps
    
    ((current_step++))
    run_step "构建环境安装程序" build_installer $current_step $total_steps
    
    ((current_step++))
    run_step "下载Coreutils源码" download_coreutils $current_step $total_steps
    
    ((current_step++))
    run_step "解压并配置Coreutils" setup_coreutils $current_step $total_steps
    
    ((current_step++))
    run_step "应用Coreutils补丁" apply_patches $current_step $total_steps
    
    ((current_step++))
    run_step "配置Coreutils" configure_coreutils $current_step $total_steps
    
    ((current_step++))
    run_step "编译Coreutils" build_coreutils $current_step $total_steps
    
    ((current_step++))
    run_step "下载和配置 Bash" configure_bash $current_step $total_steps
    
    ((current_step++))
    run_step "应用bash补丁" apply_patches_bash $current_step $total_steps
    
    ((current_step++))
    run_step "编译 Bash" build_bash $current_step $total_steps
    
    ((current_step++))
    run_step "下载和配置 zlib" configure_zlib $current_step $total_steps
    
    ((current_step++))
    run_step "应用zlib补丁" apply_patches_zlib $current_step $total_steps
    
    ((current_step++))
    run_step "编译 zlib" build_zlib $current_step $total_steps
    
    ((current_step++))
    run_step "复制和重新对齐文件" copy_and_realign $current_step $total_steps
    
    ((current_step++))
    run_step "打包输出" package_output $current_step $total_steps
    
    # 显示完成信息
    result_display
}

# 手动构建步骤
manual_build_steps() {
    echo "======================================"
    echo " 手动构建步骤"
    echo "======================================"
    
    while true; do
        step=$(dialog --backtitle "构建步骤" \
                     --title "手动构建" \
                     --menu "选择要执行的步骤：" 17 50 8 \
                     1 "安装依赖" \
                     2 "克隆termux-elf-cleaner" \
                     3 "构建环境安装程序" \
                     4 "下载Coreutils源码" \
                     5 "解压Coreutils" \
                     6 "应用Coreutils补丁" \
                     7 "配置Coreutils" \
                     8 "编译Coreutils" \
                     9 "下载和配置 Bash" \
                     10 "应用 Bash 补丁" \
                     11 "编译 Bash" \
                     12 "下载和配置 zlib" \
                     13 "应用 zlib 补丁" \
                     14 "编译 zlib" \
                     15 "复制和重新对齐文件" \
                     16 "打包输出" \
                     0 "返回主菜单" \
                     3>&1 1>&2 2>&3 3>&-)
        
        case $step in
            1) echo -e "\n\e[1;34m步骤: 安装依赖...\e[0m"; install_dependencies ;;
            2) echo -e "\n\e[1;34m步骤: 克隆termux-elf-cleaner...\e[0m"; clone_termux_elf_cleaner ;;
            3) echo -e "\n\e[1;34m步骤: 构建环境安装程序...\e[0m"; build_installer ;;
            4) echo -e "\n\e[1;34m步骤: 下载Coreutils源码...\e[0m"; download_coreutils ;;
            5) echo -e "\n\e[1;34m步骤: 解压Coreutils...\e[0m"; setup_coreutils ;;
            6) echo -e "\n\e[1;34m步骤: 应用Coreutils补丁...\e[0m"; apply_patches ;;
            7) echo -e "\n\e[1;34m步骤: 配置Coreutils...\e[0m"; configure_coreutils ;;
            8) echo -e "\n\e[1;34m步骤: 编译Coreutils...\e[0m"; build_coreutils ;;
            9) echo -e "\n\e[1;34m步骤: 下载和配置 Bash...\e[0m"; configure_bash ;;
            10) echo -e "\n\e[1;34m步骤: 应用 Bash 补丁...\e[0m"; apply_patches_bash ;;
            11) echo -e "\n\e[1;34m步骤: 编译 Bash...\e[0m"; build_bash ;;
            12) echo -e "\n\e[1;34m步骤: 下载和配置 zlib...\e[0m"; configure_zlib ;;
            13) echo -e "\n\e[1;34m步骤: 应用 zlib 补丁...\e[0m"; apply_patches_zlib ;;
            14) echo -e "\n\e[1;34m步骤: 编译 zlib...\e[0m"; build_zlib ;;
            15) echo -e "\n\e[1;34m步骤: 复制和重新对齐文件...\e[0m"; copy_and_realign ;;
            16) echo -e "\n\e[1;34m步骤: 打包输出...\e[0m"; package_output ;;
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
                       --menu "选择要修改的配置：" 15 50 6 \
                       1 "Android NDK路径 [$ANDROID_NDK]" \
                       2 "安装目录 [$APP_INSTALL_DIR]" \
                       3 "目标架构 [$TARGET_ARCH]" \
                       4 "Android API级别 [$ANDROID_API]" \
                       5 "CoreUtils 版本 [$COREUTILS_VERSION]" \
                       6 "Bash 版本 [$BASH_VERSION]" \
                       7 "是否编译 Python [$COMP_PYTHON]" \
                       8 "需要对齐 ELF 头 [$NEED_CLEAN_ELF]" \
                       9 "zlib 版本 [$ZLIB_VERSION]" \
                       10 "安静输出 [$IS_QUIET]" \
                       11 "在安静输出里保存日志 [$WRITE_LOG]" \
                       0 "返回" \
                       3>&1 1>&2 2>&3 3>&-)
        
        case $config_choice in
            1) 
                new_ndk=$(dialog --inputbox "输入Android NDK路径:" 8 50 "$ANDROID_NDK" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_ndk" ] && export ANDROID_NDK="$new_ndk" && export NDK_BUILD="${ANDROID_NDK}/ndk-build"
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
            5)
                new_api2=$(dialog --inputbox "输入新的版本号 (不建议更改):" 8 50 "$COREUTILS_VERSION" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_api2" ] && export COREUTILS_VERSION="$new_api2"
                ;;
            6)
                new_api3=$(dialog --inputbox "输入新的版本号 (不建议更改):" 8 50 "$BASH_VERSION" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_api3" ] && export BASH_VERSION="$new_api3"
                ;;
            7)
                new_choose=$(dialog --menu "选择:" 12 30 5 \
                    true "启用" \
                    false "禁用 (推荐)" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_choose" ] && export COMP_PYTHON="$new_choose"
                ;;
            8)
                new_choose=$(dialog --menu "选择:" 12 30 5 \
                    true "启用" \
                    false "禁用" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_choose" ] && export NEED_CLEAN_ELF="$new_choose"
                ;;
            9)
                new_api3=$(dialog --inputbox "输入新的版本号 (不建议更改):" 8 50 "$ZLIB_VERSION" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_api3" ] && export ZLIB_VERSION="$new_api3"
                ;;
            10)
                new_choose=$(dialog --menu "选择:" 12 85 5 \
                    1 "启用 (不推荐，容易出一些匪夷所思的Bug)" \
                    0 "禁用" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_choose" ] && export IS_QUIET="$new_choose"
                ;;
            11)
                new_choose=$(dialog --menu "选择:" 12 30 5 \
                    1 "启用" \
                    0 "禁用" 3>&1 1>&2 2>&3 3>&-)
                [ -n "$new_choose" ] && export WRITE_LOG="$new_choose"
                ;;
            0) break ;;
            *) ;;
        esac
    done
}

# 清理输出
clean_output() {
    if dialog --yesno "确定要清理所有输出文件吗?" 7 50; then
        echo "清理输出文件..."
        
        rm -rf termux-elf-cleaner coreutils-* output bash-*
        cd installer
        rm -rf libs obj
        cd $BUILD_PROG_WORKING_DIR
        rm -rf base
        
        unzip base.zip
        
        dialog --msgbox "输出文件已清理！" 6 40
    fi
}

clean_output_without_yes() {
    echo "清理输出文件..."
    rm -rf termux-elf-cleaner coreutils-* output bash-*
    dialog --msgbox "输出文件已清理！" 6 40
    clear
}

# 结果显示
result_display() {
    echo "========================================================"
    if [ -f "output/base.zip" ]; then
        echo -e "\e[1;32m编译完成！\e[0m"
        echo "输出文件: output/base.zip"
        echo "目标架构: $TARGET_ARCH"
        echo "安装目录: $APP_INSTALL_DIR"
    else
        echo -e "\e[1;31m编译未完成或出错！请检查日志。\e[0m"
    fi
    echo "========================================================"
    
    # 安静模式：显示总耗时
    if [ -n "$IS_QUIET" ] && [ "$IS_QUIET" -eq 1 ]; then
        local total_end_time=$(date +%s.%N)
        local total_elapsed_time=$(echo "$total_end_time - $total_start_time" | bc | awk '{printf "%.2f", $0}')
        echo -e "\n\e[1;32m✓ 所有步骤完成! 总耗时: ${total_elapsed_time}秒\e[0m"
    fi
    
    sleep 5 #给用户留时间查看
}

# ===================== 构建步骤函数 =====================

install_dependencies() {
    echo "更新包索引..."
    apt update -y
    
    echo "安装依赖包..."
    apt install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip dialog
    
    export BUILD_PROG_WORKING_DIR=$PWD
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
    
    cp $INSTALLER_PATH $BUILD_PROG_WORKING_DIR/base/home/.term
    unset INSTALLER_PATH
    cd $BUILD_PROG_WORKING_DIR
}

download_coreutils() {
    echo "下载coreutils源码..."
    COREUTILS_TAR="coreutils-${COREUTILS_VERSION}.tar.xz"
    
    if [ ! -f "${COREUTILS_TAR}" ]; then
        wget -c "https://mirrors.ustc.edu.cn/gnu/coreutils/${COREUTILS_TAR}" || \
        wget -c "https://ftp.gnu.org/gnu/coreutils/${COREUTILS_TAR}"
    fi
}

configure_bash() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "下载bash源码..."
    BASH_TAR="bash-${BASH_VERSION}.tar.gz"
    
    if [ ! -f "${BASH_TAR}" ]; then
        wget -c "https://mirrors.ustc.edu.cn/gnu/bash/${BASH_TAR}" || \
        wget -c "https://ftp.gnu.org/gnu/bash/${BASH_TAR}"
    fi
    
    tar -zxvf ${BASH_TAR}
    cd $BUILD_PROG_WORKING_DIR/bash-${BASH_VERSION}
    
    setup_toolchain
    
    echo "配置bash..."
    
    ./configure --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --disable-nls \
        --enable-multibyte \
        --enable-static-link \
        --without-bash-malloc \
        bash_cv_dev_fd=whacky \
        bash_cv_job_control_missing=present \
        bash_cv_sys_siglist=yes \
        bash_cv_unusable_rtsigs=no \
        ac_cv_func_mbsnrtowcs=no \
        ac_cv_func_getpwent=no \
        ac_cv_func_getgrent=no \
        ac_cv_func_setgrent=no \
        ac_cv_func_endpwent=no \
        ac_cv_func_mblen=no \
        ac_cv_func_mbrlen=no \
        ac_cv_func_endgrent=no \
        ac_cv_func_getpwnam=no \
        ac_cv_func_getgrnam=no \
        ac_cv_func_getpwuid=no \
        ac_cv_func_mempcpy=no \
        ac_cv_func___fpurge=no \
        ac_cv_func_strchrnul=no \
        ac_cv_func_sigsetmask=no \
        ac_cv_c_bigendian=no \
        bash_cv_getcwd_malloc=yes \
        bash_cv_func_sigsetjmp=present
}

setup_coreutils() {
    echo "解压源码..."
    tar xf "coreutils-${COREUTILS_VERSION}.tar.xz"
    cd "coreutils-${COREUTILS_VERSION}"
    
    setup_toolchain
}

apply_patches() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/coreutils-${COREUTILS_VERSION}
    patch -p1 < ../patch/coreutils/1.patch
    patch -p1 < ../patch/coreutils/2.patch
    patch -p1 < ../patch/coreutils/3.patch
    #patch -p1 < ../patch/coreutils/4.patch
    patch -p1 < ../patch/coreutils/5.patch
    patch -p1 < ../patch/coreutils/6.patch
    patch -p1 < ../patch/coreutils/7.patch
    patch -p1 < ../patch/coreutils/8.patch
    patch -p1 < ../patch/coreutils/9.patch
}

apply_patches_bash() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/bash-${BASH_VERSION}
    patch -p1 < ../patch/bash/1.patch
    patch -p1 < ../patch/bash/2.patch
    patch -p1 < ../patch/bash/3.patch
    patch -p1 < ../patch/bash/4.patch
    patch -p1 < ../patch/bash/5.patch
    patch -p1 < ../patch/bash/6.patch
    patch -p1 < ../patch/bash/7.patch
    patch -p1 < ../patch/bash/8.patch
    patch -p1 < ../patch/bash/9.patch
    patch -p1 < ../patch/bash/10.patch
    patch -p1 < ../patch/bash/11.patch
    patch -p1 < ../patch/bash/12.patch
    patch -p1 < ../patch/bash/13.patch
    patch -p1 < ../patch/bash/15.patch
}

configure_coreutils() {
    echo "配置coreutils..."
    
    cd $BUILD_PROG_WORKING_DIR/coreutils-${COREUTILS_VERSION}
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-single-binary=symlinks \
        --disable-xattr \
        --with-gnu-ld \
        --disable-year2038 \
        --enable-no-install-program=pinky,df,users,who,uptime,stdbuf \
        --with-packager=SuperDevelopmentEnvironment \
        --enable-shared \
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
        ac_cv_func_mbrlen=no \
        ac_cv_c_bigendian=no \
        ac_cv_func_getnameinfo=no \
        ac_cv_func_tzfree=yes \
        ac_cv_func_tzalloc=yes
}

build_coreutils() {
    echo "开始编译..."
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR/coreutils-${COREUTILS_VERSION}
    make -j$(nproc)
}

build_bash() {
    echo "开始编译..."
    cd $BUILD_PROG_WORKING_DIR/bash-${BASH_VERSION}
    setup_toolchain
    
    # export CFLAGS="${CFLAGS} -DHANDLE_MULTIBYTE"
    # echo ${CFLAGS}
    
    make -j$(nproc)
    
    unsetup_toolchain
    setup_toolchain
}

copy_and_realign() {
    echo "复制已编译文件..."
    cd $BUILD_PROG_WORKING_DIR
    mkdir -p output
    cp coreutils-${COREUTILS_VERSION}/src/coreutils output/
    cp bash-${BASH_VERSION}/bash output/
    
    case ${NEED_CLEAN_ELF} in
        "true")
            echo "重新对齐ELF..."
            cd termux-elf-cleaner
            ./termux-elf-cleaner ../output/coreutils
            ./termux-elf-cleaner ../output/bash
            ;;
        "false")
            echo "Skip!"
            ;;
    esac
}

package_output() {
    echo "打包..."
    cd $BUILD_PROG_WORKING_DIR
    cp ./output/* ./base/bin
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
    export OBJCOPY="${TOOLCHAIN_ROOT}/bin/llvm-objcopy"
    export OBJDUMP="${TOOLCHAIN_ROOT}/bin/llvm-objdump"
    export RANLIB="${TOOLCHAIN_ROOT}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN_ROOT}/bin/llvm-strip"
    export LD="${TOOLCHAIN_ROOT}/bin/ld.lld"
    
    export CFLAGS="-fPIE -fPIC -Os \
    -DNO_MKTIME_Z -D__USE_ANDROID_STDIO -DANDROID_USER_FUNCTIONS \
    -DHAVE___FPURGE=0 -DHANDLE_MULTIBYTE -Wno-everything"
    export LDFLAGS="-fPIE -pie"
    
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
    
}

unsetup_toolchain() {
    unset CC
    unset CXX
    unset AR
    unset RANLIB
    unset STRIP
    unset LD
    unset CFLAGS
    unset LDFLAGS
}

# 旋转动画函数（安静模式使用）
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='/-\|'
    local i=0
    
    echo
    
    while ps -p $pid > /dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        printf "\r$temp"
        sleep $delay
    done
    printf "\r \r"
}

# ===================== 初始化和主程序 =====================

# 默认配置
export ANDROID_NDK="/data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358"
export NDK_BUILD="${ANDROID_NDK}/ndk-build"
export APP_INSTALL_DIR="/data/data/com.manager.ssb/files/usr"
export TARGET_ARCH="aarch64"
export ANDROID_API=21
export BUILD_PROG_WORKING_DIR=$PWD
export CLEAN_TOOLS=$PWD/termux-elf-cleaner/termux-elf-cleaner
export COREUTILS_VERSION="9.7"
export BASH_VERSION="5.2.37"
export ZLIB_VERSION="1.3.1"
export PYTHON_VERSION="3.12.11"
export COMP_PYTHON="false"
export ICONV_VERSION="1.18"
export NEED_CLEAN_ELF="false"
export PKG_MGR="spm"
export IS_QUIET=0
export LOG_FILE="progress_$(date +%Y%m%d_%H%M%S).log"
export WRITE_LOG=1

# 检查并安装dialog
if ! command -v dialog &>/dev/null; then
    echo "安装dialog..."
    apt install -y dialog
fi

if ! command -v bc &>/dev/null; then
    echo "bc..."
    apt install -y bc
fi

# 启动主菜单
main_menu