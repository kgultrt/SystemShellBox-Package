#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

// ANSI转义码定义
#define CLEAR_SCREEN "\033[2J\033[H"
#define RESET "\033[0m"
#define BOLD "\033[1m"
#define REVERSE "\033[7m"
#define FG_RED "\033[31m"
#define FG_GREEN "\033[32m"
#define FG_YELLOW "\033[33m"
#define FG_BLUE "\033[34m"
#define FG_CYAN "\033[36m"
#define CURSOR_HIDE "\033[?25l"
#define CURSOR_SHOW "\033[?25h"
#define MOVE_CURSOR_UP "\033[1A"
#define MOVE_CURSOR_DOWN "\033[1B"

// 键盘控制码定义
#define KEY_ENTER 10  // 实际设备上通常是10而不是13
#define KEY_ESCAPE 27
#define KEY_SPACE 32
#define KEY_UP 'A'
#define KEY_DOWN 'B'
#define KEY_Q 'q'
#define KEY_Y 'y'
#define KEY_N 'n'
#define KEY_H 'h'

// 固定缓冲区大小
#define MAX_LINE_LENGTH 256
#define MAX_OPTIONS 20
#define MAX_HELP_TEXT 512

// Kconfig选项类型
typedef enum {
    OPT_BOOL,
    OPT_TRISTATE,
} OptionType;

// 选项结构
struct MenuOption {
    const char* name;
    const char* prompt;
    OptionType type;
    int value;
    int default_value;
    const char* help;
};

// 屏幕状态
typedef enum {
    MAIN_MENU,
    HELP_SCREEN,
    CONFIRM_SCREEN,
    INSTALLING,
    EXITING,
} ScreenState;

// 全局配置
struct Config {
    struct MenuOption options[MAX_OPTIONS];
    int option_count;
    const char* install_dir;
    ScreenState state;
    int quit;
    int selected;
    int terminal_rows;
    int terminal_cols;
};

// 获取终端尺寸
void get_terminal_size(int *rows, int *cols) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
        if (rows) *rows = w.ws_row;
        if (cols) *cols = w.ws_col;
    } else {
        // 回退到标准80x24
        if (rows) *rows = 24;
        if (cols) *cols = 80;
    }
}

// 初始化终端为原始模式
void enable_raw_mode() {
    struct termios term;
    tcgetattr(STDIN_FILENO, &term);
    term.c_lflag &= ~(ICANON | ECHO);
    term.c_cc[VMIN] = 1;
    term.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &term);
}

// 恢复终端设置
void disable_raw_mode() {
    struct termios term;
    tcgetattr(STDIN_FILENO, &term);
    term.c_lflag |= (ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &term);
}

// 完全处理方向键和特殊键
int read_key() {
    unsigned char c;
    if (read(STDIN_FILENO, &c, 1) != 1) return -1;
    
    // 处理方向键序列
    if (c == KEY_ESCAPE) {
        unsigned char seq[2];
        if (read(STDIN_FILENO, &seq[0], 1) != 1) return KEY_ESCAPE;
        if (read(STDIN_FILENO, &seq[1], 1) != 1) return KEY_ESCAPE;
        
        if (seq[0] == '[') {
            return seq[1]; // 返回方向键代码
        }
    }
    
    return c;
}

// 绘制顶部标题栏
void draw_header(const char* title) {
    printf(REVERSE " %s " RESET "\n", title);
}

// 绘制底部状态栏
void draw_footer(const char* message) {
    printf(REVERSE " %s " RESET "\n", message);
}

// 绘制主菜单
void draw_main_menu(struct Config* config) {
    printf(CLEAR_SCREEN);
    draw_header("Super Develop Environment Configuration");
    
    printf("\n" FG_YELLOW "Installation directory: " FG_GREEN "%s" RESET "\n\n", 
           config->install_dir);
    
    for (int i = 0; i < config->option_count; i++) {
        // 高亮当前选中项
        if (i == config->selected) {
            printf(REVERSE);
        }
        
        // 显示选项值指示器
        if (config->options[i].value == 0) {
            printf("   [ ] ");
        } else if (config->options[i].value == 1) {
            printf(FG_GREEN "   [*] " RESET);
        } else {
            printf(FG_YELLOW "   [M] " RESET);
        }
        
        // 安全打印选项文本
        printf("%s", config->options[i].prompt);
        
        printf(RESET "\n");
    }
    
    printf("\n");
    draw_footer("↑↓:Navigate  SPACE:Toggle  H:Help  ENTER:Continue  Q:Quit");
    fflush(stdout);
}

