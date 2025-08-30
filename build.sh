#!/usr/bin/bash

export BUILD_PROG_VERSION="v1.0.2"

# ===================== 配置部分 =====================
export ANDROID_NDK="/data/data/com.termux/files/home/android-sdk/ndk/28.2.13676358"
export NDK_BUILD="${ANDROID_NDK}/ndk-build"
export APP_INSTALL_DIR="/data/data/com.manager.ssb/files/usr"
export TARGET_ARCH="aarch64"
export ANDROID_API=21
export BUILD_PROG_WORKING_DIR=$PWD
export OUTPUT_LIB_DIR=$BUILD_PROG_WORKING_DIR/output/lib
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
export WRITE_LOG=1
export LOG_FILE="progress_$(date +%Y%m%d_%H%M%S).log"
export CONFIG_FILE="config.conf"
export CONFIG_PKG_FILE="config_pkg.conf"

# 步骤定义
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    "下载Coreutils源码"
    "解压并配置Coreutils"
    "应用Coreutils补丁"
    "配置Coreutils"
    "编译Coreutils"
    "下载和配置 Bash"
    "应用bash补丁"
    "编译 Bash"
    "下载和配置 zlib"
    "应用 zlib 补丁"
    "编译 zlib"
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "clone_termux_elf_cleaner"
    "build_installer"
    "download_coreutils"
    "setup_coreutils"
    "apply_patches"
    "configure_coreutils"
    "build_coreutils"
    "configure_bash"
    "apply_patches_bash"
    "build_bash"
    "configure_zlib"
    "apply_patches_zlib"
    "build_zlib"
    "copy_and_realign"
    "package_output"
)

# 配置项定义：变量=描述
declare -A CONFIG_ITEMS=(
    [ANDROID_NDK]="Android NDK路径"
    [APP_INSTALL_DIR]="安装目录"
    [TARGET_ARCH]="目标架构"
    [ANDROID_API]="Android API级别"
    [COREUTILS_VERSION]="CoreUtils 版本"
    [BASH_VERSION]="Bash 版本"
    [NEED_CLEAN_ELF]="是否对齐 ELF 头"
    [ZLIB_VERSION]="zlib 版本"
    [IS_QUIET]="安静输出"
    [WRITE_LOG]="安静模式下保存日志"
)

# 类型定义：变量=输入方式
declare -A CONFIG_TYPES=(
    [ANDROID_NDK]="path"
    [APP_INSTALL_DIR]="path"
    [TARGET_ARCH]="arch"
    [ANDROID_API]="number"
    [COREUTILS_VERSION]="version"
    [BASH_VERSION]="version"
    [NEED_CLEAN_ELF]="bool"
    [ZLIB_VERSION]="version"
    [IS_QUIET]="boolnum"
    [WRITE_LOG]="boolnum"
)

declare -A CONFIG_PKG_ITEMS=(
    [COREUTILS_ENABLE]="coreutils"
    [BASH_ENABLE]="bash"
    [ZLIB_ENABLE]="zlib"
)



