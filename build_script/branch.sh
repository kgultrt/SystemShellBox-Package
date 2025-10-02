change_branch() {
    new_value=$(dialog --inputbox "输入分支:" 8 50 "$(cat $BUILD_PROG_WORKING_DIR/branch)" \
              3>&1 1>&2 2>&3 3>&-)
    if [ -n "$new_value" ]; then
        rm $BUILD_PROG_WORKING_DIR/branch
        echo "$new_value" >> $BUILD_PROG_WORKING_DIR/branch
        echo "Done!"
    fi
    
    if dialog --yesno "需要重启才能应用更改，你想现在重启吗？" 7 50; then
        clear
        exit
    fi
}