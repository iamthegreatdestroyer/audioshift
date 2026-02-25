#!/usr/bin/env bash
##
# AudioShift — Record Flame Graph on Device
# Phase 6 § Sprint 6.1.1
#
# Purpose:
#   Capture CPU flame graph during audio playback using perf sampling.
#   Records all CPU activity in audioserver process for bottleneck identification.
#
# Usage:
#   ./scripts/profile/record_flamegraph.sh [--duration SEC] [--frequency HZ]
#
# Output:
#   - perf.data — raw profiling data from device
#   - out.perf — converted perf script output
#   - flamegraph.svg — interactive visualization
#
# Sampling Configuration:
#   -F 99              99 Hz sampling frequency (balance: overhead vs detail)
#   -e cpu-cycles,cpu-clock  Sample both cycle and clock events
#   -g                 Record call graph (stack traces)
#
# Requirements:
#   - Device with profiling-enabled binaries
#   - perf installed on device (or push from NDK)
#   - audioserver running with AudioShift effect active
#   - flamegraph.pl available on host
#
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

DEVICE_SERIAL="${DEVICE_SERIAL:-}"
RECORD_DURATION=30
SAMPLE_FREQUENCY=99

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
            --duration)
                RECORD_DURATION="$2"
                shift 2
                ;;
            --frequency)
                SAMPLE_FREQUENCY="$2"
                shift 2
                ;;
            --serial)
                DEVICE_SERIAL="$2"
                shift 2
                ;;
            --help)
                cat << 'EOF'
AudioShift Flame Graph Recording

Usage: ./scripts/profile/record_flamegraph.sh [OPTIONS]

Options:
  --duration SEC      Recording duration in seconds (default: 30)
  --frequency HZ      Sampling frequency (default: 99)
  --serial SERIAL     Device serial (auto-detect if omitted)
  --help              Show this help message

Sampling frequency tradeoff:
  Low (10-30 Hz):   Less overhead, less detail
  Medium (99 Hz):   Balanced (default)
  High (1000+ Hz):  More detail, higher overhead

Output files:
  - perf.data         Raw profiling data (binary)
  - out.perf          Converted text format
  - flamegraph.svg    Interactive visualization

Example:
  ./scripts/profile/record_flamegraph.sh --duration 60
  ./scripts/profile/record_flamegraph.sh --frequency 999 --duration 30

The script:
1. Checks device + audioserver state
2. Clears caches to get clean measurements
3. Records perf data during audio playback
4. Transfers perf.data to host
5. Converts to flamegraph visualization

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
# Step 1: Detect device
# ─────────────────────────────────────────────────────────────────────────────

