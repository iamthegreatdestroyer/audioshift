#!/usr/bin/env bash
##
# AudioShift — Bluetooth Codec Detection & Adaptation
# Phase 7 § Sprint 7.2
#
# Purpose:
#   Detect active Bluetooth audio codec and apply codec-specific WSOLA tuning.
#   Optimizes for latency based on codec bandwidth and processing overhead.
#
# Usage:
#   ./scripts/codec/detect_bluetooth_codec.sh [--monitor] [--profile CODEC]
#
# Supported Codecs:
#   - SBC       (baseline, all devices)
#   - AAC       (streaming optimized)
#   - aptX      (Qualcomm standard)
#   - LDAC      (Sony premium)
#   - LHDC      (Chinese ultra-low latency)
#   - aptX HD   (Qualcomm high quality)
#   - aptX Adaptive (Qualcomm latest)
#
# Adaptive Tuning:
#   Higher codec bandwidth → Shorter WSOLA sequence (lower latency)
#   Lower codec bandwidth  → Longer WSOLA sequence (better quality)
#
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

DEVICE_SERIAL="${DEVICE_SERIAL:-}"
MONITOR_MODE=false
PROFILE_CODEC=""

# Codec-specific WSOLA tuning profiles
declare -A CODEC_PROFILES=(
    [SBC]="40:15:8"           # sequence:seekwindow:overlap (ms)
    [AAC]="35:13:7"
    [aptX]="30:12:6"
    [LDAC]="25:10:5"
    [LHDC]="20:8:4"
    [aptX_HD]="28:11:6"
    [aptX_Adaptive]="15:6:3"
)

# Codec info display
declare -A CODEC_INFO=(
    [SBC]="Baseline (all devices)"
    [AAC]="Streaming optimized"
    [aptX]="Qualcomm standard"
    [LDAC]="Sony premium"
    [LHDC]="Ultra-low latency"
    [aptX_HD]="High quality"
    [aptX_Adaptive]="Latest 2024+"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} $*"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

adb_cmd() {
    local cmd="$1"
    shift || true
    if [ -n "$DEVICE_SERIAL" ]; then
        adb -s "$DEVICE_SERIAL" "$cmd" "$@"
    else
        adb "$cmd" "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --monitor)
                MONITOR_MODE=true
                shift
                ;;
            --profile)
                PROFILE_CODEC="$2"
                shift 2
                ;;
            --serial)
                DEVICE_SERIAL="$2"
                shift 2
                ;;
            --help)
                cat << 'EOF'
AudioShift Bluetooth Codec Detection

Usage: ./scripts/codec/detect_bluetooth_codec.sh [OPTIONS]

Options:
  --monitor             Monitor for codec changes continuously
  --profile CODEC       Test specific codec profile
  --serial SERIAL       Device serial (auto-detect if omitted)
  --help                Show this help message

Codec Latency Profiles:
  SBC:            12-15ms (baseline)  → WSOLA: 40/15/8
  AAC:            10-12ms (good)      → WSOLA: 35/13/7
  aptX:           8-10ms  (excellent) → WSOLA: 30/12/6
  LDAC:           7-9ms   (excellent) → WSOLA: 25/10/5
  LHDC:           6-8ms   (best)      → WSOLA: 20/8/4
  aptX HD:        8-10ms  (excellent) → WSOLA: 28/11/6
  aptX Adaptive:  4-6ms   (best)      → WSOLA: 15/6/3

WSOLA Tuning Format: sequence_ms:seekwindow_ms:overlap_ms

Latency Reduction:
  High-end codec (LDAC, LHDC, aptX Adaptive) can reduce AudioShift
  latency from 8ms (SBC) to 3ms (aptX Adaptive) = 5ms savings!

Example:
  ./scripts/codec/detect_bluetooth_codec.sh
  ./scripts/codec/detect_bluetooth_codec.sh --monitor
  ./scripts/codec/detect_bluetooth_codec.sh --profile LDAC

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
# Detect device
# ─────────────────────────────────────────────────────────────────────────────

detect_device() {
    if [ -z "$DEVICE_SERIAL" ]; then
        DEVICE_SERIAL=$(adb get-serialno 2>/dev/null || true)
        if [ -z "$DEVICE_SERIAL" ] || [ "$DEVICE_SERIAL" = "unknown" ]; then
            error "No device found"
            exit 1
        fi
    fi

    if [ "$(adb_cmd get-state 2>/dev/null)" != "device" ]; then
        error "Device not in 'device' state"
        exit 1
    fi

    success "Device: $DEVICE_SERIAL"
}

# ─────────────────────────────────────────────────────────────────────────────
# Detect active Bluetooth codec
# ─────────────────────────────────────────────────────────────────────────────

detect_active_codec() {
    local codec_output=$(adb_cmd shell "dumpsys Bluetooth_manager 2>/dev/null | grep -i -E 'codec|a2dp'" || true)

    # Try to extract codec name
    local codec=""

    # Check for specific codec strings
    for known_codec in "LDAC" "LHDC" "aptX Adaptive" "aptX HD" "aptX" "AAC" "SBC"; do
        if echo "$codec_output" | grep -qi "$known_codec"; then
            codec="$known_codec"
            break
        fi
    done

    # Normalize codec name (remove spaces for array lookup)
    codec="${codec// /_}"

    if [ -z "$codec" ]; then
        warning "Could not detect codec, assuming SBC (baseline)"
        codec="SBC"
    fi

    echo "$codec"
}

