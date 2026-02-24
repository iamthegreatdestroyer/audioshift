# audioshift_product.mk — AudioShift 432Hz product makefile
#
# Device  : Samsung Galaxy S25+ (SM-S936B)
# AOSP    : Android 16 (android-16.0.0_r1)
# Path    : PATH-B (Custom ROM / AOSP integration)
#
# Included by Android.mk via:
#   $(call inherit-product, $(LOCAL_PATH)/audioshift_product.mk)
#
# Adds AudioShift packages, properties, overlays, and configs to the product.

# ---------------------------------------------------------------------------
# AudioShift native libraries and executables
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    libaudioshift432            \
    libaudioshift_dsp           \
    audioshift_dspd             \
    audioshift.s25plus

# ---------------------------------------------------------------------------
# AudioShift HAL
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.audio@7.0-impl         \
    android.hardware.audio.effect@7.0-impl  \
    android.hardware.audio.service          \
    audio.primary.pineapple                 \
    audio.r_submix.default                  \
    audio.usb.default                       \
    libaudiohal                             \
    libaudiohal_deathhandler

# ---------------------------------------------------------------------------
# AudioShift apps / settings
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    AudioShiftSettings      \
    AudioShiftQuickToggle

# ---------------------------------------------------------------------------
# AudioShift audio effects configuration
# (runtime XML consumed by AudioFlinger effect engine)
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    hardware/audioshift/config/audio_effects_audioshift.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/audio_effects_audioshift.xml

# ---------------------------------------------------------------------------
# System properties — read at boot by AudioShift daemon
# ---------------------------------------------------------------------------
PRODUCT_SYSTEM_PROPERTIES += \
    audioshift.enabled=1                    \
    audioshift.pitch_semitones=-0.5296      \
    audioshift.pitch_cents=-52              \
    audioshift.sample_rate=48000            \
    audioshift.buffer_size_frames=8192      \
    audioshift.version=2.0.0               \
    audioshift.path=B                       \
    audioshift.engine=soundtouch            \
    audioshift.latency_limit_ms=10

# Vendor properties (visible to HAL)
PRODUCT_VENDOR_PROPERTIES += \
    vendor.audioshift.enabled=1             \
    vendor.audioshift.pitch_cents=-52       \
    vendor.audioshift.sample_rate=48000

# ---------------------------------------------------------------------------
# Feature flags
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.output.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.output.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml

# ---------------------------------------------------------------------------
# Soong namespace for device tree
# ---------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    device/samsung/s25plus \
    hardware/audioshift

# ---------------------------------------------------------------------------
# Overlays — Resource overlay for AudioShift UI theming
# ---------------------------------------------------------------------------
PRODUCT_PACKAGE_OVERLAYS += \
    device/samsung/s25plus/overlay

# ---------------------------------------------------------------------------
# Enforce VNDK for vendor libraries
# ---------------------------------------------------------------------------
PRODUCT_FULL_TREBLE_OVERRIDE := true
PRODUCT_VENDOR_MOVE_ENABLED  := true
