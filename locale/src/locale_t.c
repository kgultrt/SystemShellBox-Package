#include "../include/locale.h"
#include <string.h>
#include <stdlib.h>

// 简单的 locale_t 结构
struct __locale_struct {
    int dummy; // 简化实现
};

// 全局 locale 对象
static struct __locale_struct global_locale_obj = {0};

locale_t duplocale(locale_t locobj) {
    // 简化实现：返回相同的对象
    return locobj;
}

void freelocale(locale_t locobj) {
    // 简化实现：不释放任何东西
}

locale_t newlocale(int category_mask, const char *locale, locale_t base) {
    // 简化实现：返回全局 locale 对象
    return (locale_t)&global_locale_obj;
}

locale_t uselocale(locale_t newloc) {
    // 简化实现：返回当前的 locale
    static struct __locale_struct current_locale = {0};
    return (locale_t)&current_locale;
}