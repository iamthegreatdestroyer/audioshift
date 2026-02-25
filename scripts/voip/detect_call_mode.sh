#!/usr/bin/env bash
##
# AudioShift — VoIP Call Mode Detection
# Phase 7 § Sprint 7.1
#
# Purpose:
#   Detect when device is in call mode and optimize AudioShift parameters.
#   Monitors AudioManager mode changes and adapts WSOLA tuning dynamically.
#
# Usage:
#   ./scripts/voip/detect_call_mode.sh [--monitor] [--test-app APP]
#
# Modes:
#   - NORMAL (0): Music/media playback (standard WSOLA)
#   - RINGTONE (1): Incoming call (not processing audio)
#   - IN_CALL (2): Active voice call (VoIP optimized)
#   - IN_COMMUNICATION (3): VoIP app (WhatsApp, Signal)
#
# Output:
#   - Detects current mode
#   - Sets system properties based on mode
#   - Can monitor for mode changes
#   - Integration with audioshift.enabled property
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
TEST_APP=""

# Audio mode constants (from Android AudioSystem)
AUDIO_MODE_NORMAL=0
AUDIO_MODE_RINGTONE=1
AUDIO_MODE_IN_CALL=2
AUDIO_MODE_IN_COMMUNICATION=3

# WSOLA Parameters by mode
declare -A WSOLA_MUSIC=(
    [sequence]=40
    [seekwindow]=15
    [overlap]=8
)

declare -A WSOLA_VOIP=(
    [sequence]=20
    [seekwindow]=8
    [overlap]=4
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
            --test-app)
                TEST_APP="$2"
                shift 2
                ;;
            --serial)
                DEVICE_SERIAL="$2"
                shift 2
                ;;
            --help)
                cat << 'EOF'
AudioShift VoIP Call Mode Detection

Usage: ./scripts/voip/detect_call_mode.sh [OPTIONS]

Options:
  --monitor           Monitor for mode changes continuously
  --test-app APP      Launch test app for testing (e.g., com.whatsapp)
  --serial SERIAL     Device serial (auto-detect if omitted)
  --help              Show this help message

Audio Modes:
  0 = NORMAL              (music playback)
  1 = RINGTONE            (incoming call)
  2 = IN_CALL             (phone call)
  3 = IN_COMMUNICATION    (VoIP apps: WhatsApp, Signal, etc.)

WSOLA Parameter Adaptation:
  Music mode (NORMAL):
    Sequence:   40ms (longer, better quality)
    Seekwindow: 15ms
    Overlap:    8ms

  VoIP mode (IN_CALL, IN_COMMUNICATION):
    Sequence:   20ms (shorter, lower latency)
    Seekwindow: 8ms
    Overlap:    4ms

Example:
  ./scripts/voip/detect_call_mode.sh
  ./scripts/voip/detect_call_mode.sh --monitor
  ./scripts/voip/detect_call_mode.sh --test-app com.whatsapp

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
# Get current audio mode
# ─────────────────────────────────────────────────────────────────────────────

get_audio_mode() {
    local mode=$(adb_cmd shell "dumpsys audio_manager 2>/dev/null | grep -i 'AudioManager mode' | head -1 | awk '{print \$NF}'" || echo "0")

    # Parse mode from property as fallback
    if [ -z "$mode" ] || [ "$mode" = "0" ]; then
        mode=$(adb_cmd shell "getprop ro.audioshift.audio_mode" | tr -d '\r' || echo "0")
    fi

    echo "$mode"
}

# ─────────────────────────────────────────────────────────────────────────────
# Get mode name
# ─────────────────────────────────────────────────────────────────────────────

get_mode_name() {
    local mode=$1
    case $mode in
        $AUDIO_MODE_NORMAL)           echo "NORMAL" ;;
        $AUDIO_MODE_RINGTONE)         echo "RINGTONE" ;;
        $AUDIO_MODE_IN_CALL)          echo "IN_CALL" ;;
        $AUDIO_MODE_IN_COMMUNICATION) echo "IN_COMMUNICATION" ;;
        *)                            echo "UNKNOWN" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Detect if VoIP mode
# ─────────────────────────────────────────────────────────────────────────────

