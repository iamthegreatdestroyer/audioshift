#!/usr/bin/env bash
# AudioShift PATH-B — Custom ROM Build Script
#
# Syncs AOSP, applies the AudioFlinger 432 Hz patch, builds the ROM,
# and packages it for flashing on Samsung Galaxy S25+.
#
# Usage:
#   ./build_rom.sh [--sync] [--jobs N] [--lunch TARGET]
#
# Examples:
#   ./build_rom.sh --sync --jobs 16
#   ./build_rom.sh --lunch lineage_f2q-userdebug
#
# Requirements:
#   - AOSP build environment (Ubuntu 20.04+ / 22.04)
#   - ~300 GB free disk space
#   - 64 GB RAM recommended (32 GB min with swap)
#   - repo, git, python3, make

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PATH_B_DIR="$WORKSPACE_ROOT/path_b_rom"
PATCHES_DIR="$PATH_B_DIR/frameworks/av/services"

# AOSP source tree — must be set via env or --aosp flag
AOSP_ROOT="${AOSP_ROOT:-$HOME/aosp}"

# Samsung Galaxy S25+ device codename
# Note: S25+ uses "gts8" series internally; community codename may vary
DEVICE_CODENAME="${DEVICE_CODENAME:-s25plus}"
LUNCH_TARGET="${LUNCH_TARGET:-aosp_arm64-userdebug}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc 2>/dev/null || echo 8)}"

# AOSP branch — Android 14 QPR3 / 15 base
AOSP_BRANCH="android-14.0.0_r61"
AOSP_MANIFEST_URL="https://android.googlesource.com/platform/manifest"

# AudioFlinger patch target path
AUDIOFLINGER_TARGET="frameworks/av/services/audioflinger"

SYNC=false

# ─── Argument parsing ────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sync)         SYNC=true               ; shift ;;
        --jobs|-j)      BUILD_JOBS="$2"         ; shift 2 ;;
        --lunch)        LUNCH_TARGET="$2"       ; shift 2 ;;
        --aosp)         AOSP_ROOT="$2"          ; shift 2 ;;
        --device)       DEVICE_CODENAME="$2"    ; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--sync] [--jobs N] [--lunch TARGET] [--aosp PATH]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ─── Logging ─────────────────────────────────────────────────────────────────

info()  { echo -e "\033[1;36m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERR ]\033[0m  $*" >&2; exit 1; }

info "AudioShift PATH-B ROM Build"
info "AOSP root:    $AOSP_ROOT"
info "Lunch target: $LUNCH_TARGET"
info "Build jobs:   $BUILD_JOBS"

# ─── Step 1: Repo sync (optional) ────────────────────────────────────────────

if $SYNC; then
    info "Initializing AOSP repo..."
    mkdir -p "$AOSP_ROOT"
    cd "$AOSP_ROOT"

    if [ ! -d ".repo" ]; then
        repo init \
            -u "$AOSP_MANIFEST_URL" \
            -b "$AOSP_BRANCH" \
            --depth=1 \
            --partial-clone
    fi

    info "Syncing AOSP ($AOSP_BRANCH) — this takes 45-90 min on first run..."
    repo sync \
        --current-branch \
        --no-tags \
        --force-sync \
        --jobs="$BUILD_JOBS" \
        -q

    ok "Repo sync complete"
else
    info "Skipping repo sync (pass --sync to fetch sources)"
    [ -d "$AOSP_ROOT" ] || error "AOSP root not found: $AOSP_ROOT  (run with --sync first)"
fi

# ─── Step 2: Apply AudioFlinger patch ────────────────────────────────────────

info "Applying AudioFlinger 432 Hz patch..."

PATCH_TARGET_DIR="$AOSP_ROOT/$AUDIOFLINGER_TARGET"
[ -d "$PATCH_TARGET_DIR" ] || error "AudioFlinger source not found: $PATCH_TARGET_DIR"

# Generate the patch from our source investigation
PATCH_FILE="$PATH_B_DIR/frameworks/av/services/audioflinger_432hz.patch"

if [ ! -f "$PATCH_FILE" ]; then
    info "Generating patch from PATH-B investigation..."
    cat > "$PATCH_FILE" << 'PATCH'
diff --git a/Threads.cpp b/Threads.cpp
index 1234567..abcdef0 100644
--- a/Threads.cpp
+++ b/Threads.cpp
@@ -1,6 +1,8 @@
 // AudioFlinger Threads — 432 Hz pitch shift integration
 // AudioShift PATH-B: Direct AudioFlinger modification

+#include "audio_432hz.h"   // AudioShift 432 Hz DSP hook
+
 namespace android {

 // ... ThreadBase constructor ...
@@ -100,6 +102,14 @@ void MixerThread::threadLoop_mix() {
     }
+
+    // AudioShift: Post-mix 432 Hz pitch shift
+    // Applied after all track mixing, before playback
+    if (mAudioShift432HzEnabled) {
+        mAudioShift432Hz.process(
+            static_cast<int16_t*>(mMixBuffer),
+            mNormalFrameCount
+        );
+    }
 }

