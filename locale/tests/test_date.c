#include <stdio.h>
#include <time.h>
#include "../include/locale.h"
#include "../include/langinfo.h"

// 模拟 date 命令的核心功能
void test_date_basic() {
    printf("=== 测试基础日期功能 ===\n");
    
    // 测试当前 locale
    char *current_locale = setlocale(LC_ALL, NULL);
    printf("当前 locale: %s\n", current_locale);
    
    // 获取当前时间
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    
    // 基础格式测试
    char buffer[256];
    
    // 测试 %c - 完整的日期和时间
    strftime(buffer, sizeof(buffer), "%c", tm_info);
    printf("%%c 格式: %s\n", buffer);
    
    // 测试 %x - 日期
    strftime(buffer, sizeof(buffer), "%x", tm_info);
    printf("%%x 格式: %s\n", buffer);
    
    // 测试 %X - 时间  
    strftime(buffer, sizeof(buffer), "%X", tm_info);
    printf("%%X 格式: %s\n", buffer);
    
    printf("\n");
}

void test_date_localized() {
    printf("=== 测试本地化日期功能 ===\n");
    
    // 测试 C locale
    setlocale(LC_ALL, "C");
    printf("C locale:\n");
    
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char buffer[256];
    
    strftime(buffer, sizeof(buffer), "%A %B %d %Y", tm_info);
    printf("  日期: %s\n", buffer);
    
    strftime(buffer, sizeof(buffer), "%c", tm_info);
    printf("  完整: %s\n", buffer);
    
    // 测试中文 locale
    setlocale(LC_ALL, "zh_CN.UTF-8");
    printf("zh_CN.UTF-8 locale:\n");
    
    tm_info = localtime(&now);
    strftime(buffer, sizeof(buffer), "%A %B %d %Y", tm_info);
    printf("  日期: %s\n", buffer);
    
    strftime(buffer, sizeof(buffer), "%c", tm_info);
    printf("  完整: %s\n", buffer);
    
    printf("\n");
}

void test_nl_langinfo_items() {
    printf("=== 测试 nl_langinfo 项目 ===\n");
    
    setlocale(LC_ALL, "zh_CN.UTF-8");
    
    printf("D_T_FMT: %s\n", nl_langinfo(D_T_FMT));
    printf("D_FMT: %s\n", nl_langinfo(D_FMT));
    printf("T_FMT: %s\n", nl_langinfo(T_FMT));
    
    printf("星期: %s %s %s %s %s %s %s\n",
           nl_langinfo(DAY_1), nl_langinfo(DAY_2), nl_langinfo(DAY_3),
           nl_langinfo(DAY_4), nl_langinfo(DAY_5), nl_langinfo(DAY_6),
           nl_langinfo(DAY_7));
    
    printf("月份: %s %s %s\n", 
           nl_langinfo(MON_1), nl_langinfo(MON_2), nl_langinfo(MON_3));
    
    printf("AM/PM: %s/%s\n", nl_langinfo(AM_STR), nl_langinfo(PM_STR));
    printf("\n");
}

void test_custom_formats() {
    printf("=== 测试自定义格式 ===\n");
    
    setlocale(LC_ALL, "zh_CN.UTF-8");
    
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char buffer[256];
    
    // 测试各种格式
    char *formats[] = {
        "%Y年%m月%d日 %H时%M分%S秒",  // 中文格式
        "%A, %d %B %Y",               // 星期, 日 月 年
        "%I:%M %p",                   // 12小时制 + AM/PM
        "%F %T",                      // ISO 8601
        "%c",                         // 本地默认格式
        "%x %X",                      // 日期 + 时间
        NULL
    };
    
    for (int i = 0; formats[i] != NULL; i++) {
        strftime(buffer, sizeof(buffer), formats[i], tm_info);
        printf("%-20s: %s\n", formats[i], buffer);
    }
    printf("\n");
}

void test_locale_switching() {
    printf("=== 测试 locale 切换 ===\n");
    
    time_t now = time(NULL);
    struct tm *tm_info;
    char buffer[256];
    
    // 在 C 和中文之间切换
    setlocale(LC_ALL, "C");
    tm_info = localtime(&now);
    strftime(buffer, sizeof(buffer), "%A %B", tm_info);
    printf("C locale: %s\n", buffer);
    
    setlocale(LC_ALL, "zh_CN.UTF-8");
    tm_info = localtime(&now);
    strftime(buffer, sizeof(buffer), "%A %B", tm_info);
    printf("zh_CN: %s\n", buffer);
    
    setlocale(LC_ALL, "zh_TW.UTF-8");
    tm_info = localtime(&now);
    strftime(buffer, sizeof(buffer), "%A %B", tm_info);
    printf("zh_TW: %s\n", buffer);
    
    printf("\n");
}

int main() {
    printf("日期命令 locale 功能测试\n");
    printf("=======================\n\n");
    
    test_date_basic();
    test_date_localized();
    test_nl_langinfo_items();
    test_custom_formats();
    test_locale_switching();
    
    printf("测试完成！\n");
    return 0;
}