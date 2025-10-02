adout_this_prog() {
    echo "Please wait...!"
    
    dialog --msgbox "
    Super Development Environment 编译程序!
    (${BUILD_PROG_VERSION}, ${#PACKAGES[@]}个包可用)
    当前选择构建了${PKG_TO_BUILD}个包!
    
    shell脚本是由kgultrt制作的!
    patch/ 下的大部分内容来自termux-package!
    
    安静模式: ${IS_QUIET}
    在liunx上运行: ${IS_LIUNX}
    liunx发行版类型: ${LIUNX_TYPE}
    
    是否启用了“自行暂停超长时间构建”: ${TOO_LONG_TIME_BREAK}
    启用时，每${TO_BREAK_TIME}小时暂停一次。
    全局计数器: ${TOO_LONG_TIME_BREAK_WARN_TIMES}
    进度文件模式: ${IS_PROGRESS_FILE}
    
    
    
    Change Log:
    
        v1.0.6.005:
            初步liunx支持
            脚本里面增加了一些检查
        
        v1.0.6.004-patch3:
            修复一处错误
        
        v1.0.6.004:
            添加 自行暂停超长时间构建 功能
        
        v1.0.6.003:
            优化TUI
        
        v1.0.6.002-patch2:
            操，改错了，有点心急;
            真正的修复了一处命令错误
        
        v1.0.6.002-patch1:
            修复一处命令错误
        
        v1.0.6.002:
            开始写更新日志!
            更改打包方式，移除 base.zip
    " 70 70
}