detect_device() {
    header "Step 1: Detect device"

    if [ -z "$DEVICE_SERIAL" ]; then
        DEVICE_SERIAL=$(adb get-serialno 2>/dev/null || true)
        if [ -z "$DEVICE_SERIAL" ] || [ "$DEVICE_SERIAL" = "unknown" ]; then
            error "No device found"
            exit 1
        fi
    fi

    info "Device serial: $DEVICE_SERIAL"

    if [ "$(adb -s "$DEVICE_SERIAL" get-state 2>/dev/null)" != "device" ]; then
        error "Device not in 'device' state"
        exit 1
    fi

    success "Device connected"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Check audioserver state
# ─────────────────────────────────────────────────────────────────────────────

check_audioserver() {
    header "Step 2: Check audioserver state"

    # Check if audioserver is running
    AUDIOSERVER_PID=$(adb -s "$DEVICE_SERIAL" shell "pidof audioserver 2>/dev/null" | tr -d '\r' || true)

    if [ -z "$AUDIOSERVER_PID" ]; then
        error "audioserver not found on device"
        error "AudioShift effect must be active"
        exit 1
    fi

    success "audioserver PID: $AUDIOSERVER_PID"

    # Check for AudioShift effect
    EFFECT_ACTIVE=$(adb -s "$DEVICE_SERIAL" shell "dumpsys media.audio_flinger | grep -i audioshift" || true)

    if [ -z "$EFFECT_ACTIVE" ]; then
        warning "AudioShift effect not detected in AudioFlinger"
        info "Effect may load dynamically or on first audio play"
    else
        success "AudioShift effect active"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Prepare device for profiling
# ─────────────────────────────────────────────────────────────────────────────

prepare_device() {
    header "Step 3: Prepare device for profiling"

    info "Clearing caches for clean measurement..."
    adb -s "$DEVICE_SERIAL" shell "su -c 'echo 3 > /proc/sys/vm/drop_caches'" 2>/dev/null || {
        warning "Could not clear caches (requires root)"
    }

    info "Checking SELinux status..."
    SELINUX_STATUS=$(adb -s "$DEVICE_SERIAL" shell "getenforce" | tr -d '\r' || echo "unknown")
    info "SELinux: $SELINUX_STATUS"

    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        info "Attempting to set SELinux to permissive..."
        adb -s "$DEVICE_SERIAL" shell "su -c 'setenforce 0'" 2>/dev/null || {
            warning "Could not disable SELinux (may affect profiling accuracy)"
        }
    fi

    success "Device prepared"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Record perf data
# ─────────────────────────────────────────────────────────────────────────────

record_perf_data() {
    header "Step 4: Record performance data"

    info "Recording duration: ${RECORD_DURATION}s at ${SAMPLE_FREQUENCY}Hz"
    echo ""

    # Build perf command
    PERF_CMD="perf record -e cpu-cycles,cpu-clock -F $SAMPLE_FREQUENCY -p $AUDIOSERVER_PID -g -o /data/local/tmp/perf.data -- sleep $RECORD_DURATION"

    info "Executing on device:"
    info "  $PERF_CMD"
    echo ""

    adb -s "$DEVICE_SERIAL" shell "su -c '$PERF_CMD'" 2>&1 | grep -v "^warning\|^$" || {
        warning "perf command may have issues (continuing)"
    }

    # Verify perf.data was created
    sleep 2
    PERF_SIZE=$(adb -s "$DEVICE_SERIAL" shell "ls -lh /data/local/tmp/perf.data 2>/dev/null | awk '{print \$5}'" | tr -d '\r' || true)

    if [ -z "$PERF_SIZE" ] || [ "$PERF_SIZE" = "" ]; then
        warning "perf.data may not have been created"
        info "Attempting to verify with: adb shell ls -l /data/local/tmp/perf.data"
        adb -s "$DEVICE_SERIAL" shell "ls -l /data/local/tmp/perf.data" || {
            error "perf.data not found on device"
            return 1
        }
    else
        success "perf.data recorded: $PERF_SIZE"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Transfer perf.data to host
# ─────────────────────────────────────────────────────────────────────────────

transfer_perf_data() {
    header "Step 5: Transfer perf.data to host"

    info "Pulling perf.data from device..."
    adb -s "$DEVICE_SERIAL" pull /data/local/tmp/perf.data "$PROJECT_ROOT/perf.data" || {
        error "Failed to pull perf.data"
        return 1
    }

    success "perf.data transferred: $(ls -lh $PROJECT_ROOT/perf.data | awk '{print $5}')"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 6: Convert to flamegraph
# ─────────────────────────────────────────────────────────────────────────────

convert_to_flamegraph() {
    header "Step 6: Convert to flame graph"

    cd "$PROJECT_ROOT"

    info "Converting perf.data to script format..."
    if ! perf script perf.data > out.perf 2>/dev/null; then
        error "Failed to convert perf data"
        error "Ensure 'perf' tool matches device kernel version"
        return 1
    fi

    success "Converted: out.perf"

    # Check if flamegraph.pl is available
    if ! command -v flamegraph.pl &> /dev/null; then
        warning "flamegraph.pl not found in PATH"
        info "Manual conversion:"
        info "  1. Clone: https://github.com/brendangregg/FlameGraph"
        info "  2. Run: /path/to/flamegraph.pl --color=java --hash out.perf > flamegraph.svg"
        return 0
    fi

    info "Generating flame graph visualization..."
    flamegraph.pl --color=java --hash out.perf > flamegraph.svg

    success "Flame graph generated: flamegraph.svg"
    ls -lh flamegraph.svg
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 7: Analyze results
# ─────────────────────────────────────────────────────────────────────────────

analyze_results() {
    header "Step 7: Analysis tips"

    cat << 'EOF'

Flame Graph Interpretation:

The Y-axis shows function call stacks (deeper = more nested calls)
The X-axis shows percentage of total CPU time in that function
The height indicates time spent in that function

Expected AudioShift bottleneck chain:
  audioserver → AudioFlinger::mix_16()
    → AudioShift432Effect::process()
      → AudioPipeline::processInPlace()
        → Audio432HzConverter::process()
          → SoundTouch::putSamples()
            → TDStretch::processSample() ← [HOTSPOT ~8-10ms]

Optimization opportunities (if hotspots found elsewhere):
1. Verify SIMD enabled in SoundTouch
2. Check for allocations in inner loop
3. Profile memory bandwidth (cache misses)
4. Consider NEON intrinsics for float↔int conversion

To compare across builds:
  1. Save this SVG as: research/baselines/flamegraph_$(date +%Y%m%d).svg
  2. Build next version with optimizations
  3. Record new flamegraph
  4. Compare with: diff -u baseline.svg new.svg

Monitor metrics:
- Total CPU time: should be 11-15ms per 20ms audio frame (55-75%)
- Frame rate stability: consistent sampling rate indicates no dropouts
- Lock contention: look for repeated lock/unlock patterns

EOF

    success "Analysis tips printed above"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    detect_device
    check_audioserver
    prepare_device
    record_perf_data || exit 1
    transfer_perf_data || exit 1
    convert_to_flamegraph
    analyze_results
}

main "$@"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} Flame graph generation complete!"
echo -e "${GREEN}║${NC} Open in browser: $(pwd)/flamegraph.svg"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
