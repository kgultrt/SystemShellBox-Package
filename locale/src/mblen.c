#include <stdlib.h>
#include <dlfcn.h>
#include "../include/bits/locale_impl.h"

// 保存系统原始函数指针
static int (*original_mblen)(const char *, size_t) = NULL;
static int (*original_mbtowc)(wchar_t *, const char *, size_t) = NULL;
static int (*original_wctomb)(char *, wchar_t) = NULL;
static size_t (*original_mbstowcs)(wchar_t *, const char *, size_t) = NULL;
static size_t (*original_wcstombs)(char *, const wchar_t *, size_t) = NULL;

static void init_original_functions(void) {
    if (!original_mblen) original_mblen = dlsym(RTLD_NEXT, "mblen");
    if (!original_mbtowc) original_mbtowc = dlsym(RTLD_NEXT, "mbtowc");
    if (!original_wctomb) original_wctomb = dlsym(RTLD_NEXT, "wctomb");
    if (!original_mbstowcs) original_mbstowcs = dlsym(RTLD_NEXT, "mbstowcs");
    if (!original_wcstombs) original_wcstombs = dlsym(RTLD_NEXT, "wcstombs");
}

// 简单的多字节函数实现
int mblen(const char *s, size_t n) {
    init_original_functions();
    // UTF-8 多字节字符长度检测
    if (s == NULL) return 0;
    if (n == 0) return 0;
    
    unsigned char c = (unsigned char)*s;
    if (c < 0x80) return 1;
    if ((c & 0xE0) == 0xC0) return 2;
    if ((c & 0xF0) == 0xE0) return 3;
    if ((c & 0xF8) == 0xF0) return 4;
    return -1;
}

int mbtowc(wchar_t *pwc, const char *s, size_t n) {
    init_original_functions();
    // 简化实现
    if (s == NULL) return 0;
    if (n == 0) return 0;
    if (pwc) *pwc = (wchar_t)*s;
    return 1;
}

int wctomb(char *s, wchar_t wc) {
    init_original_functions();
    if (s == NULL) return 0;
    *s = (char)wc;
    return 1;
}

size_t mbstowcs(wchar_t *pwcs, const char *s, size_t n) {
    init_original_functions();
    size_t i;
    for (i = 0; i < n && s[i] != '\0'; i++) {
        if (pwcs) pwcs[i] = (wchar_t)s[i];
    }
    if (pwcs && i < n) pwcs[i] = 0;
    return i;
}

size_t wcstombs(char *s, const wchar_t *pwcs, size_t n) {
    init_original_functions();
    size_t i;
    for (i = 0; i < n && pwcs[i] != 0; i++) {
        if (s) s[i] = (char)pwcs[i];
    }
    if (s && i < n) s[i] = '\0';
    return i;
}