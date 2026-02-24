#!/usr/bin/env bash
# AudioShift — Regression Suite Orchestrator
# Runs: host unit tests → latency bench → (optional) ADB device integration
# Emits: tests/results/regression_<TIMESTAMP>.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$ROOT_DIR/tests/results"
RESULTS_FILE="$RESULTS_DIR/regression_${TIMESTAMP}.json"

mkdir -p "$RESULTS_DIR"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; }
info() { echo "[INFO] $*"; }

PASS_COUNT=0
FAIL_COUNT=0
declare -A RESULTS

run_stage() {
    local name="$1"; shift
    info "Running: $name"
    if "$@"; then
        RESULTS["$name"]="pass"
        PASS_COUNT=$((PASS_COUNT + 1))
        pass "$name"
    else
        RESULTS["$name"]="fail"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        fail "$name"
    fi
}

# ── Stage 1: Host Unit Tests ──────────────────────────────────────────────────
UNIT_BUILD="$ROOT_DIR/tests/unit/build"
if [[ ! -d "$UNIT_BUILD" ]]; then
    cmake -B "$UNIT_BUILD" -S "$ROOT_DIR/tests/unit" -DCMAKE_BUILD_TYPE=Release -G Ninja
fi
cmake --build "$UNIT_BUILD" --parallel "$(nproc 2>/dev/null || echo 4)"
run_stage "host_unit_tests" "$UNIT_BUILD/audioshift_unit_tests"

# ── Stage 2: Latency Benchmark ────────────────────────────────────────────────
BENCH_BUILD="$ROOT_DIR/tests/performance/build"
if [[ ! -d "$BENCH_BUILD" ]]; then
    cmake -B "$BENCH_BUILD" -S "$ROOT_DIR/tests/performance" -DCMAKE_BUILD_TYPE=Release -G Ninja
fi
cmake --build "$BENCH_BUILD" --parallel "$(nproc 2>/dev/null || echo 4)"
run_stage "latency_bench" "$BENCH_BUILD/bench_latency"

# ── Stage 3: ADB Integration (optional) ──────────────────────────────────────
if command -v adb &>/dev/null && adb devices | grep -q "device$"; then
    info "ADB device detected — running integration tests"
    run_stage "device_integration" bash "$ROOT_DIR/tests/integration/test_432hz_device.sh"
else
    RESULTS["device_integration"]="skip"
    info "No ADB device detected — skipping device integration tests"
fi

# ── Emit JSON ─────────────────────────────────────────────────────────────────
{
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$TIMESTAMP"
    printf '  "pass": %d,\n' "$PASS_COUNT"
    printf '  "fail": %d,\n' "$FAIL_COUNT"
    printf '  "results": {\n'
    first=true
    for key in "${!RESULTS[@]}"; do
        [[ "$first" == true ]] || printf ',\n'
        printf '    "%s": "%s"' "$key" "${RESULTS[$key]}"
        first=false
    done
    printf '\n  }\n'
    printf '}\n'
} > "$RESULTS_FILE"

info "Results written to: $RESULTS_FILE"

# ── Exit code ─────────────────────────────────────────────────────────────────
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    fail "Regression suite FAILED ($FAIL_COUNT failure(s))"
    exit 1
fi
pass "Regression suite PASSED ($PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)))"
