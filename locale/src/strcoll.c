#include <string.h>
#include <dlfcn.h>
#include "../include/bits/locale_impl.h"

static int (*original_strcoll)(const char *, const char *) = NULL;

static void init_original_functions(void) {
    if (!original_strcoll) original_strcoll = dlsym(RTLD_NEXT, "strcoll");
}

int strcoll(const char *s1, const char *s2) {
    init_original_functions();
    // 简化实现：直接使用 strcmp
    return original_strcoll ? original_strcoll(s1, s2) : strcmp(s1, s2);
}

size_t strxfrm(char *dest, const char *src, size_t n) {
    // 简化实现
    size_t len = strlen(src);
    if (dest && n > 0) {
        strncpy(dest, src, n-1);
        dest[n-1] = '\0';
    }
    return len;
}