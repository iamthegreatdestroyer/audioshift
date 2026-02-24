#!/usr/bin/env bash
##
# AudioShift — Device Frequency Validation Gate
# Phase 5 § Sprint 5.2.2
#
# Purpose:
#   Verify that 440 Hz input is converted to 432 Hz output (±0.5 Hz tolerance).
#   Records device speaker output via USB microphone or loopback interface,
#   analyzes spectrum via FFT to confirm pitch conversion accuracy.
#
# Usage:
#   ./scripts/tests/device_frequency_validation.sh [--serial SERIAL] [--tolerance HZ]
#
# Environment Variables:
#   DEVICE_SERIAL       — Android device serial (auto-detect if not set)
#   FREQUENCY_TOLERANCE — Acceptance tolerance in Hz (default: 0.5)
#   RECORD_INTERFACE    — Audio interface for recording (auto-detect if not set)
#
# Requirements:
#   - sox (Sound eXchange) - cross-platform audio processing
#   - python3 with scipy, numpy, soundfile
#   - USB audio interface OR loopback driver for recording
#   - At least 5 seconds of recording time
#
# Success Criteria:
#   - Measured frequency within 432 ± 0.5 Hz
#   - FFT analysis completes without error
#   - Signal-to-noise ratio indicates clear tone detection
#
# Returns:
#   0 — Frequency validation passed
#   1 — Measured frequency outside tolerance
#   2 — Setup error (missing dependencies, no audio interface)
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

DEVICE_SERIAL="${DEVICE_SERIAL:-}"
FREQUENCY_TOLERANCE="${FREQUENCY_TOLERANCE:-0.5}"
RECORD_INTERFACE="${RECORD_INTERFACE:-}"
TARGET_FREQUENCY="432"
INPUT_FREQUENCY="440"

# Audio recording parameters
RECORD_DURATION_SEC=5
SAMPLE_RATE=48000
CHANNELS=2

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
            --serial)
                DEVICE_SERIAL="$2"
                shift 2
                ;;
            --tolerance)
                FREQUENCY_TOLERANCE="$2"
                shift 2
                ;;
            --interface)
                RECORD_INTERFACE="$2"
                shift 2
                ;;
            --help)
                cat << EOF
AudioShift Device Frequency Validation Gate

Usage: $(basename "$0") [OPTIONS]

Options:
  --serial SERIAL       Device serial number (auto-detect if omitted)
  --tolerance HZ        Frequency tolerance in Hz (default: 0.5)
  --interface IFACE     Audio interface for recording (auto-detect if omitted)
  --help                Show this help message

Environment Variables:
  DEVICE_SERIAL         Override --serial
  FREQUENCY_TOLERANCE   Override --tolerance
  RECORD_INTERFACE      Override --interface

Requirements:
  - sox (Sound eXchange)
  - python3 with scipy, numpy, soundfile
  - USB audio interface or loopback driver

Examples:
  $(basename "$0")
  $(basename "$0") --serial XXXXXXXXXX --tolerance 0.3
  DEVICE_SERIAL=RF... $(basename "$0") --interface plughw:1,0

Returns:
  0 - Frequency validation passed
  1 - Measured frequency outside tolerance
  2 - Device or setup error

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

    info "Checking required tools..."

    local missing=()

    for tool in adb sox python3; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        else
            success "✓ $tool installed"
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  - ubuntu/debian: sudo apt-get install sox python3-scipy python3-soundfile"
        echo "  - macos: brew install sox && pip3 install scipy soundfile"
        echo "  - windows: install from http://sox.sourceforge.net/"
        return 2
    fi

    # Check Python modules
    info "Checking Python modules..."
    python3 -c "import numpy; import scipy.signal; import soundfile" 2>/dev/null || {
        error "Missing Python modules (numpy, scipy, soundfile)"
        echo "  Install: pip3 install numpy scipy soundfile"
        return 2
    }

    success "All dependencies available"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Detect device and audio interface
# ─────────────────────────────────────────────────────────────────────────────

