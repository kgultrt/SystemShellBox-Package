CFLAGS = -fPIC -O2 -Iinclude -std=c99 -Wall
LDFLAGS = -shared -Wl,-soname,liblocal.so.1 -ldl
PREFIX = /data/data/com.termux/files/usr

SRCS = src/locale_core.c \
    src/langinfo.c \
    src/strftime.c \
    src/mblen.c \
    src/strcoll.c \
    src/timezone.c \
    src/locale_t.c
OBJS = $(SRCS:.c=.o)

all: liblocal.so.1.0

liblocal.so.1.0: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^
	ln -sf liblocal.so.1.0 liblocal.so.1
	ln -sf liblocal.so.1.0 liblocal.so

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

install: liblocal.so.1.0
	cp liblocal.so.1.0 $(PREFIX)/lib/
	cp include/locale.h $(PREFIX)/include/
	cp include/langinfo.h $(PREFIX)/include/
	mkdir -p $(PREFIX)/include/bits
	cp include/bits/locale_impl.h $(PREFIX)/include/bits/
	cd $(PREFIX)/lib && ln -sf liblocal.so.1.0 liblocal.so.1
	cd $(PREFIX)/lib && ln -sf liblocal.so.1.0 liblocal.so

clean:
	rm -f $(OBJS) liblocal.so* test_basic

test: all
	$(CC) -L. tests/test_basic.c -llocal -o test_basic
	LD_LIBRARY_PATH=. ./test_basic

test-date: all
	$(CC) -L. tests/test_date.c -llocal -o test_date
	LD_LIBRARY_PATH=. ./test_date

test-ctype: all
	$(CC) -L. tests/test_ctype.c -llocal -o test_ctype
	LD_LIBRARY_PATH=. ./test_ctype

.PHONY: all install clean test test-date test-ctype