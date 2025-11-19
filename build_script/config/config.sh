# 配置项定义：变量=描述
declare -A CONFIG_ITEMS=(
    [ANDROID_NDK]="Android NDK路径"
    [APP_INSTALL_DIR]="安装目录"
    [APP_HOME_DIR]="家目录"
    [TARGET_ARCH]="目标架构"
    [ANDROID_API]="Android API级别"
    [NEED_CLEAN_ELF]="是否对齐 ELF 头"
    [IS_QUIET]="安静输出"
    [WRITE_LOG]="安静模式下保存日志"
    [TO_BREAK_TIME]="每隔多久暂停一次 (单位: 小时)"
    [TOO_LONG_TIME_BREAK]="自行暂停超长时间构建"
    [DISADIE_PROGRESS]="禁用进度条"
    [APP_DIR]="应用目录"
    [APP_LIB_DIR]="应用lib目录"
)

# 类型定义：变量=输入方式
declare -A CONFIG_TYPES=(
    [ANDROID_NDK]="path"
    [APP_INSTALL_DIR]="path"
    [APP_HOME_DIR]="path"
    [TARGET_ARCH]="arch"
    [ANDROID_API]="number"
    [NEED_CLEAN_ELF]="bool"
    [IS_QUIET]="boolnum"
    [WRITE_LOG]="boolnum"
    [TO_BREAK_TIME]="number"
    [TOO_LONG_TIME_BREAK]="boolnum"
    [DISADIE_PROGRESS]="boolnum"
    [APP_DIR]="path"
    [APP_LIB_DIR]="path"
)