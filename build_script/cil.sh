usage() {
    echo "用法：$0 [选项]"
    echo "选项："
    echo "  没有参数                  使用GUI，这和使用 -g 参数是一样的"
    echo "  -g, --gui                 使用GUI"
    echo "  -ng, --no-gui             直接构建"
    echo "  -q, --quiet               安静输出"
    echo "  -s, --step [ID]           直接运行步骤"
    echo "  -l, --list                显示步骤列表"
    exit 1
}

CLI_GUI=1
CLI_DIREECT_BUILD=0
CLI_STEP_ID=0
CLI_LIST=0

unset_CLI() {
    unset CLI_GUI CLI_DIREECT_BUILD CLI_STEP_ID CLI_LIST
}

# 验证步骤ID的有效性
validate_step_id() {
    local step_id=$1
    if [[ -z "$step_id" ]]; then
        echo -e "\e[1;31m[FAILED]\e[0m 步骤ID不能为空"
        exit 1
    fi
    
    if [[ $step_id -lt 0 ]] || [[ $step_id -gt $((TOTAL_STEPS - 1)) ]]; then
        echo -e "\e[1;31m[FAILED]\e[0m 步骤ID不存在: $((step_id + 1))"
        exit 1
    fi
}

# 处理步骤执行
handle_step_execution() {
    local step_id=$((CLI_STEP_ID - 1))
    validate_step_id "$step_id"
    run_step "${STEP_NAMES[step_id]}" "${STEP_FUNCTIONS[step_id]}" "$((step_id + 1))"
    unset_CLI
    exit 0
}

# 处理无GUI构建
handle_no_gui() {
    CLI_GUI=0
    CLI_DIREECT_BUILD=1
}

# 处理安静模式
handle_quiet() {
    IS_QUIET=1
}

handle_list() {
    CLI_GUI=0
    
    echo
    echo "TOTAL_STEPS: ${TOTAL_STEPS}"
    
    for ((i=0; i<TOTAL_STEPS; i++)); do
        echo "$((i+1)) ${STEP_NAMES[i]}"
    done
}

# 分发参数处理
dispatch_argument() {
    case "$1" in
        -ng|--no-gui)    handle_no_gui ;;
        -q|--quiet)      handle_quiet ;;
        -g|--gui)        ;; # 默认就是GUI，不需要操作
        -s|--step)       CLI_STEP_ID=$2; handle_step_execution ;;
        -l|--list)       handle_list ;;
        *)               echo "错误：未知选项 $1"; usage ;;
    esac
}

main() {
    if [[ $IS_PROGRESS_FILE -eq 1 ]]; then
        unset_CLI
        full_build_process_progress_file $STEP_PROGRESS_FILE
        main_menu
    fi
    
    # 参数解析
    while [[ $# -gt 0 ]]; do
        dispatch_argument "$1" "$2"
        
        # 根据参数类型调整shift次数
        case "$1" in
            -s|--step) shift 2 ;; # 步骤参数需要两个参数
            *) shift ;;
        esac
    done
    
    # 根据模式执行相应操作
    if [[ $CLI_GUI -eq 1 ]]; then
        unset_CLI
        main_menu
    elif [[ $CLI_DIREECT_BUILD -eq 1 ]]; then
        unset_CLI
        full_build_process
    fi
}