PATCH
    warn "Patch file generated as template — manual refinement required for production"
fi

cd "$PATCH_TARGET_DIR"
if git apply --check "$PATCH_FILE" 2>/dev/null; then
    git apply "$PATCH_FILE"
    ok "AudioFlinger patch applied cleanly"
else
    warn "Patch does not apply cleanly — may already be applied, or needs manual merge"
    warn "Patch file: $PATCH_FILE"
    warn "Target:     $PATCH_TARGET_DIR"
fi

# Copy our DSP header to AudioFlinger source
SHARED_HEADER="$WORKSPACE_ROOT/shared/dsp/include/audio_432hz.h"
if [ -f "$SHARED_HEADER" ]; then
    cp "$SHARED_HEADER" "$PATCH_TARGET_DIR/"
    ok "Copied audio_432hz.h to AudioFlinger source"
fi

# ─── Step 3: Copy device configuration ───────────────────────────────────────

info "Setting up device configuration..."

DEVICE_CONFIG_SRC="$PATH_B_DIR/device_configs"
DEVICE_CONFIG_DST_BASE="$AOSP_ROOT/device/samsung"

if [ -d "$DEVICE_CONFIG_SRC" ]; then
    mkdir -p "$DEVICE_CONFIG_DST_BASE/$DEVICE_CODENAME"
    cp -r "$DEVICE_CONFIG_SRC/." "$DEVICE_CONFIG_DST_BASE/$DEVICE_CODENAME/"
    ok "Device configs deployed to $DEVICE_CONFIG_DST_BASE/$DEVICE_CODENAME/"
else
    warn "Device configs not found at $DEVICE_CONFIG_SRC — using default AOSP config"
fi

# ─── Step 4: Set up build environment ────────────────────────────────────────

info "Setting up build environment..."
cd "$AOSP_ROOT"

# shellcheck source=/dev/null
source build/envsetup.sh

# Validate lunch target before invoking
if lunch "$LUNCH_TARGET" 2>&1; then
    ok "Lunch target: $LUNCH_TARGET"
else
    error "Lunch target not found: $LUNCH_TARGET"
fi

# ─── Step 5: Build ────────────────────────────────────────────────────────────

info "Building ROM (jobs=$BUILD_JOBS) — ETA: 2-4 hours..."
START_TS=$(date +%s)

make -j"$BUILD_JOBS" \
    2>&1 | tee "$WORKSPACE_ROOT/path_b_rom/build_scripts/build_$(date +%Y%m%d_%H%M%S).log"

END_TS=$(date +%s)
ELAPSED=$(( END_TS - START_TS ))
ok "Build completed in $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"

# ─── Step 6: Locate output images ────────────────────────────────────────────

OUT_DIR="$AOSP_ROOT/out/target/product/$DEVICE_CODENAME"
info "Locating flashable images in $OUT_DIR..."

for img in boot.img system.img vendor.img product.img; do
    if [ -f "$OUT_DIR/$img" ]; then
        SIZE=$(du -h "$OUT_DIR/$img" | cut -f1)
        ok "  $img ($SIZE)"
    else
        warn "  $img — not found"
    fi
done

# Check for OTA package
OTA_ZIP=$(find "$OUT_DIR" -name "*.zip" -newer "$AOSP_ROOT/Makefile" 2>/dev/null | head -1)
if [ -n "$OTA_ZIP" ]; then
    ok "OTA package: $OTA_ZIP"
fi

# ─── Step 7: Flash instructions ──────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AudioShift PATH-B Build Complete                           ║"
echo "║                                                              ║"
echo "║  Flash to Galaxy S25+ (ONE UI / stock bootloader):          ║"
echo "║                                                              ║"
echo "║  Option A — fastboot (unlocked bootloader)                  ║"
echo "║    adb reboot bootloader                                     ║"
echo "║    fastboot flash boot   $OUT_DIR/boot.img      ║"
echo "║    fastboot flash system $OUT_DIR/system.img    ║"
echo "║    fastboot reboot                                           ║"
echo "║                                                              ║"
echo "║  Option B — Heimdall (Odin-compatible, Windows/Linux)       ║"
echo "║    Download Odin 3.14.x on Windows                          ║"
echo "║    Boot into Download Mode (Vol Down + Power)                ║"
echo "║    Flash boot.tar.md5 via Odin AP slot                      ║"
echo "║                                                              ║"
echo "║  Option C — TWRP ADB Sideload (with TWRP installed)        ║"
echo "║    adb reboot recovery                                       ║"
echo "║    adb sideload $OTA_ZIP                        ║"
echo "║                                                              ║"
echo "║  NOTES:                                                      ║"
echo "║    - Unlocking bootloader WIPES all data (Samsung)          ║"
echo "║    - Knox fuse blown permanently after unlock                ║"
echo "║    - Verify 432 Hz shift with: tools/verify_432hz.sh        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
