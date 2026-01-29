configure_libandroid-selinux() {
    cd $BUILD_PROG_WORKING_DIR
    mkdir selinux
    
    local git_branch=android-${PKG_VERSIONS[libandroid-selinux]%.*}_r${PKG_VERSIONS[libandroid-selinux]##*.}
    local url="https://android.googlesource.com/platform/external/selinux"
    
    echo "get src..."
    
    git clone --depth 1 --single-branch --branch $git_branch \
        $url $BUILD_PROG_WORKING_DIR/selinux
        
    local builder_files_path=$(get_build_file_path "libandroid-selinux")
    echo "builder dir: $builder_files_path"
    
    cp -f "$builder_files_path/Makefile-android" "$BUILD_PROG_WORKING_DIR/selinux/libselinux"
    cp -f "$builder_files_path/termux_build.h" "$BUILD_PROG_WORKING_DIR/selinux/libselinux/include"
    
    echo "coped 2 files!"
}

apply_patches_libandroid-selinux() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/selinux
    general_apply_patch "libandroid-selinux"
}

build_libandroid-selinux() {
    echo "编译..."
    setup_toolchain
    
    cd $BUILD_PROG_WORKING_DIR/selinux
    
    # 在编译之前
    local local_saved_arch="$TARGET_ARCH"
    unset TARGET_ARCH
    
    make -C libselinux -f Makefile-android
    
    export TARGET_ARCH="$local_saved_arch"  # 恢复原值    
    # echo "clean up..."
}