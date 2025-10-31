adout_branch() {
    dialog --msgbox "
    musl 分支:
        musl test
    " 70 70
}

declare -A PKG_DEPENDS=(
    [musl]=""
    [hello]="musl"
)

# 包定义结构
declare -A PACKAGES=(
    [musl]="musl"
    [hello]="hello"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [musl]="true"
    [hello]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [musl]="0.0.0"
    [hello]="1.0"
)

# 包构建步骤映射 - 现在使用函数名而不是数字ID
declare -A PKG_STEPS=(
    [musl]="configure_musl build_musl"
    [hello]="build_hello"
)

# 步骤定义 - 保持顺序不变
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "修补NDK"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "配置musl"
    "构建musl"
    
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
    
    "configure_musl" 
    "build_musl"
    
    "build_hello"
    
    "copy_and_realign"
    "package_output"
)