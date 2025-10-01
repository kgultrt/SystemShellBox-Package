cil_yesandno() {
    local default_opt="$1"
    local prompt_text="$2"
    local prompt_suffix=""
    local valid_input=0
    local result=""
    
    # 设置提示后缀和默认值
    case "$default_opt" in
        1) prompt_suffix="(Y/n) " ;;
        2) prompt_suffix="(y/N) " ;;
        0) prompt_suffix="(y/n) " ;;
        *) prompt_suffix="(y/n) " ;;
    esac
    
    # 循环直到获得有效输入
    while [[ $valid_input -eq 0 ]]; do
        echo -n "$prompt_text $prompt_suffix"
        read -r user_input
        
        # 处理空输入（使用默认值）
        if [[ -z "$user_input" ]]; then
            case "$default_opt" in
                1) result="y"; valid_input=1 ;;
                2) result="n"; valid_input=1 ;;
                0) 
                    echo -e "\e[1;31m错误：没有默认选项，请输入 y 或 n\e[0m"
                    continue
                    ;;
            esac
        else
            # 处理非空输入
            case "${user_input,,}" in  # 转换为小写比较
                y|yes) result="y"; valid_input=1 ;;
                n|no)  result="n"; valid_input=1 ;;
                *) 
                    echo -e "\e[1;31m错误：请输入 y 或 n\e[0m"
                    continue
                    ;;
            esac
        fi
    done
    
    # 返回结果 (0=yes, 1=no)
    if [[ "$result" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

cil_choose() {
    local option_count="$1"
    local default_id="$2"
    local prompt_text="$3"
    shift 3

    local options=("$@")
    local option_codes=()
    local option_texts=()
    local valid_input=0
    local user_choice=""
    local default_code=""

    # 验证选项数量不超过255
    if [[ $option_count -gt 255 ]]; then
        echo -e "\e[1;31m错误：选项数量不能超过255\e[0m"
        return 1
    fi

    # 解析选项
    for ((i=0; i<option_count; i++)); do
        local option="${options[i]}"
        # 使用第一个 "-" 作为分隔符
        local code="${option%%-*}"
        local text="${option#*-}"
        
        option_codes[i]="$code"
        option_texts[i]="$text"
    done

    # 设置默认选项代码
    if [[ $default_id -gt 0 ]] && [[ $default_id -le $option_count ]]; then
        default_code="${option_codes[$((default_id-1))]}"
    fi

    # 构建选项显示字符串
    local option_display=""
    for ((i=0; i<option_count; i++)); do
        local code="${option_codes[i]}"
        local text="${option_texts[i]}"
        
        if [[ -n "$option_display" ]]; then
            option_display="$option_display, "
        fi
        option_display="$option_display[$code]$text"
    done

    # 构建默认提示
    local default_prompt=""
    if [[ -n "$default_code" ]]; then
        default_prompt=" (Default: $default_code)"
    else
        default_prompt=" (Default: NONE)"
    fi

    # 显示提示信息
    echo -n "$prompt_text $option_display$default_prompt: "

    # 交互循环
    while [[ $valid_input -eq 0 ]]; do
        read -r user_choice
        
        # 处理空输入（使用默认值）
        if [[ -z "$user_choice" ]]; then
            if [[ -n "$default_code" ]]; then
                # 返回默认选项的ID
                return $default_id
            else
                echo -e "\e[1;31m错误：没有默认选项，请选择一个选项\e[0m"
                echo -n "请选择: "
                continue
            fi
        fi
        
        # 验证输入（不区分大小写）
        user_choice_upper="${user_choice^^}"  # 转换为大写
        
        for ((i=0; i<option_count; i++)); do
            code_upper="${option_codes[i]^^}"  # 选项代码也转换为大写比较
            
            if [[ "$user_choice_upper" == "$code_upper" ]]; then
                valid_input=1
                # 返回选项ID（从1开始）
                return $((i + 1))
            fi
        done
        
        # 如果到这里，说明输入无效
        echo -e "\e[1;31m错误：无效选项 '$user_choice'，请从 [${option_codes[*]}] 中选择\e[0m"
        echo -n "请选择: "
    done
}

# 测试函数
test_yesno() {
    echo "=== cil_yesandno 测试 ==="
    
    echo "测试1: 默认Y"
    if cil_yesandno 1 "Do you want to continue?"; then
        echo "用户选择了: YES"
    else
        echo "用户选择了: NO"
    fi
    
    echo -e "\n测试2: 默认N" 
    if cil_yesandno 2 "Are you sure?"; then
        echo "用户选择了: YES"
    else
        echo "用户选择了: NO"
    fi
    
    echo -e "\n测试3: 无默认"
    if cil_yesandno 0 "Proceed without default?"; then
        echo "用户选择了: YES"
    else
        echo "用户选择了: NO"
    fi
}

test_choose() {
    echo -e "\n=== cil_choose 测试 ==="
    
    echo "测试1: 有默认选项"
    cil_choose 3 3 "What do you want to do?" "R-Replace" "C-Continue" "N-Do nothing"
    local choice1=$?
    echo "用户选择了: $choice1"
    
    echo -e "\n测试2: 无默认选项"
    cil_choose 2 0 "Choose mode:" "D-Debug" "R-Release"
    local choice2=$?
    echo "用户选择了: $choice2"
    
    echo -e "\n测试3: 中文选项"
    cil_choose 4 1 "请选择操作:" "C-继续" "S-跳过" "R-重试" "Q-退出"
    local choice3=$?
    echo "用户选择了: $choice3"
}

# 运行测试（取消注释来测试）
# test_yesno
# test_choose