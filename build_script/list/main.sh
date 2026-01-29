adout_branch() {
    dialog --msgbox "
    main 分支:
        项目的主干分支。
        
        pacman仍未完成
        spm 完成!
    " 70 70
}

# 包依赖关系定义
declare -A PKG_DEPENDS=(
    [pacman]=""
    [coreutils]=""
    [bash]="coreutils"
    [zlib]=""
    [cacertificates]=""
    [openssl]="zlib"
    [clang]=""
    [androidsupport]=""
    [libbz2]=""
    [zip]=""
    [libnghttp2]=""
    [libnghttp3]=""
    [libssh2]="openssl zlib"
    [curl]="openssl zlib libnghttp2 libnghttp3 libssh2"
    [liblzma]=""
    [zstd]=""
    [spm]=""
    [pcre2]=""
    [libandroid-selinux]="pcre2"
)

# 包定义结构
declare -A PACKAGES=(
    [pacman]="pacman"
    [coreutils]="coreutils"
    [bash]="bash"
    [zlib]="zlib"
    [cacertificates]="cacertificates"
    [openssl]="openssl"
    [clang]="clang"
    [androidsupport]="androidsupport"
    [libbz2]="libbz2"
    [zip]="zip"
    [libnghttp2]="libnghttp2"
    [libnghttp3]="libnghttp3"
    [libssh2]="libssh2"
    [curl]="curl"
    [liblzma]="liblzma"
    [zstd]="zstd"
    [spm]="spm"
    [pcre2]="pcre2"
    [libandroid-selinux]="libandroid-selinux"
)

# 包配置默认值
declare -A PKG_ENABLE=(
    [pacman]="false"
    [coreutils]="true"
    [bash]="true"
    [zlib]="true"
    [cacertificates]="true"
    [openssl]="true"
    [clang]="false"
    [androidsupport]="true"
    [libbz2]="true"
    [zip]="false"
    [libnghttp2]="true"
    [libnghttp3]="true"
    [libssh2]="true"
    [curl]="true"
    [liblzma]="true"
    [zstd]="true"
    [spm]="true"
    [pcre2]="true"
    [libandroid-selinux]="true"
)

# 包版本配置
declare -A PKG_VERSIONS=(
    [pacman]="0.0"
    [coreutils]="9.7"
    [bash]="5.2.37"
    [zlib]="1.3.1"
    [cacertificates]="1:2025.08.12"
    [openssl]="1:3.5.0"
    [clang]="r28c"
    [androidsupport]="29"
    [libbz2]="1.0.8"
    [zip]="3.0"
    [libnghttp2]="1.66.0"
    [libnghttp3]="1.10.1"
    [libssh2]="1.11.1"
    [curl]="8.14.1"
    [liblzma]="5.8.1"
    [zstd]="1.5.7"
    [spm]="1.0.0"
    [pcre2]="10.47"
    [libandroid-selinux]="14.0.0.11"
)

# 包构建步骤映射 - 现在使用函数名而不是数字ID
declare -A PKG_STEPS=(
    [pacman]="configure_pacman apply_patches_pacman build_pacman"
    [coreutils]="download_coreutils setup_coreutils apply_patches configure_coreutils build_coreutils"
    [bash]="configure_bash apply_patches_bash build_bash"
    [zlib]="configure_zlib apply_patches_zlib build_zlib"
    [cacertificates]="build_ca-certificates"
    [openssl]="configure_openssl apply_patches_openssl configure_configure_openssl build_openssl"
    [clang]="build_clang"
    [androidsupport]="configure_androidsupport compilation_androidsupport install_androidsupport"
    [libbz2]="configure_libbz2 apply_patches_libbz2 build_libbz2"
    [zip]="configure_zip apply_patches_zip build_zip"
    [libnghttp2]="configure_libnghttp2 build_libnghttp2"
    [libnghttp3]="configure_libnghttp3 build_libnghttp3"
    [libssh2]="configure_libssh2 build_libssh2"
    [curl]="configure_curl apply_patches_curl build_curl"
    [liblzma]="configure_liblzma apply_patches_liblzma build_liblzma"
    [zstd]="configure_zstd apply_patches_zstd build_zstd"
    [spm]="build_spm"
    [pcre2]="configure_pcre2 apply_patches_pcre2 build_pcre2"
    [libandroid-selinux]="configure_libandroid-selinux apply_patches_libandroid-selinux build_libandroid-selinux"
)

# 步骤定义 - 保持顺序不变
declare -a STEP_NAMES=(
    "安装依赖"
    "准备目录"
    "修补NDK"
    "克隆termux-elf-cleaner"
    "构建环境安装程序"
    
    "构建spm"
    
    "下载pacman源码"
    "应用pacman补丁"
    "编译pacman"
    
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
    
    "下载和打包 clang"
    
    "下载和配置 androidsupport"
    "编译 androidsupport"
    "安装 androidsupport"
    
    "下载和配置 libbz2"
    "应用 libbz2 补丁"
    "编译 libbz2"
    
    "下载和配置 zip"
    "应用 zip 补丁"
    "编译 zip"
    
    "下载和配置 libnghttp2"
    "编译 libnghttp2"
    
    "下载和配置 libnghttp3"
    "编译 libnghttp3"
    
    "下载和配置 libssh2"
    "编译 libssh2"
    
    "下载和配置 curl"
    "应用 curl 补丁"
    "编译 curl"
    
    "下载和配置 liblzma"
    "应用 liblzma 补丁"
    "编译 liblzma"
    
    "下载和配置 zstd"
    "应用 zstd 补丁"
    "编译 zstd"
    
    "下载和配置 pcre2"
    "应用 pcre2 补丁"
    "编译 pcre2"
    
    "下载和配置 libandroid-selinux"
    "应用 libandroid-selinux 补丁"
    "编译 libandroid-selinux"
    
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
    
    "configure_pacman"
    "apply_patches_pacman"
    "build_pacman"
    
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
    
    "build_clang"
    
    "configure_androidsupport"
    "compilation_androidsupport"
    "install_androidsupport"
    
    "configure_libbz2"
    "apply_patches_libbz2"
    "build_libbz2"
    
    "configure_zip"
    "apply_patches_zip"
    "build_zip"
    
    "configure_libnghttp2"
    "build_libnghttp2"
    
    "configure_libnghttp3"
    "build_libnghttp3"
    
    "configure_libssh2"
    "build_libssh2"
    
    "configure_curl"
    "apply_patches_curl"
    "build_curl"
    
    "configure_liblzma"
    "apply_patches_liblzma"
    "build_liblzma"
    
    "configure_zstd"
    "apply_patches_zstd"
    "build_zstd"
    
    "configure_pcre2"
    "apply_patches_pcre2"
    "build_pcre2"
    
    "configure_libandroid-selinux"
    "apply_patches_libandroid-selinux"
    "build_libandroid-selinux"
    
    "copy_and_realign"
    "package_output"
)