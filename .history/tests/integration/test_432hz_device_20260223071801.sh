#!/usr/bin/env bash
# =============================================================================
# AudioShift Integration Test Suite — Device-Based
# =============================================================================
# End-to-end test: installs module, reboots, verifies frequency shift,
# then optionally uninstalls and verifies the effect is gone.
#
# Usage:
#   ./test_432hz_device.sh                     # run all tests
#   ./test_432hz_device.sh --skip-reboot       # skip the post-install reboot
#   ./test_432hz_device.sh --no-uninstall      # leave module installed after test
#   ./test_432hz_device.sh --zip path/to.zip   # override module ZIP path
#
# Prerequisites:
#   - adb in PATH, device connected and authorized
#   - tinycap / tinyplay available in device /system/bin/
#   - sox installed on host:   brew install sox  OR  apt install sox
#   - numpy + soundfile installed: pip install numpy soundfile
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODULE_ZIP="${REPO_ROOT}/path_c_magisk/dist/audioshift-v1.0.0.zip"
VERIFY_SCRIPT="${REPO_ROOT}/path_c_magisk/tools/verify_432hz.sh"
ANALYZE_SCRIPT="${REPO_ROOT}/path_c_magisk/tools/verify_432hz.py"
RESULTS_DIR="${REPO_ROOT}/tests/results"
REPORT_JSON="${RESULTS_DIR}/integration_$(date +%Y%m%d_%H%M%S).json"

FREQ_INPUT=440
FREQ_EXPECTED=432
FREQ_TOLERANCE=2

SKIP_REBOOT=false
NO_UNINSTALL=false
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
START_TIME=$(date +%s)

# ─── Colour helpers ───────────────────────────────────────────────────────────

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; RESET='\033[0m'; BOLD='\033[1m'

info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
pass()  { echo -e "${GREEN}[PASS]${RESET}  $*"; PASS_COUNT=$((PASS_COUNT+1)); }
fail()  { echo -e "${RED}[FAIL]${RESET}  $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
step()  { echo -e "\n${BOLD}${BLUE}══ $* ${RESET}"; }

# ─── Argument parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-reboot)   SKIP_REBOOT=true ;;
        --no-uninstall)  NO_UNINSTALL=true ;;
        --zip)           MODULE_ZIP="$2"; shift ;;
        -h|--help)
            sed -n '3,20p' "$0"
            exit 0 ;;
        *)  echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

mkdir -p "$RESULTS_DIR"

# ─── Utility functions ────────────────────────────────────────────────────────

adb_ok() {
    adb shell "$@" > /dev/null 2>&1
    return $?
}

adb_out() {
    adb shell "$@" 2>/dev/null || true
}

wait_for_device() {
    local timeout="${1:-120}"
    info "Waiting for device (up to ${timeout}s)…"
    adb wait-for-device
    # Wait until fully booted (boot animation finished)
    local elapsed=0
    while [[ "$( adb_out getprop sys.boot_completed )" != "1" ]]; do
        sleep 2
        elapsed=$((elapsed+2))
        if [[ $elapsed -ge $timeout ]]; then
            fail "Device did not complete boot within ${timeout}s"
            return 1
        fi
    done
    sleep 3   # extra settle time for audio services
    info "Device ready."
}