// 绘制帮助屏幕
void draw_help_screen(struct Config* config) {
    printf(CLEAR_SCREEN);
    draw_header("Option Help");
    
    if (config->selected >= 0 && config->selected < config->option_count) {
        struct MenuOption* opt = &config->options[config->selected];
        printf("\n" BOLD "%s" RESET "\n\n", opt->prompt);
        printf("%s\n\n", opt->help ? opt->help : "No help available for this option.");
        
        printf("Symbol: %s\n", opt->name);
        printf("Type: %s\n", opt->type == OPT_BOOL ? "Boolean" : "Tristate");
        printf("Status: %s\n", opt->value == 0 ? FG_RED "Disabled" RESET : 
               (opt->value == 1 ? FG_GREEN "Enabled" RESET : FG_YELLOW "Module" RESET));
        printf("Default: %s\n", opt->default_value == 0 ? "Disabled" : 
               (opt->default_value == 1 ? "Enabled" : "Module"));
    } else {
        printf("\nNo option selected.\n");
    }
    
    printf("\n");
    draw_footer("Press any key to return to main menu");
    fflush(stdout);
}

// 绘制配置确认界面
void draw_confirm_screen(struct Config* config) {
    printf(CLEAR_SCREEN);
    draw_header("Confirm Installation");
    
    printf("\nInstallation directory: " FG_GREEN "%s" RESET "\n\n", config->install_dir);
    printf("Selected components:\n\n");
    
    int enabled_count = 0;
    for (int i = 0; i < config->option_count; i++) {
        if (config->options[i].value != 0) {
            enabled_count++;
            printf("  • ");
            switch (config->options[i].type) {
                case OPT_BOOL:
                    printf("%s: %s\n", config->options[i].prompt, 
                           config->options[i].value ? "Yes" : "No");
                    break;
                case OPT_TRISTATE:
                    printf("%s: %s\n", config->options[i].prompt, 
                           config->options[i].value == 2 ? "Module" : "Yes");
                    break;
            }
        }
    }
    
    if (!enabled_count) {
        printf(FG_RED "  No components selected!" RESET "\n");
    }
    
    printf("\n");
    draw_footer("Y: Start Installation  N: Back to Configuration  Q: Quit");
    fflush(stdout);
}

// 绘制安装进度界面
void draw_install_screen(struct Config* config) {
    printf(CLEAR_SCREEN);
    draw_header("Installing Super Develop Environment");
    
    printf("\n");
    printf("Creating installation directory...\n");
    fflush(stdout);
    
    if (mkdir(config->install_dir, 0755) == 0) {
        printf(FG_GREEN "✓ Created: %s" RESET "\n\n", config->install_dir);
    } else {
        printf(FG_RED "✗ Failed to create directory! Using fallback..." RESET "\n\n");
    }
    fflush(stdout);
    
    // 安装每个选中的组件
    int step = 1;
    int total_steps = 0;
    
    // 先计算需要安装的组件数量
    for (int i = 0; i < config->option_count; i++) {
        if (config->options[i].value != 0) total_steps++;
    }
    
    for (int i = 0; i < config->option_count; i++) {
        if (config->options[i].value == 0) continue;
        
        printf("[%d/%d] ", step++, total_steps);
        fflush(stdout);
        
        switch (config->options[i].value) {
            case 1: // Enabled
                printf("Installing %s...\n", config->options[i].prompt);
                break;
            case 2: // Module
                printf("Installing %s module...\n", config->options[i].prompt);
                break;
        }
        fflush(stdout);
        
        usleep(200000); // 模拟安装过程
        printf(FG_GREEN "✓ Successfully installed\n\n" RESET);
        fflush(stdout);
    }
    
    printf("\n" FG_GREEN BOLD "Installation complete!" RESET "\n");
    printf("\nTo start the environment, run:\n");
    printf("   " FG_CYAN "%s/bin/sde" RESET "\n\n", config->install_dir);
    
    draw_footer("Press any key to exit");
    fflush(stdout);
    
    // 等待任意键退出
    config->state = EXITING;
    read_key();
}