is_voip_mode() {
    local mode=$1
    if [ "$mode" = "$AUDIO_MODE_IN_CALL" ] || [ "$mode" = "$AUDIO_MODE_IN_COMMUNICATION" ]; then
        return 0
    else
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Apply WSOLA parameters
# ─────────────────────────────────────────────────────────────────────────────

apply_wsola_params() {
    local mode=$1
    local mode_name=$(get_mode_name "$mode")

    if is_voip_mode "$mode"; then
        info "VoIP mode detected ($mode_name)"
        info "Applying low-latency WSOLA tuning..."

        adb_cmd shell "setprop audioshift.wsola.sequence_ms ${WSOLA_VOIP[sequence]}"
        adb_cmd shell "setprop audioshift.wsola.seekwindow_ms ${WSOLA_VOIP[seekwindow]}"
        adb_cmd shell "setprop audioshift.wsola.overlap_ms ${WSOLA_VOIP[overlap]}"
        adb_cmd shell "setprop audioshift.voip_mode 1"

        success "WSOLA tuned for VoIP:"
        success "  Sequence: ${WSOLA_VOIP[sequence]}ms"
        success "  Seekwindow: ${WSOLA_VOIP[seekwindow]}ms"
        success "  Overlap: ${WSOLA_VOIP[overlap]}ms"
    else
        info "Music mode ($mode_name)"
        info "Applying standard WSOLA tuning..."

        adb_cmd shell "setprop audioshift.wsola.sequence_ms ${WSOLA_MUSIC[sequence]}"
        adb_cmd shell "setprop audioshift.wsola.seekwindow_ms ${WSOLA_MUSIC[seekwindow]}"
        adb_cmd shell "setprop audioshift.wsola.overlap_ms ${WSOLA_MUSIC[overlap]}"
        adb_cmd shell "setprop audioshift.voip_mode 0"

        success "WSOLA tuned for Music:"
        success "  Sequence: ${WSOLA_MUSIC[sequence]}ms"
        success "  Seekwindow: ${WSOLA_MUSIC[seekwindow]}ms"
        success "  Overlap: ${WSOLA_MUSIC[overlap]}ms"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Monitor mode changes
# ─────────────────────────────────────────────────────────────────────────────

monitor_mode_changes() {
    header "Monitoring audio mode changes (Ctrl+C to stop)"

    local prev_mode=""
    local check_interval=2  # Check every 2 seconds

    while true; do
        current_mode=$(get_audio_mode)
        mode_name=$(get_mode_name "$current_mode")

        if [ "$current_mode" != "$prev_mode" ]; then
            echo ""
            info "Mode changed: $(get_mode_name "$prev_mode") → $mode_name (code: $current_mode)"
            apply_wsola_params "$current_mode"
            prev_mode="$current_mode"
        fi

        sleep $check_interval
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Test with app
# ─────────────────────────────────────────────────────────────────────────────

test_with_app() {
    header "Testing with app: $TEST_APP"

    info "Launching $TEST_APP..."
    adb_cmd shell "am start -n $TEST_APP/.MainActivity 2>/dev/null || true"

    sleep 2

    info "Waiting for mode change..."
    for i in {1..10}; do
        current_mode=$(get_audio_mode)
        mode_name=$(get_mode_name "$current_mode")

        if is_voip_mode "$current_mode"; then
            success "VoIP mode detected!"
            apply_wsola_params "$current_mode"
            return 0
        fi

        echo -n "."
        sleep 1
    done

    warning "Mode did not change after 10 seconds"
    info "Current mode: $(get_audio_mode) ($(get_mode_name $(get_audio_mode)))"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    header "AudioShift VoIP Call Mode Detection"

    detect_device

    if [ -n "$TEST_APP" ]; then
        test_with_app
    else
        # Get and display current mode
        current_mode=$(get_audio_mode)
        mode_name=$(get_mode_name "$current_mode")

        info "Current audio mode: $mode_name (code: $current_mode)"
        apply_wsola_params "$current_mode"

        # Monitor if requested
        if [ "$MONITOR_MODE" = true ]; then
            echo ""
            monitor_mode_changes
        fi
    fi
}

main "$@"