capture_tone_on_device() {
    # Generate a test tone on host, push to device, play and capture simultaneously
    local freq="$1"
    local out_wav="$2"
    local capture_duration=4   # seconds

    local tone_wav="${RESULTS_DIR}/tone_${freq}hz.wav"
    local raw_cap="${RESULTS_DIR}/captured_raw.pcm"
    local cap_wav="${RESULTS_DIR}/captured_${freq}hz_raw.wav"

    # Generate test tone on host
    if ! sox -n -r 48000 -c 2 "$tone_wav" synth $((capture_duration+1)) sine $freq gain -3 2>/dev/null; then
        warn "sox tone generation failed (is sox installed?)"
        return 1
    fi

    # Push tone to device
    adb push "$tone_wav" /sdcard/audioshift_test_tone.wav > /dev/null

    # Play through AudioFlinger (so our effect is applied) while simultaneously
    # capturing the output on the device's loopback. Use tinyplay/tinycap.
    adb shell "tinyplay /sdcard/audioshift_test_tone.wav &
               sleep 0.5
               tinycap /sdcard/audioshift_captured.pcm -D 0 -d 0 -r 48000 -b 16 -c 2 -p 1024 -n 4 &
               sleep ${capture_duration}
               kill %1 %2 2>/dev/null; wait 2>/dev/null; true" 2>/dev/null || true

    # Pull captured PCM
    adb pull /sdcard/audioshift_captured.pcm "$raw_cap" > /dev/null 2>&1 || {
        warn "Could not pull captured PCM from device"
        return 1
    }

    # Convert raw PCM to WAV
    sox -t raw -r 48000 -e signed -b 16 -c 2 "$raw_cap" "$cap_wav" 2>/dev/null || {
        warn "sox PCM→WAV conversion failed"
        return 1
    }

    cp "$cap_wav" "$out_wav"
    return 0
}

# ─── Banner ───────────────────────────────────────────────────────────────────

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗"
echo    "║   AudioShift Integration Test Suite — Device          ║"
echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
echo    "  Module ZIP:  $MODULE_ZIP"
echo    "  Results:     $RESULTS_DIR"
echo

# ═════════════════════════════════════════════════════════════════════════════
# TEST 1 — Preconditions
# ═════════════════════════════════════════════════════════════════════════════

step "T1: Precondition Checks"

# T1.1 ADB connectivity
if adb devices | grep -q "device$"; then
    pass "T1.1  ADB device connected"
else
    fail "T1.1  No ADB device — aborting"
    exit 1
fi

# T1.2 Module ZIP exists
if [[ -f "$MODULE_ZIP" ]]; then
    pass "T1.2  Module ZIP found: $(basename "$MODULE_ZIP")"
else
    fail "T1.2  Module ZIP not found: $MODULE_ZIP"
    echo "       Run: $REPO_ROOT/path_c_magisk/build_scripts/build_module.sh"
    exit 1
fi

# T1.3 Magisk present on device
if adb_ok "su -c 'magisk --version'"; then
    MAGISK_VER=$(adb_out "su -c 'magisk --version'" | head -1)
    pass "T1.3  Magisk detected: $MAGISK_VER"
else
    fail "T1.3  Magisk not found — PATH-C requires rooted device with Magisk"
    exit 1
fi

# T1.4 Host tools
for tool in sox python3; do
    if command -v "$tool" &>/dev/null; then
        pass "T1.4  Host tool found: $tool"
    else
        warn "T1.4  Host tool missing: $tool (some tests will be skipped)"
        SKIP_COUNT=$((SKIP_COUNT+1))
    fi
done

# T1.5 Android version
ANDROID_VER=$(adb_out getprop ro.build.version.release)
SDK_VER=$(adb_out getprop ro.build.version.sdk)
info "      Device: Android $ANDROID_VER (API $SDK_VER)"
if [[ "${SDK_VER:-0}" -ge 28 ]]; then
    pass "T1.5  API level ≥ 28 (required)"
else
    fail "T1.5  API level ${SDK_VER} < 28 — module requires API 28+"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 2 — Baseline (before install)
# ═════════════════════════════════════════════════════════════════════════════

step "T2: Baseline — Module NOT Installed"

# T2.1 Confirm module absent
if adb_ok "su -c 'ls /data/adb/modules/audioshift'"; then
    warn "T2.1  Module already installed — skipping install step, running atop existing"
    ALREADY_INSTALLED=true
else
    ALREADY_INSTALLED=false
    pass "T2.1  Module not yet installed (clean baseline)"
fi