// 主应用程序逻辑
void run_installer(struct Config* config) {
    while (!config->quit) {
        // 根据当前状态绘制界面
        switch (config->state) {
            case MAIN_MENU:
                draw_main_menu(config);
                break;
            case HELP_SCREEN:
                draw_help_screen(config);
                break;
            case CONFIRM_SCREEN:
                draw_confirm_screen(config);
                break;
            case INSTALLING:
                draw_install_screen(config);
                break;
            case EXITING:
                config->quit = 1;
                continue; // 跳过按键处理
        }
        
        int key = read_key();
        
        switch (config->state) {
            case MAIN_MENU:
                switch (key) {
                    case KEY_UP:
                        if (config->selected > 0) config->selected--;
                        break;
                    case KEY_DOWN:
                        if (config->selected < config->option_count - 1) config->selected++;
                        break;
                    case KEY_SPACE:
                        // 切换选项值
                        if (config->options[config->selected].type == OPT_BOOL) {
                            config->options[config->selected].value = 
                                !config->options[config->selected].value;
                        } else if (config->options[config->selected].type == OPT_TRISTATE) {
                            config->options[config->selected].value = 
                                (config->options[config->selected].value + 1) % 3;
                        }
                        break;
                    case KEY_ENTER:  // 主菜单的回车键
                        config->state = CONFIRM_SCREEN;
                        break;
                    case KEY_H:
                        config->state = HELP_SCREEN;
                        break;
                    case KEY_Q:
                        config->state = EXITING;
                        break;
                    default:
                        // 忽略其他按键
                        break;
                }
                break;
                
            case HELP_SCREEN:
                // 任意键返回主菜单
                if (key != -1) {
                    config->state = MAIN_MENU;
                }
                break;
                
            case CONFIRM_SCREEN:
                switch (key) {
                    case KEY_Y:
                        config->state = INSTALLING;
                        break;
                    case KEY_N:
                    case KEY_ESCAPE:
                        config->state = MAIN_MENU;
                        break;
                    case KEY_Q:
                        config->state = EXITING;
                        break;
                    case KEY_ENTER:  // 确认界面的回车键相当于确认
                        config->state = INSTALLING;
                        break;
                }
                break;
                
            default:
                config->state = MAIN_MENU;
                break;
        }
    }
}

int main() {
    // 初始化配置
    struct Config config = {0};
    
    // 初始化选项
    struct MenuOption options[] = {
        {"PKGMGR", "Package Manager", OPT_TRISTATE, 1, 1, 
            "Install the system package manager for managing software components"},
        {"DEVTOOLS", "Development Tools", OPT_TRISTATE, 1, 1, 
            "Essential development tools including compilers and debuggers"},
        {"SHELL", "Custom Shell", OPT_BOOL, 0, 0, 
            "Install the enhanced Terminal Shell environment"},
        {"SAMPLES", "Sample Projects", OPT_TRISTATE, 0, 1, 
            "Install sample projects for learning and demonstration purposes"},
        {"PYTHON", "Python Support", OPT_BOOL, 1, 1, 
            "Install Python interpreter and basic libraries"},
    };
    
    // 复制选项到配置
    config.option_count = sizeof(options) / sizeof(options[0]);
    if (config.option_count > MAX_OPTIONS) config.option_count = MAX_OPTIONS;
    memcpy(config.options, options, sizeof(options));
    
    config.install_dir = "/data/data/com.manager.ssb/files";
    config.state = MAIN_MENU;
    config.selected = 0;
    
    // 获取终端尺寸
    get_terminal_size(&config.terminal_rows, &config.terminal_cols);
    
    // 设置终端
    setvbuf(stdout, NULL, _IONBF, 0);
    printf(CURSOR_HIDE);
    fflush(stdout);
    enable_raw_mode();
    
    // 运行主应用程序
    run_installer(&config);
    
    // 清理
    printf(CURSOR_SHOW);
    disable_raw_mode();
    printf(CLEAR_SCREEN);
    printf("Installation completed!\n");
    fflush(stdout);
    
    return 0;
}