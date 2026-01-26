adout_branch() {
    dialog --msgbox "
    self 分支:
        主要发展方向
        
        让我们自举！
    " 70 70
}

declare -A PKG_DEPENDS=(
    [coreutils]=""
    [bash]="coreutils"
    [spm]=""
    [clang]=""
)

# 包定义结构
declare -A PACKAGES=(
    [coreutils]="coreutils"
    [bash]="bash"
    [spm]="spm"
    [clang]="clang"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [coreutils]="true"
    [bash]="true"
    [spm]="true"
    [clang]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [coreutils]="9.7"
    [bash]="5.2.37"
    [spm]="1.0.0"
    [clang]="r28c"
)

# 包构建步骤映射 - 现在使用函数名而不是数字ID
declare -A PKG_STEPS=(
    [coreutils]="download_coreutils setup_coreutils apply_patches configure_coreutils build_coreutils"
    [bash]="configure_bash apply_patches_bash build_bash"
    [clang]="build_clang"
    [spm]="build_spm"
)

# 步骤定义 - 保持顺序不变
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "修补NDK"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "构建spm"
    
    "下载Coreutils源码"
    "解压并配置Coreutils"
    "应用Coreutils补丁"
    "配置Coreutils"
    "编译Coreutils"
    
    "下载和配置 Bash"
    "应用bash补丁"
    "编译 Bash"
    
    "下载和打包 clang"
    
    "复制和重新对齐文件"
    "打包输出"
)

declare -a STEP_FUNCTIONS=(
    "install_dependencies"
    "install_dir"
    "patch_ndk"
    "clone_termux_elf_cleaner"
    "build_installer"
    
    "build_spm"
    
    "download_coreutils"
    "setup_coreutils"
    "apply_patches"
    "configure_coreutils"
    "build_coreutils"
    
    "configure_bash"
    "apply_patches_bash"
    "build_bash"
    
    "build_clang"
    
    "copy_and_realign"
    "package_output"
)