# T2.2 Baseline frequency capture (440 Hz passthrough expected)
if command -v sox &>/dev/null; then
    BASELINE_WAV="${RESULTS_DIR}/baseline_captured.wav"
    info "      Capturing baseline tone (module off)…"
    if capture_tone_on_device $FREQ_INPUT "$BASELINE_WAV"; then
        BASELINE_HZ=$(python3 "$ANALYZE_SCRIPT" \
            --input "$BASELINE_WAV" \
            --expected $FREQ_INPUT \
            --tolerance $FREQ_TOLERANCE \
            --report "${RESULTS_DIR}/baseline_report.json" 2>/dev/null \
            | grep "Consensus:" | awk '{print $2}' || echo "?")
        info "      Baseline peak: ${BASELINE_HZ} Hz"
        if python3 "$ANALYZE_SCRIPT" --input "$BASELINE_WAV" \
               --expected $FREQ_INPUT --tolerance $FREQ_TOLERANCE &>/dev/null; then
            pass "T2.2  Baseline confirmed passthrough at ≈440 Hz"
        else
            warn "T2.2  Baseline capture shows shift — module may already be active"
        fi
    else
        warn "T2.2  Baseline capture failed (skipped)"
        SKIP_COUNT=$((SKIP_COUNT+1))
    fi
else
    warn "T2.2  sox not installed — skipping baseline capture"
    SKIP_COUNT=$((SKIP_COUNT+1))
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 3 — Module Installation
# ═════════════════════════════════════════════════════════════════════════════

step "T3: Module Installation"

if [[ "$ALREADY_INSTALLED" == "false" ]]; then
    # T3.1 Push ZIP to device
    info "      Pushing module ZIP to device…"
    adb push "$MODULE_ZIP" /sdcard/audioshift-latest.zip > /dev/null
    pass "T3.1  ZIP pushed to /sdcard/audioshift-latest.zip"

    # T3.2 Install via Magisk
    info "      Installing via Magisk (this may take ~30s)…"
    INSTALL_OUT=$(adb_out "su -c 'magisk --install-module /sdcard/audioshift-latest.zip'" || true)
    if echo "$INSTALL_OUT" | grep -qi "success\|installed"; then
        pass "T3.2  Module installed by Magisk"
    else
        # Try alternate magisk install path
        adb_ok "su -c 'magisk --install /sdcard/audioshift-latest.zip'" || true
        info "      Checking module directory…"
        if adb_ok "su -c 'ls /data/adb/modules/audioshift/module.prop'"; then
            pass "T3.2  Module directory present (/data/adb/modules/audioshift/)"
        else
            fail "T3.2  Magisk install may have failed — check device for dialog"
            warn "      Try manual install: copy ZIP to device, open Magisk → Modules → Install from storage"
        fi
    fi
else
    pass "T3.1  Module already installed — skipping installation"
    pass "T3.2  (skipped)"
fi

# T3.3 module.prop verification
if adb_ok "su -c 'cat /data/adb/modules/audioshift/module.prop'"; then
    MOD_VER=$(adb_out "su -c 'cat /data/adb/modules/audioshift/module.prop'" | grep "^version=" | cut -d= -f2)
    pass "T3.3  module.prop found (version: $MOD_VER)"
else
    fail "T3.3  module.prop not found under /data/adb/modules/audioshift/"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 4 — Reboot and post-boot checks
# ═════════════════════════════════════════════════════════════════════════════

step "T4: Post-Boot Verification"

if [[ "$SKIP_REBOOT" == "true" ]]; then
    warn "T4.0  --skip-reboot set — skipping reboot (using current state)"
else
    info "      Rebooting device…"
    adb reboot
    sleep 5
    wait_for_device 180
fi

# T4.1 .so present in soundfx overlay
SO_PATH_SYSTEM="$(adb_out "su -c 'ls /system/lib64/soundfx/libaudioshift_effect.so 2>/dev/null'")"
SO_PATH_VENDOR="$(adb_out "su -c 'ls /vendor/lib64/soundfx/libaudioshift_effect.so 2>/dev/null'")"

if [[ -n "$SO_PATH_SYSTEM" || -n "$SO_PATH_VENDOR" ]]; then
    pass "T4.1  libaudioshift_effect.so present in soundfx directory"
else
    fail "T4.1  libaudioshift_effect.so not found in /system/lib64/soundfx/ or /vendor/lib64/soundfx/"
fi

# T4.2 System properties set
PROP_ENABLED=$(adb_out getprop persist.audioshift.enabled)
PROP_RATIO=$(adb_out getprop persist.audioshift.pitch_ratio)
if [[ "$PROP_ENABLED" == "true" ]]; then
    pass "T4.2  persist.audioshift.enabled=true"
