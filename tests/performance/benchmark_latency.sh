#!/usr/bin/env bash
# =============================================================================
# AudioShift Latency Benchmark
# =============================================================================
# Measures the round-trip audio latency introduced by the 432 Hz pitch-shift
# effect vs. a bypass passthrough. Uses the AudioFlinger dump, system property
# reporting, and (when tinyloopback is available) hardware loopback timing.
#
# Usage:
#   ./benchmark_latency.sh                 # 10-sample run
#   ./benchmark_latency.sh --samples 30    # custom sample count
#   ./benchmark_latency.sh --csv out.csv   # export raw data
#   ./benchmark_latency.sh --compare       # run bypass vs. enabled comparison
#
# Requirements:
#   - adb connected, device rooted with Magisk
#   - AudioShift module installed
#   - tinycap / tinyplay on device
#   - python3 + numpy on host for statistics
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="${REPO_ROOT}/tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CSV_OUT=""
SAMPLES=10
COMPARE_MODE=false
TARGET_MS=20          # Maximum acceptable added latency
WARMUP_SAMPLES=3      # Discard initial startup transients

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; RESET='\033[0m'; BOLD='\033[1m'

info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
pass()  { echo -e "${GREEN}[PASS]${RESET}  $*"; }
fail()  { echo -e "${RED}[FAIL]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
header(){ echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

# ─── Argument parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --samples)  SAMPLES="$2"; shift ;;
        --csv)      CSV_OUT="$2"; shift ;;
        --compare)  COMPARE_MODE=true ;;
        -h|--help)
            sed -n '3,20p' "$0"; exit 0 ;;
        *)  echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

mkdir -p "$RESULTS_DIR"
[[ -z "$CSV_OUT" ]] && CSV_OUT="${RESULTS_DIR}/latency_${TIMESTAMP}.csv"

# ─── Helpers ─────────────────────────────────────────────────────────────────

adb_out() { adb shell "$@" 2>/dev/null || true; }

require_device() {
    if ! adb devices | grep -q "device$"; then
        echo "[ERROR] No ADB device connected."
        exit 1
    fi
}

# ─── Method 1: System Property (effect self-reports latency) ─────────────────

measure_from_property() {
    local label="$1"
    local samples="$2"
    local values=()

    info "Reading latency from persist.audioshift.latency_ms…"

    # Trigger some audio activity so the effect updates its stat
    adb shell "tinyplay /sdcard/audioshift_test_tone.wav" > /dev/null 2>&1 &
    ADB_PID=$!
    sleep 0.5

    for ((i=1; i<=samples; i++)); do
        local latency
        latency=$(adb_out getprop persist.audioshift.latency_ms)
        if [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            values+=("$latency")
            printf "  Sample %2d/%d: %s ms\n" "$i" "$samples" "$latency"
        else
            printf "  Sample %2d/%d: -- (property not updated yet)\n" "$i" "$samples"
        fi
        sleep 0.2
    done

    kill "$ADB_PID" 2>/dev/null || true
    wait "$ADB_PID" 2>/dev/null || true

    echo "${values[@]+"${values[@]}"}"
}

# ─── Method 2: tinycap round-trip timing ─────────────────────────────────────

measure_roundtrip_tinycap() {
    local label="$1"
    local samples="$2"
    local values=()

    local tone_wav="${RESULTS_DIR}/bench_tone.wav"
    info "Generating 440 Hz tone for loopback measurement…"
    sox -n -r 48000 -c 2 "$tone_wav" synth 2 sine 440 gain -3 2>/dev/null || {
        warn "sox not available — skipping tinycap round-trip"
        return
    }

    adb push "$tone_wav" /sdcard/audioshift_bench_tone.wav > /dev/null

    for ((i=1; i<=samples; i++)); do
        # Timestamp before playback
        local t_start
        t_start=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)

        # Play + capture on device, measure time until capture has first non-zero
        adb shell "tinyplay /sdcard/audioshift_bench_tone.wav &
                   tinycap /sdcard/bench_cap.pcm -D 0 -d 0 -r 48000 -b 16 -c 2 -p 256 -n 2 &
                   sleep 1.5; kill %1 %2 2>/dev/null; wait 2>/dev/null; true" > /dev/null 2>&1 || true

        local t_end
        t_end=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)

        # Pull and check captured PCM for first non-silent frame
        local cap="${RESULTS_DIR}/bench_cap_${i}.pcm"
        adb pull /sdcard/bench_cap.pcm "$cap" > /dev/null 2>&1 || continue

        # Python: find first non-zero sample offset → latency estimate
        local latency
        latency=$(python3 << PYEOF 2>/dev/null || echo ""
import numpy as np, os, sys
cap = np.frombuffer(open("$cap", "rb").read(), dtype=np.int16)
# Find first sample above noise floor
thresh = 1000  # about 3% of int16 max
nonzero = np.where(np.abs(cap) > thresh)[0]
if len(nonzero) == 0:
    sys.exit(0)
first_sample = nonzero[0]
# Latency = first_sample / (sample_rate * channels)
latency_ms = (first_sample / (48000 * 2)) * 1000
print(f"{latency_ms:.1f}")
PYEOF
)
        if [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            values+=("$latency")
            printf "  Sample %2d/%d: %s ms\n" "$i" "$samples" "$latency"
        else
            printf "  Sample %2d/%d: -- (no signal detected in capture)\n" "$i" "$samples"
        fi
    done

    echo "${values[@]+"${values[@]}"}"
}

