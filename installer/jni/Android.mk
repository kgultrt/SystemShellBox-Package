LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE    := installer
LOCAL_SRC_FILES := main.c
LOCAL_CFLAGS    := -Wall
LOCAL_LDLIBS    := -llog -landroid

include $(BUILD_EXECUTABLE)