TOTAL_STEPS=${#STEP_NAMES[@]}
TOTAL_PKG=${#CONFIG_PKG_ITEMS[@]}
echo "TOTAL_STEPS: ${TOTAL_STEPS}"
echo "TOTAL_PKG: ${TOTAL_PKG}"

default_pkg_list() {
    #export _ENABLE="true"
    
    export BASH_ENABLE="true"
    export COREUTILS_ENABLE="true"
    export ZLIB_ENABLE="true"
}

# ===================== 通用功能函数 =====================

# 带进度条的显示函数
show_progress() {
    local width=50
    local percent=$1
    local completed=$((width * percent / 100))
    local remaining=$((width - completed))
    
    # 创建进度条字符串
    local progress_bar="\e[44m"
    for ((i=0; i<completed; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m\e[47m"
    for ((i=0; i<remaining; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m"
    
    # 显示进度条
    tput sc  # 保存光标位置
    tput cup 0 0  # 移动到屏幕顶部
    echo -ne "\r[${progress_bar}] ${percent}%"
    tput rc  # 恢复光标位置
}

# 更新进度并显示
update_progress() {
    local current_step=$1
    local percent=$((100 * current_step / TOTAL_STEPS))
    
    show_progress $percent
    
    # 完成后换行
    if [[ $current_step -eq $TOTAL_STEPS ]]; then
        echo
    fi
}

# 旋转动画函数（安静模式使用）
spinner() {
    local pid=$1
    local delay=0.05
    local spinstr='/-\|'
    local i=0
    
    echo
    
    while ps -p $pid > /dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        printf "\rPlease wait... $temp ($i)"
        sleep $delay
    done
    
    printf "\rPlease wait... "
}

# 执行命令并显示进度
run_step() {
    local step_name="$1"
    local step_func="$2"
    local step_num=$3
    pkg_check ${step_num}
    local check_result=$?
    
    # 记录开始时间
    local start_time=$(date +%s.%N)
    
    # 显示步骤开始
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\n\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}...\e[0m"
    else
        # 安静模式下显示步骤名称和spinner
        printf "\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}\e[0m "
    fi
    
    if [ $check_result -eq 1 ]; then
        echo "Should Skip!"
    fi
    
    # 执行步骤函数
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        if [ $check_result -eq 0 ]; then
            # 非安静模式：显示命令输出
            $step_func
        fi
    else
        if [ -z "$WRITE_LOG" ] || [ "$WRITE_LOG" -ne 1 ]; then
            if [ $check_result -eq 0 ]; then
                # 安静模式：重定向输出到日志文件并显示spinner
                ($step_func >> "$LOG_FILE" 2>&1) &
                local pid=$!
                spinner $pid
                wait $pid
            fi
        else
            if [ $check_result -eq 0 ]; then
                ($step_func>/dev/null 2>&1) &
                local pid=$!
                spinner $pid
                wait $pid
            fi
        fi
    fi
    
    # 计算并显示步骤耗时
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc | awk '{printf "%.2f", $0}')
    
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m"
        echo
    else
        printf "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m\n"
        echo
    fi
    
    # 更新进度条
    update_progress $step_num
}

pkg_check() {
    local step_num=$1
    local return_num=0
    
    if [ "${COREUTILS_ENABLE}" = "false" ]; then
        if [[ $step_num -eq 5 || $step_num -eq 6 || $step_num -eq 7 || $step_num -eq 8 || $step_num -eq 9 ]]; then
            return_num=1
        fi
    fi
    
    if [ "${BASH_ENABLE}" = "false" ]; then
        if [[ $step_num -eq 10 || $step_num -eq 11 || $step_num -eq 12 ]]; then
            return_num=1
        fi
    fi
    
    if [ "${ZLIB_ENABLE}" = "false" ]; then
        if [[ $step_num -eq 13 || $step_num -eq 14 || $step_num -eq 15 ]]; then
            return_num=1
        fi
    fi
    
    return ${return_num}
}

# ===================== 工具链函数 =====================

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
    
    export LDSHARED="${CC} -fPIE -pie -shared"
    
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
}

# ===================== 构建步骤函数 =====================

install_dependencies() {
    echo "更新包索引..."
    apt update -y
    
    echo "安装依赖包..."
    apt install -y git automake autoconf clang binutils make gettext bison gperf texinfo wget cmake zip dialog
    
    export BUILD_PROG_WORKING_DIR=$PWD
}

install_dir() {
    mkdir -p $BUILD_PROG_WORKING_DIR/output
    mkdir -p $BUILD_PROG_WORKING_DIR/output/lib
    mkdir -p $BUILD_PROG_WORKING_DIR/output/bin
    
    echo "准备完成"
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

setup_coreutils() {
    echo "解压源码..."
    tar xf "coreutils-${COREUTILS_VERSION}.tar.xz"
    cd "coreutils-${COREUTILS_VERSION}"
    
    setup_toolchain
}

apply_patches() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/coreutils-${COREUTILS_VERSION}
    for patch_file in ../patch/coreutils/*.patch; do
        patch -p1 < $patch_file
    done
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

apply_patches_bash() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/bash-${BASH_VERSION}
    for patch_file in ../patch/bash/*.patch; do
        patch -p1 < $patch_file
    done
}

build_bash() {
    echo "开始编译..."
    cd $BUILD_PROG_WORKING_DIR/bash-${BASH_VERSION}
    setup_toolchain
    
    make -j$(nproc)
    
    unsetup_toolchain
    setup_toolchain
}

configure_zlib() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
    ZLIB_FILE="zlib-${ZLIB_VERSION}.tar.gz"
    
    if [ ! -f "${ZLIB_FILE}" ]; then
        wget "https://zlib.net/${ZLIB_FILE}" || \
        wget "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/${ZLIB_FILE}"
    fi
    
    tar -zxvf ${ZLIB_FILE}
    
    cd $BUILD_PROG_WORKING_DIR/zlib-${ZLIB_VERSION}
    
    echo "配置zlib..."
    
    unsetup_toolchain
    setup_toolchain
    
    LDFLAGS+=" -Wl,--undefined-version"
    echo ${LDFLAGS}
    
    ./configure --prefix="${APP_INSTALL_DIR}" --shared
}

apply_patches_zlib() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/zlib-${ZLIB_VERSION}
    
    patch -p1 < ../patch/zlib/1.patch
}

build_zlib() {
    echo "编译..."
    cd $BUILD_PROG_WORKING_DIR/zlib-${ZLIB_VERSION}
    
    unsetup_toolchain
    setup_toolchain
    
    LDFLAGS+=" -Wl,--undefined-version"
    
    make -j$(nproc)
    
    unsetup_toolchain
    
    mkdir -p $BUILD_PROG_WORKING_DIR/output
    cp $BUILD_PROG_WORKING_DIR/zlib-${ZLIB_VERSION}/libz.so* $OUTPUT_LIB_DIR
}

copy_and_realign() {
    echo "复制已编译文件..."
    cd $BUILD_PROG_WORKING_DIR
    mkdir -p output
    cp coreutils-${COREUTILS_VERSION}/src/coreutils output/bin
    cp bash-${BASH_VERSION}/bash output/bin
    
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
    cp -r ./output/* ./base
    cd base
    zip -r base.zip *
    cd ..
    mv base/base.zip output/
    
    echo "运行事务后清理..."
    cd $BUILD_PROG_WORKING_DIR
    rm -rf termux-elf-cleaner coreutils-* bash-* zlib-*
    echo "完成"
}

# ===================== UI 函数 =====================

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
        echo -e "\n\e[1;32m[OK] 所有步骤完成! 总耗时: ${total_elapsed_time}秒\e[0m"
    fi
    
    sleep 5 #给用户留时间查看
}

# 完整构建流程
full_build_process() {
    # 显示开始信息
    clear
    echo "======================================"
    echo " Super Development Environment 编译程序"
    echo "======================================"
    echo "总包: ${TOTAL_PKG} 个包"
    echo "将要构建: ${PKG_TO_BUILD} 个包"
    echo -e "\n\e[1;33m将在3秒后开始...\e[0m"
    sleep 3
    
    clear
    
    # 准备进度显示
    local current_step=0
    
    # 记录总开始时间（安静模式用）
    export total_start_time=$(date +%s.%N)
    trap 'echo -e "\rPlease wait... \e[1;31m[FAILED]\e[0m 用户取消操作!" && echo && exit' SIGINT SIGTERM
    
    echo -e "\n"  # 为进度条留出空间
    
    # 显示初始进度条
    echo -e "\n\e[1;32m编译进度:\e[0m"
    show_progress 0
    
    # 按顺序执行各步骤
    for ((cstep=0; cstep<TOTAL_STEPS; cstep++)); do
        ((current_step++))
        run_step "${STEP_NAMES[cstep]}" "${STEP_FUNCTIONS[cstep]}" $current_step
    done
    
    # 显示完成信息
    result_display
}

# 手动构建步骤
manual_build_steps() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        for ((i=0; i<TOTAL_STEPS; i++)); do
            options+=("$((i+1))" "${STEP_NAMES[i]}")
        done
        
        choice=$(dialog --backtitle "构建步骤" \
                     --title "手动构建" \
                     --menu "选择要执行的步骤：" 17 50 8 \
                     "${options[@]}" \
                     3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -ge 1 && $choice -le $TOTAL_STEPS ]]; then
            local step_index=$((choice-1))
            echo -e "\n\e[1;34m步骤: ${STEP_NAMES[step_index]}...\e[0m"
            run_step "手动" ${STEP_FUNCTIONS[step_index]} 99999
        fi
    done
}

# 配置设置
# ==================== 保存/加载配置 ====================

# 保存配置到文件
save_config() {
    > "$CONFIG_FILE"
    for key in "${!CONFIG_ITEMS[@]}"; do
        echo "$key=\"${!key}\"" >> "$CONFIG_FILE"
    done
    dialog --msgbox "配置已保存到 $CONFIG_FILE" 7 50
}

# 从文件加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "NO CONFIG!"
    fi
}

# ==================== 编辑配置 ====================

edit_config() {
    local var="$1"
    local type="${CONFIG_TYPES[$var]}"
    local current="${!var}"
    local new_value

    case "$type" in
        path|version|number)
            new_value=$(dialog --inputbox "输入 ${CONFIG_ITEMS[$var]}:" 8 50 "$current" 3>&1 1>&2 2>&3 3>&-)
            ;;
        bool)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 30 5 \
                true "启用" \
                false "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        boolnum)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 50 5 \
                1 "启用" \
                0 "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        arch)
            new_value=$(dialog --menu "选择目标架构:" 12 30 5 \
                aarch64 "ARM64 (推荐)" \
                arm "ARM32" \
                x86 "x86" \
                x86_64 "x86_64" 3>&1 1>&2 2>&3 3>&-)
            ;;
    esac

    [ -n "$new_value" ] && export "$var=$new_value"
}

configure_settings() {
    while true; do
        menu_items=()
        menu_items+=("0" "返回")
        menu_items+=("S" "保存配置")
        i=1
        for key in "${!CONFIG_ITEMS[@]}"; do
            value="${!key}"
            menu_items+=("$i" "${CONFIG_ITEMS[$key]} [$value]")
            keys[$i]="$key"
            ((i++))
        done
        
        choice=$(dialog --menu "选择要修改的配置：" 20 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3 3>&-)

        case "$choice" in
            0|"") break ;;
            S) save_config ;;
            *) edit_config "${keys[$choice]}" ;;
        esac
    done
}




# 配置软件包设置
configure_package_list() {
    while true; do
        menu_items=()
        
        menu_items+=("0" "返回")
        menu_items+=("S" "保存配置")
        
        i=1
        for key in "${!CONFIG_PKG_ITEMS[@]}"; do
            value="${!key}"
            menu_items+=("$i" "${CONFIG_PKG_ITEMS[$key]} [$value]")
            keys[$i]="$key"
            ((i++))
        done

        choice=$(dialog --menu "选择要修改的配置：" 20 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3 3>&-)

        case "$choice" in
            0|"") break ;;
            S) save_pkg_config ;;
            *) edit_pkg_config "${keys[$choice]}" ;;
        esac
    done
}

edit_pkg_config() {
    local var="$1"
    local current="${!var}"
    local new_value
    local no_change=0

    new_value=$(dialog --menu "选择 ${CONFIG_PKG_ITEMS[$var]}:" 12 30 5 \
        true "启用" \
        false "禁用" 3>&1 1>&2 2>&3 3>&-)
        
    if [ "$new_value" = "$current" ]; then
        no_change=1
    fi

    [ -n "$new_value" ] && export "$var=$new_value"
    
    case ${new_value} in
        "true")
            if [ $no_change -eq 0 ]; then
                ((PKG_TO_BUILD++))
            fi
            ;;
        "false")
            if [ $no_change -eq 0 ]; then
                ((PKG_TO_BUILD--))
            fi
            ;;
    esac
    
    echo "${PKG_TO_BUILD}"
}

# 保存/加载配置
# 保存配置到文件
save_pkg_config() {
    > "$CONFIG_PKG_FILE"
    for key in "${!CONFIG_PKG_ITEMS[@]}"; do
        echo "$key=\"${!key}\"" >> "$CONFIG_PKG_FILE"
    done
    
    echo "PKG_TO_BUILD=${PKG_TO_BUILD}" >> "$CONFIG_PKG_FILE"
    
    dialog --msgbox "配置已保存到 $CONFIG_PKG_FILE" 7 50
}

# 从文件加载配置
load_pkg_config() {
    if [[ -f "$CONFIG_PKG_FILE" ]]; then
        source "$CONFIG_PKG_FILE"
    else
        echo "NO PKG CONFIG!"
        export PKG_TO_BUILD=$TOTAL_PKG
        
        default_pkg_list
    fi
}

# 清理输出
clean_output() {
    if dialog --yesno "确定要清理所有输出文件吗?" 7 50; then
        echo "清理输出文件..."
        
        rm -rf termux-elf-cleaner coreutils-* output bash-* zlib-*
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

# 主菜单
main_menu() {
    while true; do
        choice=$(dialog --backtitle "Super Development Environment 编译程序 (${BUILD_PROG_VERSION}, ${TOTAL_PKG}个包可用, 构建${PKG_TO_BUILD}个包)" \
                        --title "主菜单" \
                        --menu "请选择操作：" 15 50 5 \
                        1 "完整构建流程" \
                        2 "手动构建步骤" \
                        3 "配置设置" \
                        4 "清理输出" \
                        5 "要构建哪些包" \
                        0 "退出" \
                        3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1) full_build_process ;;
            2) manual_build_steps ;;
            3) configure_settings ;;
            4) clean_output ;;
            5) configure_package_list ;;
            0) clear && exit 0 ;;
            *) return ;;
        esac
    done
}

# ===================== 初始化和主程序 =====================

# 检查并安装dialog
if ! command -v dialog &>/dev/null; then
    echo "安装dialog..."
    apt install -y dialog
fi

if ! command -v bc &>/dev/null; then
    echo "bc..."
    apt install -y bc
fi

# 加载配置
load_config
load_pkg_config
# 启动主菜单
main_menu