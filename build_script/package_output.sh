package_output() {
    echo "打包..."
    
    cd $BUILD_PROG_WORKING_DIR/output
    zip -r base.zip *
    
    echo "运行事务后清理..."
    cd $BUILD_PROG_WORKING_DIR
    
    rm -rfv coreutils-* bash-* zlib-* openssl-* \
        termux-elf-cleaner
    echo "完成"
}