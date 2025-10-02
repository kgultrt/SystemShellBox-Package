#!/usr/bin/bash

# ===================== 通用功能函数 =====================

# 带进度条的显示函数
show_progress() {
    local width=50
    local percent=$1
    local completed=$((width * percent / 100))
    local remaining=$((width - completed))
    
    # 创建进度条字符串
    local progress_bar="\e[44m"
    for ((i=0; i<completed; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m\e[47m"
    for ((i=0; i<remaining; i++)); do
        progress_bar+=" "
    done
    progress_bar+="\e[0m"
    
    # 显示进度条
    tput sc  # 保存光标位置
    tput cup 0 0  # 移动到屏幕顶部
    echo -ne "\r[${progress_bar}] ${percent}%"
    tput rc  # 恢复光标位置
}

# 更新进度并显示
update_progress() {
    local current_step=$1
    local percent=$((100 * current_step / TOTAL_STEPS))
    
    show_progress $percent
    
    # 完成后换行
    if [[ $current_step -eq $TOTAL_STEPS ]]; then
        echo
    fi
}

# 旋转动画函数（安静模式使用）
spinner() {
    local pid=$1
    local delay=1
    local spinstr='/-\|'
    local i=0
    
    echo
    
    while ps -p $pid > /dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        printf "\rPlease wait... $temp ($i s)"
        sleep $delay
    done
    
    printf "\rPlease wait... "
}

# 执行命令并显示进度
run_step() {
    local step_name="$1"
    local step_func="$2"
    local step_num=$3
    pkg_check ${step_num}
    local check_result=$?

    # 记录开始时间
    local start_time=$(date +%s.%N)
    
    # 显示步骤开始
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\n\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}...\e[0m"
    else
        # 安静模式下显示步骤名称和spinner
        printf "\e[1;34mStep ${step_num}/${TOTAL_STEPS}: ${step_name}\e[0m "
    fi
    
    if [ $check_result -eq 1 ]; then
        echo "Skip it because it has been disabled!"
        # 更新进度条
        update_progress $step_num
        return
    fi
    
    # 执行步骤函数
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        # 非安静模式：显示命令输出
        $step_func
    else
        if [ -z "$WRITE_LOG" ] || [ "$WRITE_LOG" -ne 1 ]; then
            # 安静模式：重定向输出到日志文件并显示spinner
            ($step_func >> "$LOG_FILE" 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        else
            ($step_func>/dev/null 2>&1) &
            local pid=$!
            spinner $pid
            wait $pid
        fi
    fi
    
    # 计算并显示步骤耗时
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc | awk '{printf "%.2f", $0}')
    
    if [ -z "$IS_QUIET" ] || [ "$IS_QUIET" -ne 1 ]; then
        echo -e "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m"
        echo
    else
        printf "\e[1;32m[OK]\e[0m \e[2m(${elapsed_time}s)\e[0m\n"
        echo
    fi
    
    # 更新进度条
    update_progress $step_num
    
    # 刷新，清除可能多余的构建参数
    unsetup_toolchain
    setup_toolchain
}

pkg_check() {
    local step_num=$1
    local return_num=0
    
    for pkg in "${!PKG_STEPS[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "false" ]; then
            # 检查步骤是否属于这个包
            if echo "${PKG_STEPS[$pkg]}" | grep -q "\<$step_num\>"; then
                return_num=1
                break
            fi
        fi
    done
    
    return ${return_num}
}