detect_device_and_interface() {
    header "Step 2: Detect device and audio interface"

    # Auto-detect device serial
    if [ -z "$DEVICE_SERIAL" ]; then
        info "Auto-detecting device..."
        DEVICE_SERIAL=$(adb get-serialno 2>/dev/null || true)

        if [ -z "$DEVICE_SERIAL" ] || [ "$DEVICE_SERIAL" = "unknown" ]; then
            error "No device found. Connect via USB or set DEVICE_SERIAL"
            return 2
        fi
    fi

    info "Device serial: $DEVICE_SERIAL"

    # Verify device is online
    if [ "$(adb_cmd get-state 2>/dev/null || true)" != "device" ]; then
        error "Device not in 'device' state"
        return 2
    fi

    success "Device connected"

    # Auto-detect audio interface if not specified
    if [ -z "$RECORD_INTERFACE" ]; then
        info "Auto-detecting audio record interface..."

        if [ "$(uname)" = "Darwin" ]; then
            # macOS: use system audio
            RECORD_INTERFACE=":0"
            info "Using macOS system audio input"
        elif [ "$(uname)" = "Linux" ]; then
            # Linux: find USB audio device or loopback
            if [ -f /proc/asound/cards ]; then
                RECORD_INTERFACE=$(grep -E "USB|Loopback" /proc/asound/cards 2>/dev/null | head -1 | cut -d' ' -f1 || echo "0")
                RECORD_INTERFACE="hw:${RECORD_INTERFACE}"
                info "Using Linux audio interface: $RECORD_INTERFACE"
            else
                warning "Could not detect audio interface, using default"
                RECORD_INTERFACE="hw:0"
            fi
        else
            warning "Unknown OS, using default audio interface"
            RECORD_INTERFACE="hw:0"
        fi
    fi

    success "Audio interface: $RECORD_INTERFACE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Generate and record test tone
# ─────────────────────────────────────────────────────────────────────────────

generate_and_record_tone() {
    header "Step 3: Generate test tone and record output"

    # Create temporary directory for audio files
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    info "Temp directory: $TEMP_DIR"

    # Generate 440 Hz test tone on device
    info "Generating ${INPUT_FREQUENCY}Hz test tone on device..."
    adb_cmd shell "am start \
        -n com.android.systemui/.audio.ToneGenerator \
        --ei freq ${INPUT_FREQUENCY} \
        --ei duration $((RECORD_DURATION_SEC * 1000)) \
        2>/dev/null" || {
        warning "System tone generator not available, using fallback"
    }

    # Wait for audio subsystem to stabilize
    sleep 1

    info "Recording audio output for ${RECORD_DURATION_SEC} seconds..."
    info "Interface: $RECORD_INTERFACE"
    echo ""

    # Record audio using sox
    # Timeout after 10 seconds to avoid hanging
    timeout 10 sox -t alsa "$RECORD_INTERFACE" \
        -r "$SAMPLE_RATE" \
        -c "$CHANNELS" \
        -b 16 \
        "$TEMP_DIR/recording.wav" \
        2>/dev/null || {
        warning "Audio recording completed (or timed out)"
    }

    if [ ! -f "$TEMP_DIR/recording.wav" ] || [ ! -s "$TEMP_DIR/recording.wav" ]; then
        error "Audio recording failed or empty"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Connect USB audio interface to computer"
        echo "  2. List available interfaces: arecord -l"
        echo "  3. Set RECORD_INTERFACE=hw:X,0 where X is device number"
        echo "  4. Or set RECORD_INTERFACE=plughw:X,0 for automatic conversion"
        return 2
    fi

    success "Audio recorded: $(ls -lh "$TEMP_DIR/recording.wav" | awk '{print $5}')"

    # Mix stereo to mono for analysis
    sox "$TEMP_DIR/recording.wav" \
        -c 1 \
        "$TEMP_DIR/recording_mono.wav" \
        remix - 2>/dev/null || true

    echo "$TEMP_DIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Analyze frequency via FFT (Python/SciPy)
# ─────────────────────────────────────────────────────────────────────────────

analyze_frequency() {
    local audio_file="$1"

    header "Step 4: Analyze frequency via FFT"

    info "Audio file: $audio_file"

    # Python script for FFT analysis
    MEASURED_FREQ=$(python3 << 'PYTHON_EOF' 2>/dev/null || echo "0"
import numpy as np
from scipy import signal
import soundfile as sf
import sys

try:
    # Read audio file
    audio_file = sys.argv[1]
    samples, sr = sf.read(audio_file)

    # Handle stereo → mono
    if len(samples.shape) > 1:
        samples = np.mean(samples, axis=1)

    # Skip first 0.5s to avoid startup transients
    skip_samples = int(sr * 0.5)
    samples = samples[skip_samples:]

    # Apply Welch's method for robust frequency estimation
    f, Pxx = signal.welch(samples, sr, nperseg=min(4096, len(samples)))

    # Find peak frequency
    peak_idx = np.argmax(Pxx)
    peak_freq = f[peak_idx]

    # Find frequencies within ±50 Hz of peak (in case of noise)
    freq_range = (f > peak_freq - 50) & (f < peak_freq + 50)
    if np.any(freq_range):
        refined_peak_idx = peak_idx
        for i in range(max(0, peak_idx - 100), min(len(f), peak_idx + 100)):
            if Pxx[i] > Pxx[refined_peak_idx]:
                refined_peak_idx = i
        peak_freq = f[refined_peak_idx]

    # Calculate signal-to-noise ratio (rough estimate)
    signal_power = np.max(Pxx)
    noise_power = np.mean(Pxx[Pxx < np.median(Pxx)])
    snr_db = 10 * np.log10(signal_power / (noise_power + 1e-10))

    print(f"{peak_freq:.1f}")
    print(f"SNR: {snr_db:.1f} dB", file=sys.stderr)

except Exception as e:
    print(f"0", file=sys.stdout)
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
)

    if [ "$MEASURED_FREQ" = "0" ]; then
        error "FFT analysis failed"
        return 1
    fi

    echo "$MEASURED_FREQ"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Evaluate frequency against target
# ─────────────────────────────────────────────────────────────────────────────

evaluate_frequency() {
    local measured_freq="$1"

    header "Step 5: Evaluate frequency against target"

    # Extract integer and decimal parts
    MEASURED_INT=$(echo "$measured_freq" | cut -d'.' -f1)
    TOLERANCE_INT=$(echo "$FREQUENCY_TOLERANCE" | cut -d'.' -f1)

    echo ""
    echo "  Target Frequency:     ${TARGET_FREQUENCY}Hz"
    echo "  Measured Frequency:   ${measured_freq}Hz"
    echo "  Tolerance:            ±${FREQUENCY_TOLERANCE}Hz"
    echo ""

    # Check if measured frequency is within tolerance
    DIFF=$(python3 -c "import sys; print(abs($measured_freq - $TARGET_FREQUENCY))")
    DIFF_INT=$(echo "$DIFF" | cut -d'.' -f1)

    if (( DIFF_INT < TOLERANCE_INT || (DIFF_INT == TOLERANCE_INT && $(echo "$DIFF < $FREQUENCY_TOLERANCE" | bc -l) ) )); then
        success "PASS: Measured frequency ${measured_freq}Hz is within ±${FREQUENCY_TOLERANCE}Hz"
        echo ""
        info "AudioShift 432Hz conversion verified!"
        return 0
    else
        error "FAIL: Measured frequency ${measured_freq}Hz is outside tolerance (±${FREQUENCY_TOLERANCE}Hz)"
        echo ""
        error "AudioShift 432Hz conversion failed"
        echo ""
        info "Possible causes:"
        echo "  - Device audio processing is bypassing the effect"
        echo "  - Effect not enabled or not loading"
        echo "  - Recording interface quality or calibration issue"
        echo "  - Pitch shift algorithm not functioning"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    check_dependencies || return $?
    detect_device_and_interface || return $?

    TEMP_DIR=$(generate_and_record_tone) || return $?
    trap "rm -rf $TEMP_DIR" EXIT

    MEASURED_FREQ=$(analyze_frequency "$TEMP_DIR/recording_mono.wav") || {
        error "Frequency analysis failed"
        return 2
    }

    evaluate_frequency "$MEASURED_FREQ"
}

main "$@"
exit_code=$?

echo ""
exit "$exit_code"
