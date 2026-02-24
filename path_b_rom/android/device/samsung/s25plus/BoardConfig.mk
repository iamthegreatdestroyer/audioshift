# BoardConfig.mk — Galaxy S25+ for AudioShift 432Hz Custom ROM
#
# Device  : Samsung Galaxy S25+ (SM-S936B / codename e3q)
# SoC     : Qualcomm Snapdragon 8 Elite (SM8750, platform codename "pineapple")
# AOSP    : Android 16 (android-16.0.0_r1)
#
# Reference: AOSP device/qcom/pineapple/BoardConfig.mk
#            Samsung SM8750 BSP documentation

# ---------------------------------------------------------------------------
# CPU / Architecture
# ---------------------------------------------------------------------------
TARGET_ARCH                    := arm64
TARGET_ARCH_VARIANT            := armv9-a
TARGET_CPU_ABI                 := arm64-v8a
TARGET_CPU_ABI2                :=
TARGET_CPU_VARIANT             := cortex-a520
TARGET_CPU_VARIANT_RUNTIME     := cortex-a520

TARGET_2ND_ARCH                := arm
TARGET_2ND_ARCH_VARIANT        := armv8-2a
TARGET_2ND_CPU_ABI             := armeabi-v7a
TARGET_2ND_CPU_ABI2            := armeabi
TARGET_2ND_CPU_VARIANT         := cortex-a55
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# ---------------------------------------------------------------------------
# Board / Platform
# ---------------------------------------------------------------------------
TARGET_BOARD_PLATFORM          := pineapple
TARGET_BOARD_PLATFORM_GPU      := qcom_adreno_830
TARGET_BOOTLOADER_BOARD_NAME   := e3q               # SM-S936B internal codename

QCOM_BOARD_PLATFORMS           += pineapple

# ---------------------------------------------------------------------------
# Kernel
# ---------------------------------------------------------------------------
BOARD_KERNEL_IMAGE_NAME        := Image
BOARD_RAMDISK_USE_LZ4          := true

TARGET_KERNEL_SOURCE           := kernel/samsung/s25plus
TARGET_KERNEL_CONFIG           := galaxy_s25plus_defconfig
TARGET_KERNEL_CLANG_COMPILE    := true

BOARD_KERNEL_BASE              := 0x00000000
BOARD_KERNEL_PAGESIZE          := 4096
BOARD_KERNEL_OFFSET            := 0x00008000
BOARD_RAMDISK_OFFSET           := 0x02000000
BOARD_KERNEL_TAGS_OFFSET       := 0x01e00000
BOARD_DTB_OFFSET               := 0x01f00000

BOARD_KERNEL_CMDLINE           := \
    console=ttyMSM0,115200n8          \
    earlycon=msm_geni_serial,0x00800000 \
    androidboot.hardware=qcom         \
    androidboot.memcg=1               \
    lpm_levels.sleep_disabled=1       \
    msm_rtb.filter=0x237              \
    service_locator.enable=1          \
    androidboot.usbcontroller=a600000.dwc3

# ---------------------------------------------------------------------------
# Boot image
# ---------------------------------------------------------------------------
BOARD_BOOT_HEADER_VERSION      := 4
BOARD_MKBOOTIMG_ARGS           += --header_version $(BOARD_BOOT_HEADER_VERSION)

# ---------------------------------------------------------------------------
# Partitions
# ---------------------------------------------------------------------------
BOARD_SUPER_PARTITION_SIZE                   := 12884901888  # 12 GiB
BOARD_SUPER_PARTITION_GROUPS                 := qcom_dynamic_partitions
BOARD_QCOM_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor product odm

BOARD_SYSTEMIMAGE_PARTITION_TYPE             := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE           := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE          := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE              := ext4

TARGET_COPY_OUT_VENDOR                       := vendor
TARGET_COPY_OUT_PRODUCT                      := product
TARGET_COPY_OUT_ODM                          := odm

BOARD_FLASH_BLOCK_SIZE                       := 262144  # 256 KiB

# ---------------------------------------------------------------------------
# Recovery
# ---------------------------------------------------------------------------
BOARD_USES_RECOVERY_AS_BOOT    := false
TARGET_RECOVERY_PIXEL_FORMAT   := RGBX_8888

# ---------------------------------------------------------------------------
# Audio — AudioShift 432Hz integration
# ---------------------------------------------------------------------------
BOARD_USES_ALSA_AUDIO                := true
USE_CUSTOM_AUDIO_POLICY              := 1
AUDIO_FEATURE_ENABLED_EXTENDED_COMPRESS_FORMAT := true
AUDIO_FEATURE_ENABLED_GKI_SUPPORT   := true
BOARD_SUPPORTS_SOUND_TRIGGER        := true

# AudioShift-specific flags
TARGET_USES_AUDIOSHIFT_432HZ        := true
AUDIO_FEATURE_ENABLED_AUDIOSHIFT    := true
AUDIOSHIFT_PITCH_CENTS              := -52  # -0.5296 semitones ≈ -52 cents (A440→A432)
AUDIOSHIFT_SAMPLE_RATE              := 48000

# ---------------------------------------------------------------------------
# GPS
# ---------------------------------------------------------------------------
BOARD_VENDOR_QCOM_GPS_LOC_API_HARDWARE := default
GNSS_HIDL_VERSION                      := 2.1

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
BOARD_QTI_CAMERA_32BIT_ONLY_MODE   := false

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------
TARGET_USES_HWC2                   := true
TARGET_USES_GRALLOC1               := true
BOARD_USES_ADRENO                  := true

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------
BOARD_AVB_ENABLE                   := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS   += --flags 3

# ---------------------------------------------------------------------------
# Build leniency (allow missing proprietary blobs during development)
# ---------------------------------------------------------------------------
BUILD_BROKEN_DUP_RULES             := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
ALLOW_MISSING_DEPENDENCIES         := true

# ---------------------------------------------------------------------------
# SELinux
# ---------------------------------------------------------------------------
BOARD_VENDOR_SEPOLICY_DIRS         += device/samsung/s25plus/sepolicy/vendor
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS   += device/samsung/s25plus/sepolicy/private
