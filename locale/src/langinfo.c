#include "../include/langinfo.h"
#include "../include/bits/locale_impl.h"
#include <string.h>
#include <time.h>
#include <dlfcn.h>

// 保存系统的原始函数指针
static char *(*original_nl_langinfo)(nl_item) = NULL;
static char *(*original_nl_langinfo_l)(nl_item, locale_t) = NULL;

// 初始化系统函数指针（延迟初始化）
static void init_original_functions(void) {
    if (!original_nl_langinfo) {
        original_nl_langinfo = dlsym(RTLD_NEXT, "nl_langinfo");
    }
    if (!original_nl_langinfo_l) {
        original_nl_langinfo_l = dlsym(RTLD_NEXT, "nl_langinfo_l");
    }
}

char *nl_langinfo(nl_item item) {
    const char *locale = get_current_locale_name();
    int is_chinese = (strstr(locale, "zh_CN") || strstr(locale, "zh_TW"));
    
    // 对于某些项目，我们返回自定义的中文内容
    switch (item) {
        case CODESET:
            return "UTF-8";
            
        case D_T_FMT:
            return is_chinese ? "%Y年%m月%d日 %H时%M分%S秒" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "%a %b %e %H:%M:%S %Y");
            
        case D_FMT:
            return is_chinese ? "%Y/%m/%d" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "%m/%d/%y");
            
        case T_FMT:
            return "%H:%M:%S";
            
        case T_FMT_AMPM:
            return "%I:%M:%S %p";
            
        case AM_STR:
            return is_chinese ? "上午" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "AM");
            
        case PM_STR:
            return is_chinese ? "下午" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "PM");
            
        /* Full day names */
        case DAY_1: return is_chinese ? "星期日" : (original_nl_langinfo ? original_nl_langinfo(item) : "Sunday");
        case DAY_2: return is_chinese ? "星期一" : (original_nl_langinfo ? original_nl_langinfo(item) : "Monday");
        case DAY_3: return is_chinese ? "星期二" : (original_nl_langinfo ? original_nl_langinfo(item) : "Tuesday");
        case DAY_4: return is_chinese ? "星期三" : (original_nl_langinfo ? original_nl_langinfo(item) : "Wednesday");
        case DAY_5: return is_chinese ? "星期四" : (original_nl_langinfo ? original_nl_langinfo(item) : "Thursday");
        case DAY_6: return is_chinese ? "星期五" : (original_nl_langinfo ? original_nl_langinfo(item) : "Friday");
        case DAY_7: return is_chinese ? "星期六" : (original_nl_langinfo ? original_nl_langinfo(item) : "Saturday");
        
        /* Abbreviated day names */
        case ABDAY_1: return is_chinese ? "周日" : (original_nl_langinfo ? original_nl_langinfo(item) : "Sun");
        case ABDAY_2: return is_chinese ? "周一" : (original_nl_langinfo ? original_nl_langinfo(item) : "Mon");
        case ABDAY_3: return is_chinese ? "周二" : (original_nl_langinfo ? original_nl_langinfo(item) : "Tue");
        case ABDAY_4: return is_chinese ? "周三" : (original_nl_langinfo ? original_nl_langinfo(item) : "Wed");
        case ABDAY_5: return is_chinese ? "周四" : (original_nl_langinfo ? original_nl_langinfo(item) : "Thu");
        case ABDAY_6: return is_chinese ? "周五" : (original_nl_langinfo ? original_nl_langinfo(item) : "Fri");
        case ABDAY_7: return is_chinese ? "周六" : (original_nl_langinfo ? original_nl_langinfo(item) : "Sat");
        
        /* Full month names */
        case MON_1: return is_chinese ? "一月" : (original_nl_langinfo ? original_nl_langinfo(item) : "January");
        case MON_2: return is_chinese ? "二月" : (original_nl_langinfo ? original_nl_langinfo(item) : "February");
        case MON_3: return is_chinese ? "三月" : (original_nl_langinfo ? original_nl_langinfo(item) : "March");
        case MON_4: return is_chinese ? "四月" : (original_nl_langinfo ? original_nl_langinfo(item) : "April");
        case MON_5: return is_chinese ? "五月" : (original_nl_langinfo ? original_nl_langinfo(item) : "May");
        case MON_6: return is_chinese ? "六月" : (original_nl_langinfo ? original_nl_langinfo(item) : "June");
        case MON_7: return is_chinese ? "七月" : (original_nl_langinfo ? original_nl_langinfo(item) : "July");
        case MON_8: return is_chinese ? "八月" : (original_nl_langinfo ? original_nl_langinfo(item) : "August");
        case MON_9: return is_chinese ? "九月" : (original_nl_langinfo ? original_nl_langinfo(item) : "September");
        case MON_10: return is_chinese ? "十月" : (original_nl_langinfo ? original_nl_langinfo(item) : "October");
        case MON_11: return is_chinese ? "十一月" : (original_nl_langinfo ? original_nl_langinfo(item) : "November");
        case MON_12: return is_chinese ? "十二月" : (original_nl_langinfo ? original_nl_langinfo(item) : "December");
        
        /* Abbreviated month names */
        case ABMON_1: return is_chinese ? " 1月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Jan");
        case ABMON_2: return is_chinese ? " 2月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Feb");
        case ABMON_3: return is_chinese ? " 3月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Mar");
        case ABMON_4: return is_chinese ? " 4月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Apr");
        case ABMON_5: return is_chinese ? " 5月" : (original_nl_langinfo ? original_nl_langinfo(item) : "May");
        case ABMON_6: return is_chinese ? " 6月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Jun");
        case ABMON_7: return is_chinese ? " 7月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Jul");
        case ABMON_8: return is_chinese ? " 8月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Aug");
        case ABMON_9: return is_chinese ? " 9月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Sep");
        case ABMON_10: return is_chinese ? "10月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Oct");
        case ABMON_11: return is_chinese ? "11月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Nov");
        case ABMON_12: return is_chinese ? "12月" : (original_nl_langinfo ? original_nl_langinfo(item) : "Dec");
        
        case RADIXCHAR:
            return ".";
            
        case THOUSEP:
            return is_chinese ? "," : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "");
            
        case YESEXPR:
            return is_chinese ? "^[是是是的对同意]" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "^[yY]");
            
        case NOEXPR:
            return is_chinese ? "^[不否非没拒绝]" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "^[nN]");
            
        case CRNCYSTR:
            return is_chinese ? "￥" : 
                   (original_nl_langinfo ? original_nl_langinfo(item) : "");
            
        default:
            // 对于其他项目，回退到系统实现
            init_original_functions();
            return original_nl_langinfo ? original_nl_langinfo(item) : "";
    }
}

char *nl_langinfo_l(nl_item item, locale_t locale) {
    // 简化处理：直接调用我们的 nl_langinfo
    return nl_langinfo(item);
}