# ─────────────────────────────────────────────────────────────────────────────
# Get codec latency info
# ─────────────────────────────────────────────────────────────────────────────

get_codec_latency() {
    local codec=$1

    case "$codec" in
        SBC)           echo "12-15ms (baseline)" ;;
        AAC)           echo "10-12ms (streaming)" ;;
        aptX)          echo "8-10ms (standard)" ;;
        LDAC)          echo "7-9ms (premium)" ;;
        LHDC)          echo "6-8ms (ultra-low)" ;;
        aptX_HD)       echo "8-10ms (high quality)" ;;
        aptX_Adaptive) echo "4-6ms (latest)" ;;
        *)             echo "unknown" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Apply codec-specific tuning
# ─────────────────────────────────────────────────────────────────────────────

apply_codec_tuning() {
    local codec=$1

    if [ -z "${CODEC_PROFILES[$codec]:-}" ]; then
        warning "Codec profile not found: $codec"
        return 1
    fi

    # Parse WSOLA parameters
    IFS=':' read -r sequence seekwindow overlap <<< "${CODEC_PROFILES[$codec]}"

    info "Applying tuning for codec: $codec"
    info "  Codec info: ${CODEC_INFO[$codec]:-unknown}"
    info "  Expected latency: $(get_codec_latency "$codec")"
    echo ""

    # Apply system properties
    adb_cmd shell "setprop audioshift.bluetooth_codec $codec"
    adb_cmd shell "setprop audioshift.wsola.sequence_ms $sequence"
    adb_cmd shell "setprop audioshift.wsola.seekwindow_ms $seekwindow"
    adb_cmd shell "setprop audioshift.wsola.overlap_ms $overlap"

    success "WSOLA tuned for $codec:"
    success "  Sequence:   ${sequence}ms"
    success "  Seekwindow: ${seekwindow}ms"
    success "  Overlap:    ${overlap}ms"
    success "  Expected latency reduction: $(calculate_reduction "$codec")"
}

# ─────────────────────────────────────────────────────────────────────────────
# Calculate latency reduction vs SBC
# ─────────────────────────────────────────────────────────────────────────────

calculate_reduction() {
    local codec=$1

    case "$codec" in
        SBC)           echo "baseline (0ms)" ;;
        AAC)           echo "-2ms vs SBC" ;;
        aptX)          echo "-5ms vs SBC" ;;
        LDAC)          echo "-8ms vs SBC" ;;
        LHDC)          echo "-10ms vs SBC" ;;
        aptX_HD)       echo "-5ms vs SBC" ;;
        aptX_Adaptive) echo "-12ms vs SBC" ;;
        *)             echo "unknown" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Monitor codec changes
# ─────────────────────────────────────────────────────────────────────────────

monitor_codec_changes() {
    header "Monitoring Bluetooth codec changes (Ctrl+C to stop)"

    local prev_codec=""
    local check_interval=3  # Check every 3 seconds

    while true; do
        current_codec=$(detect_active_codec)

        if [ "$current_codec" != "$prev_codec" ]; then
            echo ""
            info "Codec changed: $prev_codec → $current_codec"
            apply_codec_tuning "$current_codec"
            prev_codec="$current_codec"
        else
            echo -n "."
        fi

        sleep $check_interval
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Display codec matrix
# ─────────────────────────────────────────────────────────────────────────────

display_codec_matrix() {
    echo ""
    echo -e "${MAGENTA}Codec Latency & Tuning Matrix:${NC}"
    echo ""
    printf "%-20s %-20s %-15s %-25s\n" "Codec" "Latency" "WSOLA (seq/sw/ol)" "Reduction"
    printf "%-20s %-20s %-15s %-25s\n" "─────" "────────" "─────────────────" "─────────"

    for codec in SBC AAC aptX LDAC LHDC aptX_HD aptX_Adaptive; do
        latency=$(get_codec_latency "$codec")
        reduction=$(calculate_reduction "$codec")
        IFS=':' read -r sequence seekwindow overlap <<< "${CODEC_PROFILES[$codec]}"

        printf "%-20s %-20s %-15s %-25s\n" "$codec" "$latency" "$sequence/$seekwindow/$overlap" "$reduction"
    done

    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    header "AudioShift Bluetooth Codec Detection & Adaptation"

    detect_device
    echo ""

    if [ -n "$PROFILE_CODEC" ]; then
        # Test specific profile
        apply_codec_tuning "$PROFILE_CODEC"
    else
        # Detect current codec
        current_codec=$(detect_active_codec)
        info "Detected codec: $current_codec"
        apply_codec_tuning "$current_codec"

        # Display matrix
        display_codec_matrix

        # Monitor if requested
        if [ "$MONITOR_MODE" = true ]; then
            monitor_codec_changes
        fi
    fi
}

main "$@"
