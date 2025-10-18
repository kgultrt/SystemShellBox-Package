adout_branch() {
    dialog --msgbox "
    empty 分支:
        项目的空分支，不包括任何内容！仅包括一些必须的东西！
        
        你可以把它用作一个新分支的开头！
    " 70 70
}

declare -A PKG_DEPENDS=(
    [empty]=""
)

# 包定义结构
declare -A PACKAGES=(
    [empty]="empty"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [empty]="false"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [empty]="0.0.0"
)

# 包构建步骤映射 - 现在使用函数名而不是数字ID
declare -A PKG_STEPS=(
    [empty]="configure_empty apply_patches_empty build_empty"
)

# 步骤定义 - 保持顺序不变
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "修补NDK"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "patch_ndk"
    "clone_termux_elf_cleaner"
    "build_installer"
    
    "copy_and_realign"
    "package_output"
)