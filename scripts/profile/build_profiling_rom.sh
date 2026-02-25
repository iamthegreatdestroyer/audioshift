#!/usr/bin/env bash
##
# AudioShift — Build with Profiling Instrumentation
# Phase 6 § Sprint 6.1.1
#
# Purpose:
#   Rebuild AudioShift libraries with profiling flags enabled for
#   flame graph generation and performance analysis.
#
# Usage:
#   ./scripts/profile/build_profiling_rom.sh [--skip-rom] [--output PATH]
#
# Profiling Flags:
#   -fprofile-instr-generate       Clang profiling instrumentation
#   -fcoverage-mapping             Coverage-guided profiling
#   -g                             Debug symbols for better trace output
#
# Output:
#   - Profiling-enabled binaries suitable for perf/flame graph capture
#   - Device binaries: build_profile/libaudioshift_*.so
#   - Profiling database: perf.data (generated on device)
#   - Flame graph visualization: flamegraph.svg
#
# Requirements:
#   - AOSP build environment (source build/envsetup.sh)
#   - Android NDK (for arm64-v8a profiling binaries)
#   - perf (Linux tool) + flamegraph.pl (Perl script)
#   - Device connected via adb
#
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

SKIP_ROM="${SKIP_ROM:-0}"
OUTPUT_PATH="${OUTPUT_PATH:-$PROJECT_ROOT}"
DEVICE_SERIAL="${DEVICE_SERIAL:-}"

# Profiling configuration
PROFILE_FLAGS=(
    "-fprofile-instr-generate"
    "-fcoverage-mapping"
    "-g"
    "-O2"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────────────────────────────────

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[⚠]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $*"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-rom)
                SKIP_ROM=1
                shift
                ;;
            --output)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --serial)
                DEVICE_SERIAL="$2"
                shift 2
                ;;
            --help)
                cat << 'EOF'
AudioShift Build with Profiling Instrumentation

Usage: ./scripts/profile/build_profiling_rom.sh [OPTIONS]

Options:
  --skip-rom         Skip full ROM build (only build DSP library)
  --output PATH      Output directory (default: project root)
  --serial SERIAL    Device serial for push (auto-detect if omitted)
  --help             Show this help message

Environment Variables:
  SKIP_ROM           Override --skip-rom
  OUTPUT_PATH        Override --output
  DEVICE_SERIAL      Override --serial

The script builds:
1. AudioShift DSP library with profiling enabled
2. PATH-C Magisk module with profiling enabled
3. Optionally: Full AOSP ROM with profiling

