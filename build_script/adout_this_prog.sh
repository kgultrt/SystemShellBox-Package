adout_this_prog() {
    dialog --msgbox "
    Super Development Environment 编译程序!
    (${BUILD_PROG_VERSION}, ${#PACKAGES[@]}个包可用)
    
    当前选择构建了${PKG_TO_BUILD}个包!
    
    shell脚本是由kgultrt制作的!
    
    patch/ 下的大部分内容来自termux-package!
    " 70 50
}