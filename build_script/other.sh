#!/usr/bin/bash

# ===================== UI 函数 =====================

# 结果显示
result_display() {
    echo "========================================================"
    if [ -f "output/base.zip" ]; then
        echo -e "\e[1;32m编译完成！\e[0m"
        echo "输出文件: output/base.zip"
        echo "目标架构: $TARGET_ARCH"
        echo "安装目录: $APP_INSTALL_DIR"
        echo "构建的包:"
        for pkg in "${!PACKAGES[@]}"; do
            if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
                echo "  - ${PACKAGES[$pkg]} (${PKG_VERSIONS[$pkg]})"
            fi
        done
    else
        echo -e "\e[1;31m编译未完成或出错！请检查日志。\e[0m"
    fi
    echo "========================================================"
    
    local total_end_time=$(date +%s.%N)
    local total_elapsed_time=$(echo "$total_end_time - $total_start_time" | bc | awk '{printf "%.2f", $0}')
    echo -e "\n\e[1;32m[OK] 所有步骤完成! 总耗时: ${total_elapsed_time}秒\e[0m"
    
    sleep 5 #给用户留时间查看
}

# 完整构建流程
full_build_process() {
    # 显示开始信息
    clear
    echo "==========================================="
    echo " Super Development Environment 编译程序"
    echo "==========================================="
    echo "总包: ${#PACKAGES[@]} 个包"
    echo "将要构建: ${PKG_TO_BUILD} 个包"
    echo -e "\n\e[1;33m将在3秒后开始...\e[0m"
    sleep 3
    
    clear
    
    # 准备进度显示
    local current_step=0
    
    # 记录总开始时间（安静模式用）
    export total_start_time=$(date +%s.%N)
    trap 'echo -e "\rPlease wait... \e[1;31m[FAILED]\e[0m 用户取消操作!" && echo && exit' SIGINT SIGTERM
    
    echo -e "\n"  # 为进度条留出空间
    
    # 显示初始进度条
    echo -e "\n\e[1;32m编译进度:\e[0m"
    show_progress 0
    
    # 按顺序执行各步骤
    for ((cstep=0; cstep<TOTAL_STEPS; cstep++)); do
        ((current_step++))
        run_step "${STEP_NAMES[cstep]}" "${STEP_FUNCTIONS[cstep]}" $current_step
        
        local end_time=$(date +%s.%N)
        local elapsed_time=$(echo "$end_time - $total_start_time" | bc | awk '{printf "%d", $0}')
        
        long_time_check $elapsed_time $((cstep+1))
        
        unset end_time elapsed_time
    done
    
    # 显示完成信息
    result_display
}

# 手动构建步骤
manual_build_steps() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        for ((i=0; i<TOTAL_STEPS; i++)); do
            options+=("$((i+1))" "${STEP_NAMES[i]}")
        done
        
        choice=$(dialog --backtitle "构建步骤" \
                     --title "手动构建" \
                     --menu "选择要执行的步骤：" 17 50 8 \
                     "${options[@]}" \
                     3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -ge 1 && $choice -le $TOTAL_STEPS ]]; then
            local step_index=$((choice-1))
            echo -e "\n\e[1;34m步骤: ${STEP_NAMES[step_index]}...\e[0m"
            run_step "手动" ${STEP_FUNCTIONS[step_index]} 99999
        fi
    done
}

# ==================== 保存/加载配置 ====================

# 保存配置到文件
save_config() {
    > "$CONFIG_FILE"
    for key in "${!CONFIG_ITEMS[@]}"; do
        echo "$key=\"${!key}\"" >> "$CONFIG_FILE"
    done
    dialog --msgbox "配置已保存到 $CONFIG_FILE" 7 50
}

# 从文件加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "NO CONFIG!"
    fi
}

# ==================== 编辑配置 ====================

