configure_androidsupport() {
    local version_1=29
    local version_2=4
    
    cd $BUILD_PROG_WORKING_DIR
    
    if [ ! -f "v${version_1}.tar.gz" ]; then
        wget https://github.com/termux/libandroid-support/archive/v${version_1}.tar.gz
        tar -zxvf v${version_1}.tar.gz
        rm -rfv "v${version_1}.tar.gz"
    fi
    
    if [ ! -f "v${version_2}.tar.gz" ]; then
        wget https://github.com/termux/wcwidth/archive/v${version_2}.tar.gz
        tar -zxvf v${version_2}.tar.gz
        rm -rfv "v${version_2}.tar.gz"
    fi
    
    cp wcwidth-${version_2}/wcwidth.c libandroid-support-${version_1}/src/
    
    rm -rfv wcwidth-${version_2}
}

compilation_androidsupport() {
    cd $BUILD_PROG_WORKING_DIR
    cd libandroid-support-${PKG_VERSIONS[androidsupport]}
    setup_toolchain
    
    local c_file

    mkdir -p objects
    for c_file in $(find src -type f -iname \*.c); do
        echo "Compilation $c_file"
        $CC $CFLAGS -std=c99 -DNULL=0 -fPIC -Iinclude \
            -c $c_file -o ./objects/$(basename "$c_file").o
    done

    cd objects
    echo "Linking to libandroid-support.so"
    $AR rcu ../libandroid-support.a *.o
    $CC $LDFLAGS -shared -o ../libandroid-support.so *.o
}

install_androidsupport() {
    echo "install..."
    
    cd $BUILD_PROG_WORKING_DIR
    cd libandroid-support-${PKG_VERSIONS[androidsupport]}
    
    install -Dm600 libandroid-support.a $OUTPUT_LIB_DIR/libandroid-support.a
    install -Dm600 libandroid-support.so $OUTPUT_LIB_DIR/libandroid-support.so
    
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rfv libandroid-support-${PKG_VERSIONS[androidsupport]}
}