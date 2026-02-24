# Android.mk — Galaxy S25+ device tree for AudioShift 432Hz Custom ROM
#
# Device  : Samsung Galaxy S25+ (SM-S936B / codename e3q)
# SoC     : Qualcomm Snapdragon 8 Elite (SM8750)
# AOSP    : Android 16 (android-16.0.0_r1)
#
# This makefile:
#   1. Copies AudioShift system properties into the build.
#   2. Copies audio policy XML into the vendor partition.
#   3. Recursively includes sub-directory makefiles.
#
# Included by AOSP build system when lunch target is "aosp_s25plus-*".

LOCAL_PATH := $(call my-dir)

# ---------------------------------------------------------------------------
# System-property file — sets audioshift.* props at runtime
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audioshift.prop:$(TARGET_COPY_OUT_SYSTEM)/etc/audioshift.prop

# ---------------------------------------------------------------------------
# Audio policy configuration
# Placed in vendor/etc/audio/ so AudioFlinger / APM can discover it.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/audio_policy_configuration.xml

# ---------------------------------------------------------------------------
# Mixer paths — ALSA codec route configuration for WCD938x
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../device_configs/mixer_paths.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/mixer_paths.xml

# ---------------------------------------------------------------------------
# AudioShift product makefile (packages, overlays, properties)
# ---------------------------------------------------------------------------
$(call inherit-product, $(LOCAL_PATH)/audioshift_product.mk)

# ---------------------------------------------------------------------------
# Sub-directory makefiles (none currently, reserved for future sub-modules)
# ---------------------------------------------------------------------------
include $(call all-makefiles-under,$(LOCAL_PATH))
