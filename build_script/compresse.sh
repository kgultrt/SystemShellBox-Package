configure_libbz2() {
    cd $BUILD_PROG_WORKING_DIR
    
    if [ ! -f "bzip2-${PKG_VERSIONS[libbz2]}.tar.xz" ]; then
        wget https://fossies.org/linux/misc/bzip2-${PKG_VERSIONS[libbz2]}.tar.xz
        tar -xJvf bzip2-${PKG_VERSIONS[libbz2]}.tar.xz
    fi
    
    cd bzip2-${PKG_VERSIONS[libbz2]}
}

apply_patches_libbz2() {
    cd $BUILD_PROG_WORKING_DIR/bzip2-${PKG_VERSIONS[libbz2]}
    echo "应用Android补丁..."
    general_apply_patch libbz2
}

build_libbz2() {
    cd $BUILD_PROG_WORKING_DIR/bzip2-${PKG_VERSIONS[libbz2]}
    
    make -f Makefile-libbz2_so
    make PREFIX=../output install
    
    rm -rfv ../output/lib/libbz2*
    rm -rfv ../output/bin/{bzcat,bunzip2}
    cp bzip2-shared ../output/bin/bzip2
    cp libbz2.so.${PKG_VERSIONS[libbz2]} ../output/lib
    (cd ../output/lib && ln -s libbz2.so.${PKG_VERSIONS[libbz2]} libbz2.so.1.0)
    (cd ../output/lib && ln -s libbz2.so.${PKG_VERSIONS[libbz2]} libbz2.so)
    (cd ../output/bin && ln -s bzip2 bzcat)
    (cd ../output/bin && ln -s bzip2 bunzip2)
    
    mv ../output/man/man1/* ../output/share/man/man1
    rm -rfv ../output/man
    
    rm ../output/bin/bz{e,f}grep ../output/share/man/man1/bz{e,f}grep.1
    
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rfv $BUILD_PROG_WORKING_DIR/bzip2-${PKG_VERSIONS[libbz2]} "bzip2-${PKG_VERSIONS[libbz2]}.tar.xz"
}



configure_zip() {
    cd $BUILD_PROG_WORKING_DIR
    
    echo "get src..."
    
    if [ ! -f "zip30.tar.gz" ]; then
        wget https://downloads.sourceforge.net/infozip/zip30.tar.gz
    fi
    
    tar -zxvf zip30.tar.gz
}

apply_patches_zip() {
    cd $BUILD_PROG_WORKING_DIR/zip30
    echo "应用Android补丁..."
    general_apply_patch zip
}

build_zip() {
    echo "编译..."
    
    cd $BUILD_PROG_WORKING_DIR/zip30
    cp unix/Makefile Makefile
    
    setup_toolchain
    
    echo "LD=$CC $LDFLAGS CC=$CC $CFLAGS $LDFLAGS make -j generic"
    
    LD="$CC $LDFLAGS" CC="$CC $CFLAGS $LDFLAGS" make -j zip generic
}