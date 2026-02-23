#!/usr/bin/env bash
# AudioShift PATH-C — Magisk Module Build Script
#
# Builds libaudioshift_effect.so with the Android NDK, then packages
# the complete Magisk module as a flashable ZIP.
#
# Usage:
#   ./build_module.sh [--debug] [--abi arm64-v8a] [--ndk /path/to/ndk]
#
# Output:
#   path_c_magisk/dist/audioshift-v1.0.0.zip   (flashable Magisk module)
#
# Requirements:
#   - Android NDK r25+ (tested with r25c / r26)
#   - CMake 3.22+
#   - zip / unzip
#   - adb (optional, for --deploy)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE_DIR="$WORKSPACE_ROOT/path_c_magisk/module"
NATIVE_DIR="$WORKSPACE_ROOT/path_c_magisk/native"
DIST_DIR="$WORKSPACE_ROOT/path_c_magisk/dist"
BUILD_DIR="$WORKSPACE_ROOT/path_c_magisk/native/build"

MODULE_VERSION="1.0.0"
MODULE_ID="audioshift"
OUTPUT_ZIP="$DIST_DIR/${MODULE_ID}-v${MODULE_VERSION}.zip"

# Defaults
BUILD_TYPE="Release"
ABI="arm64-v8a"
ANDROID_PLATFORM="android-28"
DEPLOY=false

# NDK detection order: env var → common paths
if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
    for candidate in \
        "$HOME/Android/Sdk/ndk/26.3.11579264" \
        "$HOME/Android/Sdk/ndk/25.2.9519653" \
        "/opt/android-ndk" \
        "/usr/local/android-ndk"
    do
        if [ -d "$candidate" ]; then
            ANDROID_NDK_ROOT="$candidate"
            break
        fi
    done
fi

# ─── Argument parsing ────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)    BUILD_TYPE="Debug"          ; shift ;;
        --abi)      ABI="$2"                    ; shift 2 ;;
        --ndk)      ANDROID_NDK_ROOT="$2"       ; shift 2 ;;
        --deploy)   DEPLOY=true                 ; shift ;;
        --help|-h)
            echo "Usage: $0 [--debug] [--abi <abi>] [--ndk <path>] [--deploy]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ─── Pre-flight checks ────────────────────────────────────────────────────────

info()  { echo -e "\033[1;36m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERR ]\033[0m  $*" >&2; exit 1; }

info "AudioShift Module Build — v${MODULE_VERSION}"
info "ABI:        $ABI"
info "Build type: $BUILD_TYPE"

[ -z "${ANDROID_NDK_ROOT:-}" ] && error "ANDROID_NDK_ROOT not set. Pass --ndk or set the environment variable."
[ -d "$ANDROID_NDK_ROOT"    ] || error "NDK not found at: $ANDROID_NDK_ROOT"
command -v cmake >/dev/null    || error "cmake not found in PATH"
command -v zip   >/dev/null    || error "zip not found in PATH"

TOOLCHAIN="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
[ -f "$TOOLCHAIN" ] || error "Toolchain file not found: $TOOLCHAIN"
ok "NDK: $ANDROID_NDK_ROOT"

# ─── Step 1: Build native library ────────────────────────────────────────────

info "Configuring CMake..."
mkdir -p "$BUILD_DIR"
cmake \
    -S "$NATIVE_DIR" \
    -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$MODULE_DIR" \
    2>&1

info "Compiling libaudioshift_effect.so..."
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --parallel "$(nproc 2>/dev/null || echo 4)"

info "Installing .so into module directory..."
cmake --install "$BUILD_DIR" --config "$BUILD_TYPE"

SO_PATH="$MODULE_DIR/system/lib64/soundfx/libaudioshift_effect.so"
[ -f "$SO_PATH" ] || error ".so not found after install: $SO_PATH"

SO_SIZE=$(du -h "$SO_PATH" | cut -f1)
ok "libaudioshift_effect.so built: $SO_SIZE"

# ─── Step 2: Verify exported symbols ─────────────────────────────────────────

info "Verifying exported effect symbols..."
REQUIRED_SYMBOLS=(
    "EffectCreate"
    "EffectRelease"
    "EffectGetDescriptor"
    "EffectQueryNumberEffects"
    "EffectQueryEffect"
)

NM_TOOL=""
for candidate in \
    "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-nm" \
    "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android-nm" \
    "nm"
do
    if command -v "$candidate" >/dev/null 2>&1 || [ -f "$candidate" ]; then
        NM_TOOL="$candidate"
        break
    fi
done

if [ -n "$NM_TOOL" ]; then
    EXPORTED=$("$NM_TOOL" -D --defined-only "$SO_PATH" 2>/dev/null || echo "")
    for sym in "${REQUIRED_SYMBOLS[@]}"; do
        if echo "$EXPORTED" | grep -q " $sym$\| ${sym} "; then
            ok "  $sym ✓"
        else
            warn "  $sym — NOT FOUND in exports (check visibility)"
        fi
    done
else
    warn "nm tool not found — skipping symbol verification"
fi

# ─── Step 3: Package Magisk ZIP ──────────────────────────────────────────────

info "Packaging Magisk module ZIP..."
mkdir -p "$DIST_DIR"
rm -f "$OUTPUT_ZIP"

cd "$MODULE_DIR"
zip -r "$OUTPUT_ZIP" \
    module.prop \
    common/ \
    system/ \
    META-INF/ \
    -x "*.DS_Store" \
    -x "*/.gitkeep"

ZIP_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1)
ok "Module ZIP: $OUTPUT_ZIP ($ZIP_SIZE)"

# ─── Step 4: Verify ZIP structure ────────────────────────────────────────────

info "Verifying ZIP contents..."
REQUIRED_ENTRIES=(
    "module.prop"
    "system/lib64/soundfx/libaudioshift_effect.so"
    "system/vendor/etc/audio_effects_audioshift.xml"
    "META-INF/com/google/android/update-binary"
    "META-INF/com/google/android/updater-script"
    "common/service.sh"
    "common/post-fs-data.sh"
)

for entry in "${REQUIRED_ENTRIES[@]}"; do
    if unzip -l "$OUTPUT_ZIP" | grep -q "$entry"; then
        ok "  $entry ✓"
    else
        warn "  $entry — MISSING from ZIP"
    fi
done

# ─── Step 5: Deploy (optional) ───────────────────────────────────────────────

if $DEPLOY; then
    command -v adb >/dev/null || error "adb not found (required for --deploy)"
    info "Deploying to device via ADB..."
    adb push "$OUTPUT_ZIP" /sdcard/Download/
    ok "Pushed to /sdcard/Download/$(basename "$OUTPUT_ZIP")"
    info "Install via: adb shell magisk --install-module /sdcard/Download/$(basename "$OUTPUT_ZIP")"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  AudioShift Module Build Complete                ║"
echo "║                                                  ║"
echo "║  ZIP: $OUTPUT_ZIP"
echo "║                                                  ║"
echo "║  Flash via:                                      ║"
echo "║    Magisk Manager → Modules → Install from file  ║"
echo "║    adb sideload (TWRP)                           ║"
echo "║    scripts/device_install_magisk.sh              ║"
echo "╚══════════════════════════════════════════════════╝"
