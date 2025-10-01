adout_this_prog() {
    echo "Please wait!"
    
    dialog --msgbox "
    Super Development Environment 编译程序!
    (${BUILD_PROG_VERSION}, ${#PACKAGES[@]}个包可用)
    
    当前选择构建了${PKG_TO_BUILD}个包!
    
    shell脚本是由kgultrt制作的!
    
    patch/ 下的大部分内容来自termux-package!
    
    
    
    Change Log:
    
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
    " 70 50
}