# ─── Statistics ───────────────────────────────────────────────────────────────

compute_stats() {
    local label="$1"
    shift
    local values=("$@")

    if [[ ${#values[@]} -eq 0 ]]; then
        echo "  No measurements available."
        return 1
    fi

    python3 << PYEOF
import statistics, sys
values = [float(v) for v in ${values[@]/#/[} ${values[@]/%/,}]]
# Remove warmup
if len(values) > $WARMUP_SAMPLES:
    values = values[$WARMUP_SAMPLES:]
if not values:
    print("  Not enough samples after warmup discard.")
    sys.exit(1)
mean   = statistics.mean(values)
median = statistics.median(values)
stdev  = statistics.stdev(values) if len(values) > 1 else 0
p95    = sorted(values)[int(len(values)*0.95)]
mn     = min(values)
mx     = max(values)
print(f"  Label:   {repr('$label')}")
print(f"  Samples: {len(values)} (after {$WARMUP_SAMPLES} warmup)")
print(f"  Mean:    {mean:.2f} ms")
print(f"  Median:  {median:.2f} ms")
print(f"  Stdev:   {stdev:.2f} ms")
print(f"  P95:     {p95:.2f} ms")
print(f"  Min:     {mn:.2f} ms")
print(f"  Max:     {mx:.2f} ms")
target = $TARGET_MS
verdict = "PASS" if mean < target else "FAIL"
print(f"  Target:  < {target} ms")
print(f"  Verdict: {verdict}")
PYEOF
}

save_csv() {
    local label="$1"
    shift
    local values=("$@")
    local wrote_header=false

    if [[ ! -f "$CSV_OUT" ]]; then
        echo "timestamp,label,sample_index,latency_ms" > "$CSV_OUT"
    fi

    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local idx=1
    for v in "${values[@]}"; do
        echo "${ts},${label},${idx},${v}" >> "$CSV_OUT"
        idx=$((idx+1))
    done
}

# ─── Main ─────────────────────────────────────────────────────────────────────

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗"
echo    "║       AudioShift Latency Benchmark                    ║"
echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
echo    "  Samples:   $SAMPLES (+ $WARMUP_SAMPLES warmup discarded)"
echo    "  Target:    < ${TARGET_MS} ms added latency"
echo    "  CSV:       $CSV_OUT"
echo

require_device

# ═══════════════════════════════════════════════════════════════════════════
# Phase A: Self-Reported Latency (persist.audioshift.latency_ms)
# ═══════════════════════════════════════════════════════════════════════════

header "Phase A: Self-Reported Latency (AudioShift property)"

# Ensure effect is enabled
adb shell "su -c 'resetprop persist.audioshift.enabled true'" > /dev/null 2>&1 || true

if ! adb_out getprop persist.audioshift.enabled | grep -q "true"; then
    warn "persist.audioshift.enabled is not 'true' — module may not be installed"
fi

# Warm up
info "Warming up effect (${WARMUP_SAMPLES} warmup samples)…"
adb push "${RESULTS_DIR}/bench_tone.wav" /sdcard/audioshift_bench_tone.wav > /dev/null 2>&1 || \
    sox -n -r 48000 -c 2 "${RESULTS_DIR}/bench_tone.wav" synth 2 sine 440 gain -3 2>/dev/null || true

mapfile -t PROP_VALUES < <(measure_from_property "enabled" "$((SAMPLES + WARMUP_SAMPLES))" | tr ' ' '\n')

echo
compute_stats "audioshift_enabled" "${PROP_VALUES[@]}" || true
save_csv "property_enabled" "${PROP_VALUES[@]}" || true

# ═══════════════════════════════════════════════════════════════════════════
# Phase B: Round-Trip Timing via tinycap
# ═══════════════════════════════════════════════════════════════════════════

header "Phase B: Round-Trip Latency via tinycap"

if command -v sox &>/dev/null && command -v python3 &>/dev/null; then
    mapfile -t RT_ENABLED < <(measure_roundtrip_tinycap "enabled" "$SAMPLES" | tr ' ' '\n')
    echo
    compute_stats "roundtrip_enabled" "${RT_ENABLED[@]}" || true
    save_csv "roundtrip_enabled" "${RT_ENABLED[@]}" || true
else
    warn "sox or python3 not installed — skipping round-trip measurement"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Phase C: Bypass Comparison (if --compare)
# ═══════════════════════════════════════════════════════════════════════════

if [[ "$COMPARE_MODE" == "true" ]]; then
    header "Phase C: Bypass Comparison"

    info "Disabling AudioShift effect…"
    adb shell "su -c 'resetprop persist.audioshift.enabled false'" > /dev/null 2>&1 || {
        warn "Could not disable effect — skipping comparison"
    }
    sleep 2

    mapfile -t RT_BYPASS < <(measure_roundtrip_tinycap "bypass" "$SAMPLES" | tr ' ' '\n')
    echo
    compute_stats "roundtrip_bypass" "${RT_BYPASS[@]}" || true
    save_csv "roundtrip_bypass" "${RT_BYPASS[@]}" || true

    # Re-enable
    adb shell "su -c 'resetprop persist.audioshift.enabled true'" > /dev/null 2>&1 || true
    info "AudioShift effect re-enabled."

    # Delta computation
    if [[ ${#RT_ENABLED[@]} -gt 0 && ${#RT_BYPASS[@]} -gt 0 ]] && command -v python3 &>/dev/null; then
        header "Phase D: Added Latency (Effect − Bypass)"
        python3 << DELTAPY
import statistics
enabled = [float(v) for v in "${RT_ENABLED[*]}".split() if v]
bypass  = [float(v) for v in "${RT_BYPASS[*]}".split()  if v]
if not enabled or not bypass:
    print("  Insufficient data for comparison.")
else:
    added = statistics.mean(enabled) - statistics.mean(bypass)
    print(f"  Mean (enabled): {statistics.mean(enabled):.2f} ms")
    print(f"  Mean (bypass):  {statistics.mean(bypass):.2f} ms")
    print(f"  Added latency:  {added:.2f} ms")
    verdict = "PASS" if added < $TARGET_MS else "FAIL"
    colour = "\033[1;32m" if verdict == "PASS" else "\033[1;31m"
    print(f"  Verdict:        {colour}{verdict}\033[0m  (target < ${TARGET_MS} ms)")
DELTAPY
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# Final summary
# ═══════════════════════════════════════════════════════════════════════════

header "Results Exported"
echo    "  CSV:  $CSV_OUT"
echo    "  Dir:  $RESULTS_DIR"

# Quick pass/fail from self-reported prop (most reliable single number)
if [[ ${#PROP_VALUES[@]} -gt $WARMUP_SAMPLES ]]; then
    MEAN_LATENCY=$(python3 -c "
import statistics
vals = [float(v) for v in '${PROP_VALUES[*]}'.split()[$WARMUP_SAMPLES:] if v]
print(f'{statistics.mean(vals):.1f}' if vals else '?')
" 2>/dev/null || echo "?")
    echo
    if python3 -c "import sys; sys.exit(0 if float('${MEAN_LATENCY:-99}') < $TARGET_MS else 1)" 2>/dev/null; then
        pass "Mean self-reported latency ${MEAN_LATENCY} ms < ${TARGET_MS} ms target"
        exit 0
    else
        fail "Mean self-reported latency ${MEAN_LATENCY} ms ≥ ${TARGET_MS} ms target"
        exit 1
    fi
fi

echo
info "Benchmark complete."