else
    fail "T4.2  persist.audioshift.enabled not 'true' (got: '$PROP_ENABLED')"
fi
if [[ -n "$PROP_RATIO" ]]; then
    pass "T4.3  persist.audioshift.pitch_ratio=$PROP_RATIO"
else
    fail "T4.3  persist.audioshift.pitch_ratio not set"
fi

# T4.4 Effects XML registration
XML_UUID=$(adb_out "su -c 'grep -r f1a2b3c4 /vendor/etc/audio_effects*.xml 2>/dev/null | head -1'" || true)
if [[ -n "$XML_UUID" ]]; then
    pass "T4.4  Effect UUID registered in audio_effects XML"
else
    fail "T4.4  UUID f1a2b3c4-... not found in /vendor/etc/audio_effects*.xml"
fi

# T4.5 AudioFlinger loaded our library
AF_DUMP=$(adb_out "su -c 'dumpsys media.audio_flinger'" 2>/dev/null || true)
if echo "$AF_DUMP" | grep -qi "audioshift\|f1a2b3c4\|432"; then
    pass "T4.5  AudioFlinger dump references AudioShift effect"
else
    warn "T4.5  AudioFlinger dump does not mention AudioShift — may need audio playback first"
    SKIP_COUNT=$((SKIP_COUNT+1))
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 5 — Frequency Measurement
# ═════════════════════════════════════════════════════════════════════════════

step "T5: 432 Hz Frequency Measurement"

if command -v sox &>/dev/null && command -v python3 &>/dev/null; then
    SHIFTED_WAV="${RESULTS_DIR}/shifted_captured.wav"
    info "      Capturing frequency-shifted output…"

    if capture_tone_on_device $FREQ_INPUT "$SHIFTED_WAV"; then
        # Run Python FFT analysis
        ANALYSIS_REPORT="${RESULTS_DIR}/shifted_report.json"
        if python3 "$ANALYZE_SCRIPT" \
                --input "$SHIFTED_WAV" \
                --expected $FREQ_EXPECTED \
                --tolerance $FREQ_TOLERANCE \
                --report "$ANALYSIS_REPORT"; then
            pass "T5.1  Frequency shift to 432 Hz verified"

            MEASURED_HZ=$(python3 -c "import json; d=json.load(open('$ANALYSIS_REPORT')); print(d.get('consensus',{}).get('measured_hz','?'))" 2>/dev/null || echo "?")
            MEASURED_SEMI=$(python3 -c "import json; d=json.load(open('$ANALYSIS_REPORT')); print(d.get('consensus',{}).get('semitones','?'))" 2>/dev/null || echo "?")
            info "      Measured: ${MEASURED_HZ} Hz  (${MEASURED_SEMI} semitones)"
        else
            fail "T5.1  Frequency did not shift to expected 432 Hz"
            if [[ -f "$ANALYSIS_REPORT" ]]; then
                BAD_HZ=$(python3 -c "import json; d=json.load(open('$ANALYSIS_REPORT')); print(d.get('consensus',{}).get('measured_hz','?'))" 2>/dev/null || echo "?")
                info "      Measured: ${BAD_HZ} Hz (expected: ${FREQ_EXPECTED} ± ${FREQ_TOLERANCE} Hz)"
            fi
        fi

        # T5.2 Ratio accuracy
        if [[ -f "$ANALYSIS_REPORT" ]]; then
            ERROR_HZ=$(python3 -c "import json; d=json.load(open('$ANALYSIS_REPORT')); print(d.get('consensus',{}).get('error_from_432hz',99))" 2>/dev/null || echo "99")
            if python3 -c "import sys; sys.exit(0 if float('$ERROR_HZ') <= 0.5 else 1)" 2>/dev/null; then
                pass "T5.2  Frequency accuracy ±0.5 Hz (error: ${ERROR_HZ} Hz)"
            elif python3 -c "import sys; sys.exit(0 if float('$ERROR_HZ') <= $FREQ_TOLERANCE else 1)" 2>/dev/null; then
                pass "T5.2  Frequency within tolerance (error: ${ERROR_HZ} Hz)"
            else
                fail "T5.2  Frequency error ${ERROR_HZ} Hz exceeds tolerance ${FREQ_TOLERANCE} Hz"
            fi
        fi
    else
        fail "T5.1  Audio capture from device failed"
        fail "T5.2  (skipped due to capture failure)"
    fi
