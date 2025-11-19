// tests/test_basic.c
#include <stdio.h>
#include "../include/locale.h"
#include "../include/langinfo.h"

// 声明你实现的函数
const char *get_current_locale_name(void);

int main() {
    printf("Testing liblocal implementation\n\n");
    
    // 测试 get_current_locale_name
    printf("0. get_current_locale_name(): %s\n", get_current_locale_name());
    
    // Test 1: Query current locale
    char *current = setlocale(LC_ALL, NULL);
    printf("1. Current locale: %s\n", current);
    printf("   get_current_locale_name(): %s\n", get_current_locale_name());
    
    // Test 2: Set to C locale
    char *result = setlocale(LC_ALL, "C");
    printf("2. Set to C locale: %s\n", result);
    printf("   get_current_locale_name(): %s\n", get_current_locale_name());
    
    struct lconv *lc = localeconv();
    printf("   Decimal point: '%s'\n", lc->decimal_point);
    printf("   Currency symbol: '%s'\n", lc->currency_symbol);
    
    // Test 3: Set to Chinese locale
    result = setlocale(LC_ALL, "zh_CN.UTF-8");
    printf("3. Set to zh_CN.UTF-8: %s\n", result);
    printf("   get_current_locale_name(): %s\n", get_current_locale_name());
    
    lc = localeconv();
    printf("   Decimal point: '%s'\n", lc->decimal_point);
    printf("   Currency symbol: '%s'\n", lc->currency_symbol);
    printf("   Thousands separator: '%s'\n", lc->thousands_sep);
    
    // Test 4: nl_langinfo - 先测试一些基本项
    printf("4. nl_langinfo tests:\n");
    printf("   CODESET: %s\n", nl_langinfo(CODESET));
    printf("   RADIXCHAR: %s\n", nl_langinfo(RADIXCHAR));
    printf("   THOUSEP: %s\n", nl_langinfo(THOUSEP));
    
    // 测试中文特定的项
    printf("5. Chinese specific tests:\n");
    printf("   DAY_1: %s\n", nl_langinfo(DAY_1));
    printf("   MON_1: %s\n", nl_langinfo(MON_1));
    printf("   AM_STR: %s\n", nl_langinfo(AM_STR));
    printf("   D_T_FMT: %s\n", nl_langinfo(D_T_FMT));
    
    return 0;
}