patch_ndk() {
    setup_toolchain
    
    if [[ $NDK_HAS_PATCHED -eq 0 ]]; then
        echo "WARNING!"
        echo "This program is about to make some changes to your ndk ($TOOLCHAIN_ROOT)"
        echo "If you are developing an android app using ndk"
        echo "You may need to reinstall ndk to continue with your project (But in general, I don't think it's necessary)"
    
        cil_yesandno 0 "Do you want to continue?"
        local choose=$?
        if [[ $choose -eq 0 ]]; then
            
            cd $TOOLCHAIN_ROOT/sysroot
            
            for f in $BUILD_PROG_WORKING_DIR/patch/ndk/*.patch; do
                echo "Applying ndk-patch: $(basename $f)"
                
                sed "s%\@APP_INSTALL_DIR\@%${APP_INSTALL_DIR}%g" "$f" | \
                    sed "s%\@APP_HOME_DIR\@%${APP_HOME_DIR}%g" | \
                    patch --silent -p1;
            done
        
        else
            echo "Of course."
        fi
    fi
    
    save_prog_data
}