edit_config() {
    local var="$1"
    local type="${CONFIG_TYPES[$var]}"
    local current="${!var}"
    local new_value

    case "$type" in
        path|number)
            new_value=$(dialog --inputbox "输入 ${CONFIG_ITEMS[$var]}:" 8 50 "$current" 3>&1 1>&2 2>&3 3>&-)
            ;;
        bool)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 30 5 \
                true "启用" \
                false "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        boolnum)
            new_value=$(dialog --menu "选择 ${CONFIG_ITEMS[$var]}:" 12 50 5 \
                1 "启用" \
                0 "禁用" 3>&1 1>&2 2>&3 3>&-)
            ;;
        arch)
            new_value=$(dialog --menu "选择目标架构:" 12 30 5 \
                aarch64 "ARM64 (推荐)" \
                arm "ARM32" \
                x86 "x86" \
                x86_64 "x86_64" 3>&1 1>&2 2>&3 3>&-)
            ;;
    esac

    [ -n "$new_value" ] && export "$var=$new_value"
}

configure_settings() {
    while true; do
        menu_items=()
        menu_items+=("0" "返回")
        menu_items+=("S" "保存配置")
        i=1
        for key in "${!CONFIG_ITEMS[@]}"; do
            value="${!key}"
            menu_items+=("$i" "${CONFIG_ITEMS[$key]} [$value]")
            keys[$i]="$key"
            ((i++))
        done
        
        choice=$(dialog --menu "选择要修改的配置：" 20 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3 3>&-)

        case "$choice" in
            0|"") break ;;
            S) save_config ;;
            *) edit_config "${keys[$choice]}" ;;
        esac
    done
}

# ==================== 包管理函数 ====================

# 保存包配置
save_pkg_config() {
    > "$PKG_CONFIG_FILE"
    for pkg in "${!PACKAGES[@]}"; do
        echo "PKG_ENABLE_${pkg}=\"${PKG_ENABLE[$pkg]}\"" >> "$PKG_CONFIG_FILE"
    done
    for pkg in "${!PACKAGES[@]}"; do
        echo "PKG_VERSION_${pkg}=\"${PKG_VERSIONS[$pkg]}\"" >> "$PKG_CONFIG_FILE"
    done
    echo "PKG_TO_BUILD=${PKG_TO_BUILD}" >> "$PKG_CONFIG_FILE"
    dialog --msgbox "包配置已保存到 $PKG_CONFIG_FILE" 7 50
}

# 加载包配置
load_pkg_config() {
    if [[ -f "$PKG_CONFIG_FILE" ]]; then
        source "$PKG_CONFIG_FILE"
        # 将加载的配置应用到数组
        for pkg in "${!PACKAGES[@]}"; do
            local enable_var="PKG_ENABLE_${pkg}"
            local version_var="PKG_VERSION_${pkg}"
            if [ -n "${!enable_var}" ]; then
                PKG_ENABLE["$pkg"]="${!enable_var}"
            fi
            if [ -n "${!version_var}" ]; then
                PKG_VERSIONS["$pkg"]="${!version_var}"
            fi
        done
    else
        echo "NO PKG CONFIG!"
    fi
    
    # 计算要构建的包数量
    PKG_TO_BUILD=0
    for pkg in "${!PACKAGES[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
            ((PKG_TO_BUILD++))
        fi
    done
}

# 包管理菜单
package_management_menu() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        options+=("1" "保存配置")
        
        local i=2
        for pkg in "${!PACKAGES[@]}"; do
            local status="禁用"
            [ "${PKG_ENABLE[$pkg]}" = "true" ] && status="启用"
            options+=("$i" "${PACKAGES[$pkg]} [$status]")
            pkg_keys[$i]="$pkg"
            ((i++))
        done
        
        choice=$(dialog --menu "包管理 - 选择要配置的包：" 17 50 8 \
                 "${options[@]}" \
                 3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ $choice -eq 1 ]]; then
            save_pkg_config
        elif [[ -n "${pkg_keys[$choice]}" ]]; then
            configure_package "${pkg_keys[$choice]}"
        fi
    done
}

