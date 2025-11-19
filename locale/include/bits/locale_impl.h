#ifndef _LOCALE_IMPL_H
#define _LOCALE_IMPL_H

#include "../locale.h"  // 这会包含 xlocale.h

/* Internal locale structure */
struct __locale_struct {
    struct __locale_data *cat[6];
};

/* Internal functions */
const char *get_current_locale_name(void);
void apply_C_locale(int category);
void apply_zh_CN_UTF8_locale(int category);
void apply_zh_TW_UTF8_locale(int category);

extern struct __locale_data __C_ctype_locale;
extern struct __locale_data __C_numeric_locale;
extern struct __locale_data __C_time_locale;
extern struct __locale_data __C_collate_locale;
extern struct __locale_data __C_monetary_locale;
extern struct __locale_data __C_messages_locale;

#endif /* _LOCALE_IMPL_H */