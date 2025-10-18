# 修复后的依赖关系解析函数
resolve_dependencies() {
    local target_pkg="$1"
    
    # 使用局部变量避免全局污染
    local -a _RESOLVED_DEPS=()
    local -a _VISITED_DEPS=()
    
    _resolve_deps_recursive_fixed "$target_pkg"
    
    # 返回解析后的包列表（按依赖顺序）
    echo "${_RESOLVED_DEPS[@]}"
}

_resolve_deps_recursive_fixed() {
    local current_pkg="$1"
    
    # 检查是否已经在访问中（检测循环依赖）
    if [[ " ${_VISITED_DEPS[@]} " =~ " $current_pkg " ]]; then
        echo "警告: 检测到循环依赖，包: $current_pkg" >&2
        return
    fi
    
    # 标记为正在访问
    _VISITED_DEPS+=("$current_pkg")
    
    # 递归解析依赖
    local deps="${PKG_DEPENDS[$current_pkg]}"
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if [[ -n "$dep" && "${PKG_ENABLE[$dep]}" = "true" ]]; then
                _resolve_deps_recursive_fixed "$dep"
            fi
        done
    fi
    
    # 只有当包没有被解析过时才添加
    if ! [[ " ${_RESOLVED_DEPS[@]} " =~ " $current_pkg " ]]; then
        _RESOLVED_DEPS+=("$current_pkg")
    fi
    
    # 从访问列表中移除（回溯）
    _VISITED_DEPS=("${_VISITED_DEPS[@]/$current_pkg}")
}

# 优化的获取所有启用的包函数
get_enabled_packages_ordered() {
    local -a enabled_packages=()
    local -a all_ordered=()
    local -a processed=()
    
    # 首先收集所有启用的包
    for pkg in "${!PACKAGES[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
            enabled_packages+=("$pkg")
        fi
    done
    
    # 为每个启用的包解析依赖
    for pkg in "${enabled_packages[@]}"; do
        if [[ " ${processed[@]} " =~ " $pkg " ]]; then
            continue
        fi
        
        local pkg_deps=($(resolve_dependencies "$pkg"))
        for dep_pkg in "${pkg_deps[@]}"; do
            # 只添加启用的依赖包，且未处理过的
            if [ "${PKG_ENABLE[$dep_pkg]}" = "true" ] && \
               ! [[ " ${all_ordered[@]} " =~ " $dep_pkg " ]]; then
                all_ordered+=("$dep_pkg")
                processed+=("$dep_pkg")
            fi
        done
    done
    
    echo "${all_ordered[@]}"
}

# 检查依赖是否满足
check_dependencies() {
    local pkg="$1"
    local missing_deps=()
    
    local deps="${PKG_DEPENDS[$pkg]}"
    for dep in $deps; do
        if [[ -n "$dep" && "${PKG_ENABLE[$dep]}" != "true" ]]; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "错误: 包 $pkg 需要以下依赖包: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# 增强的依赖验证函数
validate_all_dependencies() {
    local errors=0
    local -a checked_packages=()
    
    for pkg in "${!PACKAGES[@]}"; do
        if [ "${PKG_ENABLE[$pkg]}" = "true" ]; then
            # 避免重复检查
            if [[ " ${checked_packages[@]} " =~ " $pkg " ]]; then
                continue
            fi
            
            if ! check_dependencies "$pkg"; then
                ((errors++))
            fi
            checked_packages+=("$pkg")
            
            # 同时检查依赖包
            local deps="${PKG_DEPENDS[$pkg]}"
            for dep in $deps; do
                if [[ -n "$dep" && ! " ${checked_packages[@]} " =~ " $dep " ]]; then
                    if ! check_dependencies "$dep"; then
                        ((errors++))
                    fi
                    checked_packages+=("$dep")
                fi
            done
        fi
    done
    return $errors
}

# 显示包依赖信息
show_package_dependencies() {
    local pkg="$1"
    local deps="${PKG_DEPENDS[$pkg]}"
    
    if [[ -z "$deps" ]]; then
        echo "无依赖"
    else
        echo "$deps"
    fi
}

# 查看依赖关系图
show_dependency_graph() {
    local graph_info="包依赖关系图:\n\n"
    
    for pkg in "${!PACKAGES[@]}"; do
        local deps="${PKG_DEPENDS[$pkg]}"
        if [[ -z "$deps" ]]; then
            graph_info+="• ${PACKAGES[$pkg]} [无依赖]\n"
        else
            graph_info+="• ${PACKAGES[$pkg]} → $deps\n"
        fi
    done
    
    dialog --msgbox "$graph_info" 25 80
}

# 验证依赖菜单
validate_dependencies_menu() {
    if validate_all_dependencies; then
        dialog --msgbox "所有依赖关系都满足！" 10 40
    else
        dialog --msgbox "存在未满足的依赖关系，请检查包配置。" 10 50
    fi
}

# 增强的包信息显示
show_package_info() {
    local options=()
    for pkg in "${!PACKAGES[@]}"; do
        options+=("$pkg" "${PACKAGES[$pkg]}")
    done
    
    local choice=$(dialog --menu "选择要查看的包：" 20 60 10 \
                 "${options[@]}" \
                 3>&1 1>&2 2>&3 3>&-)
    
    if [[ -n "$choice" ]]; then
        local info="包名: ${PACKAGES[$choice]}\n"
        info+="内部名称: $choice\n"
        info+="版本: ${PKG_VERSIONS[$choice]}\n"
        info+="状态: ${PKG_ENABLE[$choice]}\n"
        info+="依赖: $(show_package_dependencies "$choice")\n"
        info+="构建步骤: ${PKG_STEPS[$choice]}"
        
        dialog --msgbox "$info" 15 70
    fi
}

# 调试函数：显示依赖解析过程
debug_dependency_resolution() {
    local pkg="$1"
    echo "调试: 解析包 $pkg 的依赖..."
    echo "依赖定义: ${PKG_DEPENDS[$pkg]}"
    
    local deps=($(resolve_dependencies "$pkg"))
    echo "解析结果: ${deps[*]}"
    echo "---"
}

# 测试依赖解析
test_dependency_resolution() {
    echo "测试依赖解析..."
    
    # 测试 zlib（应该没有循环依赖）
    echo "测试 zlib:"
    debug_dependency_resolution "zlib"
    
    # 测试 openssl
    echo "测试 openssl:"
    debug_dependency_resolution "openssl"
    
    # 测试 libssh2
    echo "测试 libssh2:"
    debug_dependency_resolution "libssh2"
    
    # 测试 curl
    echo "测试 curl:"
    debug_dependency_resolution "curl"
    
    echo "测试完成"
}

# 显示构建顺序
show_build_order() {
    local build_order=($(get_enabled_packages_ordered))
    local order_info="构建顺序:\n\n"
    
    for ((i=0; i<${#build_order[@]}; i++)); do
        order_info+="$((i+1)). ${build_order[i]}\n"
    done
    
    dialog --msgbox "$order_info" 20 60
}