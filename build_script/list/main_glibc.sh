adout_branch() {
    dialog --msgbox "
    main_glibc 分支:
        原 musl test
        现 glibc
    " 70 70
}

declare -A PKG_DEPENDS=(
    [glibc]=""
    [hello]="glibc"
)

# 包定义结构
declare -A PACKAGES=(
    [glibc]="glibc"
    [hello]="hello"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [glibc]="true"
    [hello]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [glibc]="2.41"
    [hello]="1.0"
)

# 包构建步骤映射 - 现在使用函数名而不是数字ID
declare -A PKG_STEPS=(
    [glibc]="configure_glibc build_glibc"
    [hello]="build_hello"
)

# 步骤定义 - 保持顺序不变
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "修补NDK"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "配置glibc"
    "构建glibc"
    
    "构建hello"
    
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "patch_ndk"
    "clone_termux_elf_cleaner"
    "build_installer"
    
    "configure_glibc" 
    "build_glibc"
    
    "build_hello"
    
    "copy_and_realign"
    "package_output"
)