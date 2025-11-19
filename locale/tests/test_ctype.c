#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "../include/locale.h"

void test_ctype_basic() {
    printf("=== 测试基础字符分类 ===\n");
    
    printf("C locale:\n");
    setlocale(LC_CTYPE, "C");
    
    printf("  isalpha('A'): %d\n", isalpha('A'));
    printf("  isalpha('中'): %d\n", isalpha('中'));
    printf("  isalnum('A'): %d\n", isalnum('A')); 
    printf("  isalnum('中'): %d\n", isalnum('中'));
    printf("  isprint('中'): %d\n", isprint('中'));
    
    printf("zh_CN.UTF-8 locale:\n");
    setlocale(LC_CTYPE, "zh_CN.UTF-8");
    
    printf("  isalpha('A'): %d\n", isalpha('A'));
    printf("  isalpha('中'): %d\n", isalpha('中'));
    printf("  isalnum('A'): %d\n", isalnum('A'));
    printf("  isalnum('中'): %d\n", isalnum('中'));
    printf("  isprint('中'): %d\n", isprint('中'));
    
    printf("\n");
}

void test_chinese_string() {
    printf("=== 测试中文字符串处理 ===\n");
    
    setlocale(LC_CTYPE, "zh_CN.UTF-8");
    
    const char *test_str = "Hello世界123";
    printf("测试字符串: %s\n", test_str);
    
    int alpha_count = 0, alnum_count = 0, print_count = 0;
    
    for (int i = 0; test_str[i] != '\0'; i++) {
        if (isalpha(test_str[i])) alpha_count++;
        if (isalnum(test_str[i])) alnum_count++;
        if (isprint(test_str[i])) print_count++;
    }
    
    printf("  字母字符数: %d\n", alpha_count);
    printf("  字母数字字符数: %d\n", alnum_count);
    printf("  可打印字符数: %d\n", print_count);
    printf("\n");
}

int main() {
    printf("字符分类函数测试\n");
    printf("================\n\n");
    
    test_ctype_basic();
    test_chinese_string();
    
    printf("测试完成！\n");
    return 0;
}