Output files are compatible with:
- perf record -g (Linux performance sampling)
- flamegraph.pl (Brendan Gregg's visualization)

Example:
  ./scripts/profile/build_profiling_rom.sh --skip-rom
  ./scripts/profile/build_profiling_rom.sh --output /tmp/profile_build

EOF
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Check dependencies
# ─────────────────────────────────────────────────────────────────────────────

check_dependencies() {
    header "Step 1: Check dependencies"

    # Check for NDK
    if [ ! -d "$ANDROID_NDK_ROOT" ] && [ ! -d "$NDK_ROOT" ]; then
        warning "Android NDK not found in ANDROID_NDK_ROOT or NDK_ROOT"
        info "Set one of these environment variables to NDK path"
        info "Example: export ANDROID_NDK_ROOT=/opt/android-ndk-r26"
    else
        NDK_ROOT="${ANDROID_NDK_ROOT:-$NDK_ROOT}"
        success "Android NDK found: $NDK_ROOT"
    fi

    # Check for perf tool
    if command -v perf &> /dev/null; then
        success "perf tool available"
    else
        warning "perf not installed (needed for profiling capture)"
        info "Install: sudo apt-get install linux-tools-generic"
    fi

    # Check for flamegraph scripts
    if command -v flamegraph.pl &> /dev/null; then
        success "flamegraph.pl available"
    else
        warning "flamegraph.pl not found (needed for visualization)"
        info "Install from: https://github.com/brendangregg/FlameGraph"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Build DSP library with profiling
# ─────────────────────────────────────────────────────────────────────────────

build_dsp_profiling() {
    header "Step 2: Build DSP library with profiling"

    cd "$PROJECT_ROOT/shared/dsp"

    info "Creating profiling build directory..."
    mkdir -p build_profile

    # Export profiling flags
    export CFLAGS="${PROFILE_FLAGS[*]}"
    export CXXFLAGS="${PROFILE_FLAGS[*]}"
    export LDFLAGS="-fprofile-instr-generate"

    info "Configuring CMake with profiling flags..."
    info "CFLAGS: $CFLAGS"

    cmake -B build_profile \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
        -DANDROID_ABI=arm64-v8a \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=21 \
        -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a

    info "Building with profiling instrumentation..."
    cmake --build build_profile -j$(nproc)

    # Verify output
    if [ -f "build_profile/libaudioshift_dsp.so" ]; then
        success "DSP library built: build_profile/libaudioshift_dsp.so"
        ls -lh build_profile/libaudioshift_dsp.so
    else
        error "DSP library build failed"
        exit 1
    fi

    # Verify debug symbols
    if strings build_profile/libaudioshift_dsp.so | grep -q "__llvm"; then
        success "Profiling symbols present in binary"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Push profiling library to device
# ─────────────────────────────────────────────────────────────────────────────

push_to_device() {
    header "Step 3: Push profiling library to device"

    # Auto-detect device serial if not provided
    if [ -z "$DEVICE_SERIAL" ]; then
        DEVICE_SERIAL=$(adb get-serialno 2>/dev/null || true)
        if [ -z "$DEVICE_SERIAL" ] || [ "$DEVICE_SERIAL" = "unknown" ]; then
            warning "No device found. Skipping push step"
            info "You can manually push later with:"
            info "  adb push $PROJECT_ROOT/shared/dsp/build_profile/libaudioshift_dsp.so /data/local/tmp/"
            return 0
        fi
    fi

    info "Device serial: $DEVICE_SERIAL"

    # Verify device is online
    if [ "$(adb -s "$DEVICE_SERIAL" get-state 2>/dev/null)" != "device" ]; then
        warning "Device not in 'device' state, skipping push"
        return 1
    fi

    info "Pushing profiling library to device..."
    adb -s "$DEVICE_SERIAL" push "$PROJECT_ROOT/shared/dsp/build_profile/libaudioshift_dsp.so" \
        /data/local/tmp/ || {
        error "Failed to push library"
        return 1
    }

    success "Library pushed to device"

    # Create profiling directory
    adb -s "$DEVICE_SERIAL" shell "mkdir -p /data/local/tmp/profiles" || true

    info "Profiling directory created on device"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Build full ROM (if not skipped)
# ─────────────────────────────────────────────────────────────────────────────

build_rom_profiling() {
    if [ "$SKIP_ROM" -eq 1 ]; then
        warning "Skipping full ROM build (--skip-rom)"
        return 0
    fi

    header "Step 4: Build full ROM with profiling"

    warning "Full ROM build with profiling is resource-intensive"
    info "This requires:"
    info "  - AOSP checkout (~200GB)"
    info "  - 4+ hours compilation time"
    info "  - 32GB+ RAM"
    echo ""

    read -p "Proceed with full ROM build? (y/n) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warning "Skipped full ROM build"
        return 0
    fi

    AOSP_ROOT="${AOSP_ROOT:-$HOME/aosp}"

    if [ ! -f "$AOSP_ROOT/build/envsetup.sh" ]; then
        error "AOSP environment not found at $AOSP_ROOT"
        error "Set AOSP_ROOT environment variable"
        return 1
    fi

    cd "$AOSP_ROOT"

    info "Sourcing AOSP build environment..."
    source build/envsetup.sh > /dev/null 2>&1

    info "Configuring lunch target..."
    lunch aosp_arm64-userdebug > /dev/null 2>&1

    # Apply profiling flags
    export CFLAGS="${PROFILE_FLAGS[*]}"
    export CXXFLAGS="${PROFILE_FLAGS[*]}"

    info "Starting ROM build with profiling (this takes 3-4 hours)..."
    m -j$(nproc) 2>&1 | tee build_profiling.log

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        success "ROM build completed"
        ROM_ZIP=$(find "$AOSP_ROOT/out/target/product" -name "*.zip" -type f -printf '%T@ %p\n' | \
            sort -rn | head -1 | cut -d' ' -f2-)
        success "ROM ZIP: $ROM_ZIP"
    else
        error "ROM build failed"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Generate profiling instructions
# ─────────────────────────────────────────────────────────────────────────────

generate_instructions() {
    header "Step 5: Next steps for profiling capture"

    cat << 'EOF'

Your profiling-enabled binaries are ready!

To generate flame graphs:

1. **On Device (adb shell):**
   # Enable performance monitoring
   adb shell "echo 3 > /proc/sys/vm/drop_caches"
   adb shell "su -c 'setenforce 0'"  # (if SELinux enforcing)

   # Play audio and start profiling
   adb shell "su -c 'perf record -e cpu-cycles,cpu-clock -F 99 -p \$(pidof audioserver) -g -o /data/local/tmp/perf.data -- sleep 30'"

2. **On Host (extract and analyze):**
   adb pull /data/local/tmp/perf.data
   perf script perf.data > out.perf
   flamegraph.pl --color=java --hash out.perf > flamegraph.svg

3. **View Results:**
   # Open flamegraph.svg in web browser
   # Hotspots indicate where CPU time is spent
   # SoundTouch WSOLA resampling should dominate (~60-70% of time)

Expected bottlenecks:
- SoundTouch::TDStretch::processSample() (~8-10ms per frame)
- Overlap-add windowing (~2-3ms)
- Float↔int16 conversion (~1-2ms)

Total frame processing: 11-15ms (within latency budget)

To compare against baseline, save this flamegraph to:
research/baselines/flamegraph_baseline.svg

Future optimizations:
- Enable SIMD (SSE/NEON) in SoundTouch
- Parallel processing on multi-core
- Hardware audio DSP if available on device

EOF

    success "Instructions generated"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    check_dependencies
    build_dsp_profiling
    push_to_device || warning "Device push skipped (but library is built)"
    build_rom_profiling || true
    generate_instructions
}

main "$@"
echo ""
success "Profiling build complete!"
