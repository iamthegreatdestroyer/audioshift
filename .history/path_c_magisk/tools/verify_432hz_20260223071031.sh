#!/usr/bin/env bash
# AudioShift — Device Verification Tool (Shell)
#
# Verifies 432 Hz pitch shift is active on a connected Android device.
# Plays a 440 Hz test tone, captures the audio output, and measures
# the dominant frequency to confirm the ≈8 Hz downward shift.
#
# Usage:
#   ./verify_432hz.sh [--device SERIAL] [--duration 5] [--verbose]
#
# Requirements on host:
#   adb, sox, python3 (for FFT), optional: aubio-tools
#
# Requirements on device:
#   Magisk module installed, tinyplay / tinycap (or similar)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TOOLS_DIR="$WORKSPACE_ROOT/path_c_magisk/tools"
TMP_DIR="$(mktemp -d)"

# Measurement parameters
SAMPLE_RATE=48000
CHANNELS=2
DURATION=5          # seconds of audio to capture
FREQ_EXPECTED=432   # Hz
FREQ_INPUT=440      # Hz
FREQ_TOLERANCE=2    # Hz — pass/fail threshold

# Target device
ADB_SERIAL=""
VERBOSE=false

# ─── Argument parsing ────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device|-s)    ADB_SERIAL="$2"     ; shift 2 ;;
        --duration|-d)  DURATION="$2"       ; shift 2 ;;
        --verbose|-v)   VERBOSE=true        ; shift ;;
        --help|-h)
            echo "Usage: $0 [--device SERIAL] [--duration 5] [--verbose]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

ADB_CMD="adb"
[ -n "$ADB_SERIAL" ] && ADB_CMD="adb -s $ADB_SERIAL"

# ─── Logging ─────────────────────────────────────────────────────────────────

