check_system() {
    local termux_path_1="/data/data/com.termux/files"
    local termux_path_2="/data/user/0/com.termux/files"
    local runing_path="$BUILD_PROG_WORKING_DIR"
    
    if [[ $runing_path =~ $termux_path_1 ]] || [[ $runing_path =~ $termux_path_2 ]]; then
        echo "IS TERMUX!"
        echo "IS_LIUNX=0" >> "$SYSTEM_CHECK_FILE"
    else
        
        echo "Hold on a second..."
        cil_yesandno 0 "Are you running on liunx?"
        local is_liunx=$?
        
        if [[ $is_liunx -eq 0 ]]; then
            
            IS_LIUNX=1
            echo "IS_LIUNX=1" >> "$SYSTEM_CHECK_FILE"
            
            echo "OK,"
            cil_choose 1 0 "Select your liunx distribution type" "D-Debian"
            local system_type=$?
            LIUNX_TYPE=$system_type
            echo "LIUNX_TYPE=${LIUNX_TYPE}" >> "$SYSTEM_CHECK_FILE"
            
            echo "OK,"
            echo "This program will resume loading after 3 seconds..."
            sleep 3
        else
            echo "IS_LIUNX=0" >> "$SYSTEM_CHECK_FILE"
            echo
            echo "OK,"
            echo "Give a warning that if you are running on another environment,"
            echo -e "\e[1;31mThis program may not work properly and may even harm your system.\e[0m"
            echo "This program will resume loading after 30 seconds..."
            sleep 30
        fi
    fi
}