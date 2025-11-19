#ifndef _LOCALE_H
#define _LOCALE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <xlocale.h>  // 使用系统定义的 locale_t
#include <time.h>     // 包含系统 timezone_t 定义
#include <stdbool.h>  // 包含 bool 类型定义

// 基础 locale 类别
#define LC_CTYPE          0
#define LC_NUMERIC        1
#define LC_TIME           2
#define LC_COLLATE        3
#define LC_MONETARY       4
#define LC_MESSAGES       5
#define LC_ALL            6

// GNU 扩展的 locale 类别
#define LC_PAPER          7
#define LC_NAME           8
#define LC_ADDRESS        9
#define LC_TELEPHONE      10
#define LC_MEASUREMENT    11
#define LC_IDENTIFICATION 12

// GNU 全局 locale 常量
#define LC_GLOBAL_LOCALE ((locale_t)-1L)

struct lconv {
    char *decimal_point;
    char *thousands_sep;
    char *grouping;
    char *int_curr_symbol;
    char *currency_symbol;
    char *mon_decimal_point;
    char *mon_thousands_sep;
    char *mon_grouping;
    char *positive_sign;
    char *negative_sign;
    char int_frac_digits;
    char frac_digits;
    char p_cs_precedes;
    char p_sep_by_space;
    char n_cs_precedes;
    char n_sep_by_space;
    char p_sign_posn;
    char n_sign_posn;
};

char *setlocale(int category, const char *locale);
struct lconv *localeconv(void);

/* 使用系统定义的 locale_t */
locale_t duplocale(locale_t locobj);
void freelocale(locale_t locobj);
locale_t newlocale(int category_mask, const char *locale, locale_t base);
locale_t uselocale(locale_t newloc);

#ifdef __cplusplus
}
#endif

#endif /* _LOCALE_H */