# ===================== 包管理系统 =====================

# 包定义结构
declare -A PACKAGES=(
    [xdps]="xdps"
    [coreutils]="coreutils"
    [bash]="bash"
    [zlib]="zlib"
    [cacertificates]="cacertificates"
    [openssl]="openssl"
    [androidndk]="androidndk"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [xdps]="false"
    [coreutils]="true"
    [bash]="true"
    [zlib]="true"
    [cacertificates]="true"
    [openssl]="true"
    [androidndk]="false"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [xdps]="0.0"
    [coreutils]="9.7"
    [bash]="5.2.37"
    [zlib]="1.3.1"
    [cacertificates]="1:2025.08.12"
    [openssl]="1:3.5.0"
    [androidndk]="r28c"
)

# 包构建步骤映射
declare -A PKG_STEPS=(
    [xdps]="5 6 7"
    [coreutils]="8 9 10 11 12"
    [bash]="13 14 15"
    [zlib]="16 17 18"
    [cacertificates]="19"
    [openssl]="20 21 22 23"
    [androidndk]="24"
)

# 步骤定义
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "下载xpds源码"
    "应用xpds补丁"
    "编译xdps"
    
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
    
    "打包 ca-certificates"
    
    "下载 openssl"
    "应用 openssl 补丁"
    "配置 openssl"
    "编译 openssl"
    
    "下载和打包 androidndk"
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "clone_termux_elf_cleaner"
    "build_installer"
    
    "configure_xdps"
    "apply_patches_xdps"
    "build_xdps"
    
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
    
    "build_ca-certificates"
    
    "configure_openssl"
    "apply_patches_openssl"
    "configure_configure_openssl"
    "build_openssl"
    
    "build_androidndk"
    
    "copy_and_realign"
    "package_output"
)