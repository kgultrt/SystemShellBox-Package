usage() {
    echo "用法：$0 [选项]"
    echo "选项："
    echo "  没有参数                  使用GUI，这和使用 -g 参数是一样的"
    echo "  -g, --gui                 使用GUI"
    echo "  -ng, --no-gui             直接构建"
    echo "  -q, --quiet               安静输出"
    echo "  -s, --step [ID]           直接运行步骤"
    exit 1
}

CLI_GUI=1
CLI_DIREECT_BUILD=0
CLI_STEP_ID=0

unset_CLI() {
    unset CLI_GUI
    unset CLI_DIREECT_BUILD
    unset CLI_STEP_ID
}

main() {
    # 参数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -ng|--no-gui)
                CLI_GUI=0
                CLI_DIREECT_BUILD=1
                shift
                ;;
            -q|--quiet)
                IS_QUIET=1
                shift
                ;;
            -g|--gui)
                shift
                ;;
            -s|--step)
                local CLI_STEP_ID=$2
                
                CLI_STEP_ID=$((CLI_STEP_ID - 1))
                
                if [[ $CLI_STEP_ID -eq "" ]]; then
                    CLI_STEP_ID=0
                fi
                
                if [[ $CLI_STEP_ID -gt $((TOTAL_STEPS - 1)) ]]; then
                    echo -e "\e[1;31m[FAILED]\e[0m ID不存在"
                    exit 1
                fi
                
                if [[ $CLI_STEP_ID -lt 0 ]]; then
                    echo -e "\e[1;31m[FAILED]\e[0m ID不存在"
                    exit 1
                fi
                
                run_step "${STEP_NAMES[CLI_STEP_ID]}" ${STEP_FUNCTIONS[${CLI_STEP_ID}]} $((CLI_STEP_ID + 1))
                unset_CLI
                exit 0
                shift
                ;;
            *)
                echo "错误：未知选项 $1"
                usage
                ;;
        esac
    done
    
    if [[ $CLI_GUI -eq 1 ]]; then
        unset_CLI
        main_menu
    fi
    
    if [[ $CLI_GUI -eq 0 ]]; then
        if [[ $CLI_DIREECT_BUILD -eq 1 ]]; then
            unset_CLI
            full_build_process
        fi
    fi
}