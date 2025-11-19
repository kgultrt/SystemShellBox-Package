#include <time.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <dlfcn.h>
#include "../include/langinfo.h"
#include "../include/bits/locale_impl.h"

// 保存系统原始函数指针
static size_t (*original_strftime)(char *, size_t, const char *, const struct tm *) = NULL;

// 初始化系统函数指针
static void init_original_functions(void) {
    if (!original_strftime) {
        original_strftime = dlsym(RTLD_NEXT, "strftime");
    }
}

// 基于 Android 的代码，但使用我们的 nl_langinfo
static char * _add(const char *str, char *pt, const char *ptlim, int modifier) {
    int c;

    switch (modifier) {
    case 0x100: // FORCE_LOWER_CASE
        while (pt < ptlim && (*pt = tolower(*str++)) != '\0') {
            ++pt;
        }
        break;

    case '^':
        while (pt < ptlim && (*pt = toupper(*str++)) != '\0') {
            ++pt;
        }
        break;

    case '#':
        while (pt < ptlim && (c = *str++) != '\0') {
            if (isupper(c)) {
                c = tolower(c);
            } else if (islower(c)) {
                c = toupper(c);
            }
            *pt = c;
            ++pt;
        }
        break;

    default:
        while (pt < ptlim && (*pt = *str++) != '\0') {
            ++pt;
        }
    }

    return pt;
}

static char * _conv(int n, const char *format, char *pt, const char *ptlim) {
    char buf[32];
    snprintf(buf, sizeof(buf), format, n);
    return _add(buf, pt, ptlim, 0);
}

static char * _fmt(const char *format, const struct tm *t, char *pt, 
                   const char *ptlim, int *warnp);

// 简化的 strftime 实现，使用我们的 nl_langinfo
static char * _fmt(const char *format, const struct tm *t, char *pt, 
                   const char *ptlim, int *warnp) {
    const char *locale = get_current_locale_name();
    int is_chinese = (strstr(locale, "zh_CN") || strstr(locale, "zh_TW"));
    
    for ( ; *format; ++format) {
        if (*format == '%') {
            int modifier = 0;
            
            switch (*++format) {
            case '\0':
                --format;
                break;
            case 'A':
                if (is_chinese) {
                    pt = _add(nl_langinfo(DAY_1 + t->tm_wday), pt, ptlim, modifier);
                } else {
                    const char *en_days[] = {"Sunday", "Monday", "Tuesday", "Wednesday", 
                                           "Thursday", "Friday", "Saturday"};
                    pt = _add(en_days[t->tm_wday], pt, ptlim, modifier);
                }
                continue;
            case 'a':
                if (is_chinese) {
                    pt = _add(nl_langinfo(ABDAY_1 + t->tm_wday), pt, ptlim, modifier);
                } else {
                    const char *en_abdays[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
                    pt = _add(en_abdays[t->tm_wday], pt, ptlim, modifier);
                }
                continue;
            case 'B':
                if (is_chinese) {
                    pt = _add(nl_langinfo(MON_1 + t->tm_mon), pt, ptlim, modifier);
                } else {
                    const char *en_months[] = {"January", "February", "March", "April", 
                                             "May", "June", "July", "August", 
                                             "September", "October", "November", "December"};
                    pt = _add(en_months[t->tm_mon], pt, ptlim, modifier);
                }
                continue;
            case 'b':
            case 'h':
                if (is_chinese) {
                    pt = _add(nl_langinfo(ABMON_1 + t->tm_mon), pt, ptlim, modifier);
                } else {
                    const char *en_abmonths[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
                    pt = _add(en_abmonths[t->tm_mon], pt, ptlim, modifier);
                }
                continue;
            case 'c':
                if (is_chinese) {
                    pt = _fmt(nl_langinfo(D_T_FMT), t, pt, ptlim, warnp);
                } else {
                    pt = _fmt("%a %b %e %H:%M:%S %Y", t, pt, ptlim, warnp);
                }
                continue;
            case 'd':
                pt = _conv(t->tm_mday, "%02d", pt, ptlim);
                continue;
            case 'e':
                pt = _conv(t->tm_mday, "%2d", pt, ptlim);
                continue;
            case 'H':
                pt = _conv(t->tm_hour, "%02d", pt, ptlim);
                continue;
            case 'I':
                pt = _conv((t->tm_hour % 12) ? (t->tm_hour % 12) : 12, "%02d", pt, ptlim);
                continue;
            case 'M':
                pt = _conv(t->tm_min, "%02d", pt, ptlim);
                continue;
            case 'm':
                pt = _conv(t->tm_mon + 1, "%02d", pt, ptlim);
                continue;
            case 'p':
                if (is_chinese) {
                    pt = _add((t->tm_hour >= 12) ? nl_langinfo(PM_STR) : nl_langinfo(AM_STR), 
                             pt, ptlim, modifier);
                } else {
                    pt = _add((t->tm_hour >= 12) ? "PM" : "AM", pt, ptlim, modifier);
                }
                continue;
            case 'S':
                pt = _conv(t->tm_sec, "%02d", pt, ptlim);
                continue;
            case 'T':
                pt = _fmt("%H:%M:%S", t, pt, ptlim, warnp);
                continue;
            case 'F':
                pt = _fmt("%Y-%m-%d", t, pt, ptlim, warnp);
                continue;
            case 'x':
                if (is_chinese) {
                    pt = _fmt(nl_langinfo(D_FMT), t, pt, ptlim, warnp);
                } else {
                    pt = _fmt("%m/%d/%y", t, pt, ptlim, warnp);
                }
                continue;
            case 'X':
                if (is_chinese) {
                    pt = _fmt(nl_langinfo(T_FMT), t, pt, ptlim, warnp);
                } else {
                    pt = _fmt("%H:%M:%S", t, pt, ptlim, warnp);
                }
                continue;
            case 'Y':
                pt = _conv(t->tm_year + 1900, "%04d", pt, ptlim);
                continue;
            case 'y':
                pt = _conv((t->tm_year + 1900) % 100, "%02d", pt, ptlim);
                continue;
            case 'Z':
                // 时区名称 - 简化处理
                pt = _add("", pt, ptlim, modifier);
                continue;
            case '%':
                // 字面百分号
                break;
            default:
                // 未知格式符，原样输出
                break;
            }
        }
        
        if (pt == ptlim)
            break;
        *pt++ = *format;
    }
    return pt;
}

// 主 strftime 函数
size_t strftime(char *s, size_t maxsize, const char *format, const struct tm *t) {
    init_original_functions();
    
    // 如果是中文 locale，使用我们的实现
    const char *locale = get_current_locale_name();
    int is_chinese = (strstr(locale, "zh_CN") || strstr(locale, "zh_TW"));
    
    if (is_chinese && format) {
        int warn = 0;
        char *result = _fmt(format, t, s, s + maxsize, &warn);
        if (result == s + maxsize) {
            return 0;
        }
        *result = '\0';
        return result - s;
    }
    
    // 否则使用系统实现
    return original_strftime ? original_strftime(s, maxsize, format, t) : 0;
}