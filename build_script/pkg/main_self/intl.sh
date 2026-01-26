build_intl() {
    cd $BUILD_PROG_WORKING_DIR
    
    git clone https://github.com/j-jorge/libintl-lite.git
    
    cd $BUILD_PROG_WORKING_DIR/libintl-lite
    
    cd internal
    
    setup_toolchain

    echo "libintl.cpp -> libintl.o"
    $CXX -O3 -c libintl.cpp -o libintl.o
    echo "libintl.a"
    $AR rs ../libintl.a libintl.o

    cd ..

    
    INSTALL_PREFIX=$TOOLCHAIN_ROOT/sysroot/usr

    echo "install it to NDK"
    cp libintl.a $INSTALL_PREFIX/lib
    cp libintl.h $INSTALL_PREFIX/include
}

build_locale() {
    cd $BUILD_PROG_WORKING_DIR/locale
    
    setup_toolchain

    make
    general_install
    
    LOCALE_HAS_BUILDED=true
}