# 配置单个包
configure_package() {
    local pkg=$1
    local current_enable="${PKG_ENABLE[$pkg]}"
    local current_version="${PKG_VERSIONS[$pkg]}"
    
    while true; do
        choice=$(dialog --menu "配置 ${PACKAGES[$pkg]}：" 12 40 5 \
                 0 "返回" \
                 1 "启用状态: $current_enable" \
                 2 "版本: $current_version" \
                 3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1)
                new_value=$(dialog --menu "选择启用状态：" 10 30 3 \
                          "true" "启用" \
                          "false" "禁用" \
                          3>&1 1>&2 2>&3 3>&-)
                if [ -n "$new_value" ]; then
                    PKG_ENABLE[$pkg]="$new_value"
                    current_enable="$new_value"
                    # 更新构建计数
                    if [ "$new_value" = "true" ]; then
                        ((PKG_TO_BUILD++))
                    else
                        ((PKG_TO_BUILD--))
                    fi
                fi
                ;;
            2)
                new_value=$(dialog --inputbox "输入版本号：" 8 40 "$current_version" \
                          3>&1 1>&2 2>&3 3>&-)
                if [ -n "$new_value" ]; then
                    PKG_VERSIONS[$pkg]="$new_value"
                    current_version="$new_value"
                fi
                ;;
            0|"") break ;;
        esac
    done
}

# 清理输出
clean_output() {
    if dialog --yesno "确定要清理所有输出文件吗?" 7 50; then
        echo "清理输出文件..."
        
        rm -rfv termux-elf-cleaner coreutils-* output bash-* zlib-* \
            openssl-* base $NDK_FILE
        
        cd installer
        rm -rfv libs obj
        cd $BUILD_PROG_WORKING_DIR
        rm -rfv base
        
        dialog --msgbox "输出文件已清理！" 6 40
    fi
}

build_by_pkg() {
    while true; do
        options=()
        options+=("0" "返回主菜单")
        
        local i=1
        for pkg in "${!PACKAGES[@]}"; do
            if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
                options+=("$i" "构建 ${PACKAGES[$pkg]}")
                pkg_keys[$i]="$pkg"
                ((i++))
            fi
        done
        
        choice=$(dialog --menu "选择要构建的包：" 17 50 8 \
                 "${options[@]}" \
                 3>&1 1>&2 2>&3 3>&-)
        
        if [[ $choice -eq 0 ]]; then
            break
        elif [[ -n "${pkg_keys[$choice]}" ]]; then
            clear
            
            local pkg_name="${pkg_keys[$choice]}"
            local pkg_steps_list="${PKG_STEPS[$pkg_name]}"
            local will_runing_step=$(echo "${pkg_steps_list}" | tr " " "\n")
            
            local the_cont=0
            
            for the_step in $will_runing_step; do
                the_cont=$((the_cont + 1))
                run_step "构建${pkg_name}的第${the_cont}个步骤" "${the_step}" 0
            done
        fi
    done
}

# 主菜单
main_menu() {
    while true; do
        choice=$(dialog --backtitle "Super Development Environment 编译程序 ${BUILD_PROG_VERSION}" \
                        --title "主菜单" \
                        --menu "请选择操作：" 20 60 10 \
                        1 "完整构建流程" \
                        2 "手动构建步骤" \
                        3 "单独构建包" \
                        4 "配置设置" \
                        5 "清理输出" \
                        6 "包管理" \
                        7 "更改分支" \
                        8 "关于${BRANCH}分支" \
                        9 "关于" \
                        0 "退出" \
                        3>&1 1>&2 2>&3 3>&-)
        
        case $choice in
            1) full_build_process ;;
            2) manual_build_steps ;;
            3) build_by_pkg ;;
            4) configure_settings ;;
            5) clean_output ;;
            6) package_management_menu ;;
            7) change_branch ;;
            8) adout_branch ;;
            9) adout_this_prog ;;
            0) clear && exit 0 ;;
            *) return ;;
        esac
    done
}