info()  { echo -e "\033[1;36m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[PASS]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*" >&2; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ─── Pre-flight ───────────────────────────────────────────────────────────────

info "AudioShift 432 Hz Verification"
info "Target frequency: ${FREQ_EXPECTED} Hz (from ${FREQ_INPUT} Hz input)"

command -v adb >/dev/null    || { fail "adb not found in PATH"; exit 1; }

# Device connectivity
if ! $ADB_CMD get-state >/dev/null 2>&1; then
    fail "No device connected (or SERIAL not found)"
    echo "  Run: adb devices"
    exit 1
fi

DEVICE_MODEL=$($ADB_CMD shell getprop ro.product.model 2>/dev/null | tr -d '\r')
ANDROID_VER=$($ADB_CMD shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
info "Device: $DEVICE_MODEL (Android $ANDROID_VER)"

# ─── Step 1: Check module presence ───────────────────────────────────────────

info "Checking Magisk module status..."

MODULE_STATUS=$($ADB_CMD shell magisk --list-modules 2>/dev/null | grep -i audioshift || echo "")
if [ -n "$MODULE_STATUS" ]; then
    ok "Module 'audioshift' found in Magisk"
else
    warn "Module not listed by Magisk — checking file presence..."
fi

SO_CHECK=$($ADB_CMD shell "[ -f /system/lib64/soundfx/libaudioshift_effect.so ] && echo YES || echo NO" 2>/dev/null | tr -d '\r')
if [ "$SO_CHECK" = "YES" ]; then
    ok "libaudioshift_effect.so present at /system/lib64/soundfx/"
else
    SO_VENDOR=$($ADB_CMD shell "[ -f /vendor/lib64/soundfx/libaudioshift_effect.so ] && echo YES || echo NO" 2>/dev/null | tr -d '\r')
    if [ "$SO_VENDOR" = "YES" ]; then
        ok "libaudioshift_effect.so present at /vendor/lib64/soundfx/"
    else
        fail "libaudioshift_effect.so not found on device"
    fi
fi

# ─── Step 2: Check system properties ─────────────────────────────────────────

info "Checking AudioShift system properties..."

ENABLED=$($ADB_CMD shell getprop persist.audioshift.enabled 2>/dev/null | tr -d '\r')
PITCH=$($ADB_CMD shell getprop persist.audioshift.pitch_ratio 2>/dev/null | tr -d '\r')
VERSION=$($ADB_CMD shell getprop persist.audioshift.version 2>/dev/null | tr -d '\r')

if [ "$ENABLED" = "1" ]; then
    ok "persist.audioshift.enabled = $ENABLED"
else
    fail "persist.audioshift.enabled = '$ENABLED' (expected '1')"
fi

if [ -n "$PITCH" ]; then
    ok "persist.audioshift.pitch_ratio = $PITCH"
else
    warn "persist.audioshift.pitch_ratio not set"
fi

$VERBOSE && info "persist.audioshift.version = $VERSION"

# ─── Step 3: Check Effects XML registration ───────────────────────────────────

info "Checking Effects Framework registration..."

for xml_path in \
    "/vendor/etc/audio_effects.xml" \
    "/vendor/etc/audio_effects_audioshift.xml" \
    "/system/etc/audio_effects.xml"
do
    XML_EXISTS=$($ADB_CMD shell "[ -f $xml_path ] && echo YES || echo NO" 2>/dev/null | tr -d '\r')
    if [ "$XML_EXISTS" = "YES" ]; then
        UUID_FOUND=$($ADB_CMD shell "grep -c 'f1a2b3c4' $xml_path 2>/dev/null || echo 0" | tr -d '\r')
        if [ "$UUID_FOUND" != "0" ]; then
            ok "UUID registered in $xml_path"
        else
            $VERBOSE && warn "UUID not in $xml_path"
        fi
    fi
done

# ─── Step 4: AudioFlinger effect loading ─────────────────────────────────────

info "Checking if AudioFlinger loaded the effect..."

# dumpstate / dumpsys media.audio_flinger shows loaded effects
EFFECT_DUMP=$($ADB_CMD shell "dumpsys media.audio_flinger 2>/dev/null | grep -i 'audioshift\|432\|f1a2b3c4' | head -20" 2>/dev/null || echo "")
if [ -n "$EFFECT_DUMP" ]; then
    ok "Effect visible in AudioFlinger dump:"
    echo "$EFFECT_DUMP" | sed 's/^/  /'
else
    warn "Effect not (yet) visible in AudioFlinger — may load on first audio playback"
fi

# ─── Step 5: Frequency measurement ───────────────────────────────────────────

info "Measuring output frequency..."

# Generate 440 Hz PCM test tone (if sox available on host)
if command -v sox >/dev/null 2>&1; then
    info "Generating ${FREQ_INPUT} Hz test tone (${DURATION}s)..."
    TONE_FILE="$TMP_DIR/tone_440hz.wav"
    sox -n -r "$SAMPLE_RATE" -c "$CHANNELS" "$TONE_FILE" \
        synth "$DURATION" sine "$FREQ_INPUT" vol -6dB

    # Push and play on device via tinyplay (if available)
    TINYPLAY_CHECK=$($ADB_CMD shell "command -v tinyplay 2>/dev/null || echo ''" | tr -d '\r')
    if [ -n "$TINYPLAY_CHECK" ]; then
        info "Pushing test tone to device..."
        $ADB_CMD push "$TONE_FILE" /sdcard/audioshift_test_tone.wav >/dev/null

        # Capture audio output via tinycap while playing
        CAPTURE_FILE="$TMP_DIR/captured.raw"
        info "Capturing audio output for ${DURATION}s..."

        # Start capture in background, then play
        $ADB_CMD shell "tinycap /sdcard/audioshift_capture.raw -D 0 -d 0 -r $SAMPLE_RATE -c $CHANNELS -b 16 &" \
            2>/dev/null || true
        sleep 0.5
        $ADB_CMD shell "tinyplay /sdcard/audioshift_test_tone.wav" >/dev/null 2>&1 || true
        sleep 1
        $ADB_CMD shell "pkill tinycap 2>/dev/null || true" >/dev/null 2>&1

        # Pull captured audio
        $ADB_CMD pull /sdcard/audioshift_capture.raw "$CAPTURE_FILE" >/dev/null 2>&1

        if [ -f "$CAPTURE_FILE" ] && [ -s "$CAPTURE_FILE" ]; then
            info "Captured $(du -h "$CAPTURE_FILE" | cut -f1) of audio"

            # Convert raw PCM to WAV for sox analysis
            CAPTURE_WAV="$TMP_DIR/captured.wav"
            sox -r "$SAMPLE_RATE" -e signed -b 16 -c "$CHANNELS" \
                "$CAPTURE_FILE" "$CAPTURE_WAV" 2>/dev/null

            # Use Python FFT analysis
            if [ -f "$TOOLS_DIR/verify_432hz.py" ]; then
                info "Running FFT analysis..."
                python3 "$TOOLS_DIR/verify_432hz.py" \
                    --input "$CAPTURE_WAV" \
                    --expected "$FREQ_EXPECTED" \
                    --tolerance "$FREQ_TOLERANCE"
            else
                # Fallback: sox stat for rough frequency estimate
                STAT_OUTPUT=$(sox "$CAPTURE_WAV" -n stat 2>&1 || echo "")
                $VERBOSE && echo "$STAT_OUTPUT"
                warn "verify_432hz.py not found — run it directly for accurate measurement"
            fi
        else
            warn "Audio capture failed — tinycap may not be available or permission denied"
        fi
    else
        warn "tinyplay not available on device — skipping playback/capture test"
        info "Manual test: Play a 440 Hz tone through device speakers"
        info "  Then capture output and run: python3 $TOOLS_DIR/verify_432hz.py"
    fi
else
    warn "sox not found on host — skipping automated frequency measurement"
    info "Install sox: apt-get install sox  OR  brew install sox"
fi

# ─── Step 6: Latency check ────────────────────────────────────────────────────

info "Checking AudioShift latency report..."

LATENCY_PROP=$($ADB_CMD shell getprop persist.audioshift.latency_ms 2>/dev/null | tr -d '\r')
if [ -n "$LATENCY_PROP" ] && [ "$LATENCY_PROP" != "0" ]; then
    if (( $(echo "$LATENCY_PROP < 20" | bc -l 2>/dev/null || echo "1") )); then
        ok "Reported latency: ${LATENCY_PROP}ms (target: <20ms)"
    else
        warn "Reported latency: ${LATENCY_PROP}ms (target: <20ms)"
    fi
else
    warn "Latency property not set — effect may not be processing yet"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────────"
echo "  AudioShift Verification Summary"
echo "─────────────────────────────────────────────"
echo "  Device:   $DEVICE_MODEL"
echo "  Expected: ${FREQ_EXPECTED} Hz output from ${FREQ_INPUT} Hz input"
echo "  Module:   $([ "$SO_CHECK" = "YES" ] && echo "✓ INSTALLED" || echo "✗ MISSING")"
echo "  Enabled:  $([ "$ENABLED" = "1" ]   && echo "✓ YES"       || echo "✗ NO")"
echo "─────────────────────────────────────────────"
echo ""
echo "  For precise frequency measurement:"
echo "    python3 $TOOLS_DIR/verify_432hz.py --help"
