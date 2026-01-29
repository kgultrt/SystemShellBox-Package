configure_pcre2() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
    
    if [[ ! -f pcre2-${PKG_VERSIONS[pcre2]}.tar.bz2 ]]; then
        wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PKG_VERSIONS[pcre2]}/pcre2-${PKG_VERSIONS[pcre2]}.tar.bz2
    fi
    
    tar -xjf pcre2-${PKG_VERSIONS[pcre2]}.tar.bz2
    
    cd $BUILD_PROG_WORKING_DIR/pcre2-${PKG_VERSIONS[pcre2]}
    
    local _SOVER_libpcre2_8=0
    local _SOVER_libpcre2_16=0
    local _SOVER_libpcre2_32=0
    local _SOVER_libpcre2_posix=3
    local a
    for a in libpcre2_{8,16,32,posix}; do
        local e=$(sed -En 's/^m4_define\('"${a}"'_version,\s*\[([0-9]+):([0-9]+):([0-9]+)\].*/\1-\3/p' \
                configure.ac)
        if [ ! "${e}" ] || [ "$(eval echo \$_SOVER_${a})" != "$(( "${e}" ))" ]; then
            echo "SOVERSION guard check failed for ${a/_/-}.so."
            prog_exit 1
        fi
    done
}

apply_patches_pcre2() {
    echo "应用Android补丁..."
    cd $BUILD_PROG_WORKING_DIR/pcre2-${PKG_VERSIONS[pcre2]}
    general_apply_patch "pcre2"
}

build_pcre2() {
    echo "编译..."
    setup_toolchain
    
    ./configure \
        --host="${TARGET_HOST}" \
        --prefix="${APP_INSTALL_DIR}" \
        --enable-jit \
        --enable-pcre2-16 \
        --enable-pcre2-32
        
    make -j
    general_install_2
    
    echo "clean up..."
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rfv pcre2*
}