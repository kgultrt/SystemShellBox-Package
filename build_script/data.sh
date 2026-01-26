save_prog_data() {
    local data_files="$BUILD_PROG_WORKING_DIR/build_script/config/data.txt"
    
    echo "NDK_HAS_PATCHED=${NDK_HAS_PATCHED}" >> $data_files
    echo "SPM_HAS_BUILDED=${SPM_HAS_BUILDED}" >> $data_files
    echo "LOCALE_HAS_BUILDED=${LOCALE_HAS_BUILDED}" >> $data_files

}