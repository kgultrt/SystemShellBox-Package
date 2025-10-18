long_time_check() {
    local time=$1
    local current_step=$2
    
    local max_time=$((TO_BREAK_TIME * 3600 * TOO_LONG_TIME_BREAK_WARN_TIMES))
    
    if [[ $TOO_LONG_TIME_BREAK -eq 1 ]]; then
        if [[ $time -ge $max_time ]]; then
            echo "构建时间过长！"
            echo "在第$current_step步停止！"
        
            cil_choose 3 1 "你希望是休息一会儿还是继续构建？" "C-继续" "R-老子休息一会儿" "N-别烦老子 (以后不再提醒)"
            local choice1=$?
        
            case $choice1 in
                1)
                    TOO_LONG_TIME_BREAK_WARN_TIMES=$((TOO_LONG_TIME_BREAK_WARN_TIMES+1))
                    return 0
                    ;;
                    2)
                    cil_yesandno 1 "你希望保存并退出吗？(将创建进度文件)"
                    local choice2=$?
                
                    if [[ $choice2 -eq 0 ]]; then
                        cd $BUILD_PROG_WORKING_DIR
                        
                        echo "IS_PROGRESS_FILE=1" >> "$PROGRESS_FILE"
                        echo "TOO_LONG_TIME_BREAK_WARN_TIMES=${TOO_LONG_TIME_BREAK_WARN_TIMES}" >> "$PROGRESS_FILE"
                        echo "TO_BREAK_TIME=${TO_BREAK_TIME}" >> "$PROGRESS_FILE"
                        echo "STEP_PROGRESS_FILE=${current_step}" >> "$PROGRESS_FILE"
                        
                        save_config
                        save_pkg_config
                        
                        echo "已保存!"
                        
                        prog_exit
                    else
                        cil_yesandno 2 "将会不保存退出，真的不保存吗？"
                        local choice3=$?
                        
                        if [[ $choice3 -eq 0 ]]; then
                            prog_exit
                        else
                            echo "IS_PROGRESS_FILE=1" >> "$PROGRESS_FILE"
                            echo "TOO_LONG_TIME_BREAK_WARN_TIMES=${TOO_LONG_TIME_BREAK_WARN_TIMES}" >> "$PROGRESS_FILE"
                            echo "TO_BREAK_TIME=${TO_BREAK_TIME}" >> "$PROGRESS_FILE"
                            echo "STEP_PROGRESS_FILE=${current_step}" >> "$PROGRESS_FILE"
                            
                            save_config
                            save_pkg_config
                            
                            echo "已保存!"
                            
                            prog_exit
                        fi
                    fi
                    ;;
                3)
                    TOO_LONG_TIME_BREAK_WARN_TIMES=$((TOO_LONG_TIME_BREAK_WARN_TIMES+1))
                    TOO_LONG_TIME_BREAK=0
                    return 0
                    ;;
            esac
        fi
    fi
}

load_progress_file() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        source "$PROGRESS_FILE"
    else
        echo "NO PROGRESS FILE!"
    fi
}

full_build_process_progress_file() {
    # 显示开始信息
    clear
    echo "==========================================="
    echo " Super Development Environment 编译程序"
    echo "==========================================="
    echo "总包: ${#PACKAGES[@]} 个包"
    echo "将要构建: ${PKG_TO_BUILD} 个包"
    echo -e "\n\e[1;33m将在3秒后继续构建...\e[0m"
    sleep 3
    
    clear
    
    # 准备进度显示
    local current_step=$1
    local saved_step=$1
    
    # 记录总开始时间（安静模式用）
    export total_start_time=$(date +%s.%N)
    trap 'echo -e "\rPlease wait... \e[1;31m[FAILED]\e[0m 用户取消操作!" && echo && prog_exit' SIGINT SIGTERM
    
    echo -e "\n"  # 为进度条留出空间
    
    # 显示初始进度条
    echo -e "\n\e[1;32m编译进度:\e[0m"
    show_progress 0
    
    # 按顺序执行各步骤
    for ((cstep=$saved_step; cstep<TOTAL_STEPS; cstep++)); do
        ((current_step++))
        run_step "${STEP_NAMES[cstep]}" "${STEP_FUNCTIONS[cstep]}" $current_step
        
        local end_time=$(date +%s.%N)
        local elapsed_time=$(echo "$end_time - $total_start_time" | bc | awk '{printf "%d", $0}')
        
        long_time_check $elapsed_time $((cstep+1))
        
        unset end_time elapsed_time
    done
    
    # 显示完成信息
    result_display
    
    cd $BUILD_PROG_WORKING_DIR
    rm -rf $CONFIG_FILE $PKG_CONFIG_FILE $PROGRESS_FILE
    
}