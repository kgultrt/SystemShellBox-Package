#include "../include/bits/locale_impl.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <dlfcn.h>

// 保存系统的原始函数指针
static char *(*original_setlocale)(int, const char *) = NULL;

// 初始化系统函数指针
static void init_original_functions(void) {
    if (!original_setlocale) {
        original_setlocale = dlsym(RTLD_NEXT, "setlocale");
    }
}

/* Simple locale data structure */
struct __locale_data {
    const char *name;
    void *data;
};

/* Default C locale instances */
struct __locale_data __C_ctype_locale = { "C", NULL };
struct __locale_data __C_numeric_locale = { "C", NULL };
struct __locale_data __C_time_locale = { "C", NULL };
struct __locale_data __C_collate_locale = { "C", NULL };
struct __locale_data __C_monetary_locale = { "C", NULL };
struct __locale_data __C_messages_locale = { "C", NULL };
struct __locale_data __C_paper_locale = { "C", NULL };
struct __locale_data __C_name_locale = { "C", NULL };
struct __locale_data __C_address_locale = { "C", NULL };
struct __locale_data __C_telephone_locale = { "C", NULL };
struct __locale_data __C_measurement_locale = { "C", NULL };
struct __locale_data __C_identification_locale = { "C", NULL };

static char current_locale_name[64] = "C";

const char *get_current_locale_name(void) {
    return current_locale_name;
}

void apply_C_locale(int category) {
    /* C locale is already set by default */
}

void apply_zh_CN_UTF8_locale(int category) {
    /* Chinese locale will be applied when functions are called */
}

void apply_zh_TW_UTF8_locale(int category) {
    /* Traditional Chinese locale */
}

char *setlocale(int category, const char *locale) {
    init_original_functions();
    
    if (category < LC_CTYPE || category > LC_IDENTIFICATION) {
        return NULL;
    }
    
    /* Query current locale */
    if (locale == NULL) {
        return current_locale_name;
    }
    
    /* Set locale */
    if (strcmp(locale, "C") == 0 || strcmp(locale, "POSIX") == 0) {
        strcpy(current_locale_name, "C");
        if (category == LC_ALL || category == LC_CTYPE) {
            apply_C_locale(category);
        }
        // 也调用系统实现
        if (original_setlocale) {
            return original_setlocale(category, locale);
        }
        return current_locale_name;
    }
    
    /* Support Chinese UTF-8 */
    if (strcmp(locale, "zh_CN.UTF-8") == 0 || 
        strcmp(locale, "zh_CN.utf8") == 0 ||
        strcmp(locale, "zh_CN") == 0) {
        strcpy(current_locale_name, "zh_CN.UTF-8");
        if (category == LC_ALL || category == LC_CTYPE) {
            apply_zh_CN_UTF8_locale(category);
        }
        // 也调用系统实现
        if (original_setlocale) {
            return original_setlocale(category, "C"); // 告诉系统是 C locale
        }
        return current_locale_name;
    }
    
    if (strcmp(locale, "zh_TW.UTF-8") == 0 ||
        strcmp(locale, "zh_TW.utf8") == 0 ||
        strcmp(locale, "zh_TW") == 0) {
        strcpy(current_locale_name, "zh_TW.UTF-8");
        if (category == LC_ALL || category == LC_CTYPE) {
            apply_zh_TW_UTF8_locale(category);
        }
        // 也调用系统实现
        if (original_setlocale) {
            return original_setlocale(category, "C"); // 告诉系统是 C locale
        }
        return current_locale_name;
    }
    
    /* Unsupported locale - 回退到系统实现 */
    if (original_setlocale) {
        char *result = original_setlocale(category, locale);
        if (result) {
            strncpy(current_locale_name, result, sizeof(current_locale_name)-1);
        }
        return result;
    }
    
    return NULL;
}

struct lconv *localeconv(void) {
    static struct lconv lc;
    const char *locale = get_current_locale_name();
    int is_chinese = (strstr(locale, "zh_CN") || strstr(locale, "zh_TW"));
    
    /* Reset all fields */
    memset(&lc, 0, sizeof(lc));
    
    if (is_chinese) {
        /* Chinese locale settings */
        lc.decimal_point = ".";
        lc.thousands_sep = ",";
        lc.grouping = "\3";
        lc.currency_symbol = "￥";
        lc.mon_decimal_point = ".";
        lc.mon_thousands_sep = ",";
        lc.mon_grouping = "\3";
        lc.positive_sign = "";
        lc.negative_sign = "-";
        lc.frac_digits = 2;
        lc.int_frac_digits = 2;
        lc.p_cs_precedes = 1;
        lc.p_sep_by_space = 0;
        lc.n_cs_precedes = 1;
        lc.n_sep_by_space = 0;
        lc.p_sign_posn = 1;
        lc.n_sign_posn = 1;
    } else {
        /* C locale settings */
        lc.decimal_point = ".";
        lc.thousands_sep = "";
        lc.grouping = "";
        lc.int_curr_symbol = "";
        lc.currency_symbol = "";
        lc.mon_decimal_point = "";
        lc.mon_thousands_sep = "";
        lc.mon_grouping = "";
        lc.positive_sign = "";
        lc.negative_sign = "";
        lc.int_frac_digits = 127;
        lc.frac_digits = 127;
        lc.p_cs_precedes = 127;
        lc.p_sep_by_space = 127;
        lc.n_cs_precedes = 127;
        lc.n_sep_by_space = 127;
        lc.p_sign_posn = 127;
        lc.n_sign_posn = 127;
    }
    
    return &lc;
}