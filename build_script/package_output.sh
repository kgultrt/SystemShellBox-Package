package_output() {
    echo "打包..."
    
    cd $BUILD_PROG_WORKING_DIR
    cp -r ./output/* ./base
    cd base
    zip -r base.zip *
    cd ..
    mv base/base.zip output/
    
    echo "运行事务后清理..."
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rfv coreutils-* bash-* zlib-* openssl-* \
        termux-elf-cleaner
    echo "完成"
}