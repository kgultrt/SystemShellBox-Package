#include <stdint.h>
#include <stdio.h>
#include <pthread.h>  // 添加线程支持

#ifndef LOG_PRI
#define LOG_PRI(priority, tag, ...) \
  __android_log_print(priority, tag, __VA_ARGS__)
#endif

#ifndef LOG_EVENT_STRING
#define LOG_EVENT_STRING(_tag, _value) \
  (void)__android_log_buf_write(LOG_ID_EVENTS, ANDROID_LOG_DEFAULT, _tag, _value);
#endif

#define fgets_unlocked(buf, size, fp) fgets(buf, size, fp)

#define AID_USER_OFFSET 100000 /* offset for uid ranges for each user */
#define AID_APP_START 10000 /* first app user */
#define AID_SDK_SANDBOX_PROCESS_START 20000 /* start of uids allocated to sdk sandbox processes */
#define AID_ISOLATED_START 90000 /* start of uids for fully isolated sandboxed processes */

/* 定义 fsetlocking 相关的常量 */
#ifndef FSETLOCKING_BYCALLER
#define FSETLOCKING_BYCALLER 0
#define FSETLOCKING_INTERNAL 1
#define FSETLOCKING_QUERY 2
#endif

/* __fsetlocking 的实现 */
static inline int __fsetlocking(FILE *stream, int type) {
    // 在 Android 上，我们实现一个简单的版本
    // 返回当前的锁定类型
    (void)stream;  // 避免未使用参数警告
    
    switch (type) {
        case FSETLOCKING_QUERY:
            // Android 的 stdio 是线程安全的，所以返回 INTERNAL
            return FSETLOCKING_INTERNAL;
        case FSETLOCKING_BYCALLER:
            // 在 Android 上，我们通常让标准库管理锁定
            // 这里简单返回成功
            return 0;
        case FSETLOCKING_INTERNAL:
            // 设置回内部锁定，同样返回成功
            return 0;
        default:
            return -1;  // 无效的类型
    }
}

/* 线程安全的 stdio 函数（如果需要的话） */
#define flockfile(fp) pthread_mutex_lock(&((fp)->_lock))
#define funlockfile(fp) pthread_mutex_unlock(&((fp)->_lock))
#define getc_unlocked(fp) getc(fp)
#define putc_unlocked(c, fp) putc(c, fp)

/* 其他可能需要定义的 stdio 相关函数 */
#ifndef fflush_unlocked
#define fflush_unlocked(stream) fflush(stream)
#endif

#ifndef fputc_unlocked
#define fputc_unlocked(c, stream) fputc(c, stream)
#endif

#ifndef fputs_unlocked
#define fputs_unlocked(s, stream) fputs(s, stream)
#endif