else
    warn "T5.1  sox or python3 missing — frequency measurement skipped"
    warn "T5.2  (skipped)"
    SKIP_COUNT=$((SKIP_COUNT+2))
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 6 — Latency Check
# ═════════════════════════════════════════════════════════════════════════════

step "T6: Processing Latency"

LATENCY_PROP=$(adb_out getprop persist.audioshift.latency_ms || echo "")
if [[ -n "$LATENCY_PROP" ]]; then
    if python3 -c "import sys; sys.exit(0 if float('$LATENCY_PROP') < 20 else 1)" 2>/dev/null; then
        pass "T6.1  Reported latency: ${LATENCY_PROP} ms (< 20 ms target)"
    else
        fail "T6.1  Reported latency: ${LATENCY_PROP} ms (exceeds 20 ms target)"
    fi
else
    warn "T6.1  persist.audioshift.latency_ms not set (effect may not have processed audio yet)"
    SKIP_COUNT=$((SKIP_COUNT+1))
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 7 — Disable / Re-enable Toggle
# ═════════════════════════════════════════════════════════════════════════════

step "T7: Enable/Disable Toggle"

# T7.1 Disable via setprop
adb_ok "su -c 'resetprop persist.audioshift.enabled false'" && \
    pass "T7.1  Disabled via resetprop" || \
    fail "T7.1  Could not set persist.audioshift.enabled=false"

sleep 2

# T7.2 Check property reflected
ENABLED_AFTER=$(adb_out getprop persist.audioshift.enabled)
if [[ "$ENABLED_AFTER" == "false" ]]; then
    pass "T7.2  Property confirmed false"
else
    fail "T7.2  Property is '$ENABLED_AFTER', expected 'false'"
fi

# T7.3 Re-enable
adb_ok "su -c 'resetprop persist.audioshift.enabled true'" && \
    pass "T7.3  Re-enabled via resetprop" || \
    fail "T7.3  Could not re-enable"

# ═════════════════════════════════════════════════════════════════════════════
# TEST 8 — Cleanup
# ═════════════════════════════════════════════════════════════════════════════

step "T8: Cleanup"

if [[ "$NO_UNINSTALL" == "true" ]]; then
    info "      --no-uninstall set — leaving module installed"
    pass "T8.1  Module retained (as requested)"
else
    info "      Marking module for removal…"
    adb_ok "su -c 'touch /data/adb/modules/audioshift/remove'" && \
        pass "T8.1  Module marked for removal (takes effect on next reboot)" || \
        warn "T8.1  Could not create remove file — module may stay installed"
fi

# ─── Final Report ─────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗"
echo -e "║              TEST RESULTS SUMMARY                    ║"
echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
printf  "  Total tests:  %d\n" "$TOTAL"
printf  "  ${GREEN}Passed${RESET}:        %d\n" "$PASS_COUNT"
printf  "  ${RED}Failed${RESET}:        %d\n" "$FAIL_COUNT"
printf  "  ${YELLOW}Skipped${RESET}:       %d\n" "$SKIP_COUNT"
printf  "  Duration:      %ds\n" "$ELAPSED"
printf  "  Report dir:    %s\n" "$RESULTS_DIR"
echo

# Write summary JSON
python3 - <<SUMMARY_PY 2>/dev/null || true
import json, os
summary = {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "passed": $PASS_COUNT,
    "failed": $FAIL_COUNT,
    "skipped": $SKIP_COUNT,
    "duration_s": $ELAPSED,
    "verdict": "PASS" if $FAIL_COUNT == 0 else "FAIL"
}
with open("${RESULTS_DIR}/summary_$(date +%Y%m%d_%H%M%S).json", "w") as f:
    json.dump(summary, f, indent=2)
SUMMARY_PY

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓ ALL TESTS PASSED${RESET}"
    exit 0
else
    echo -e "  ${RED}${BOLD}✗ ${FAIL_COUNT} TEST(S) FAILED${RESET}"
    exit 1
fi
