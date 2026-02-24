#!/usr/bin/env bash
# =============================================================================
# apply_patches.sh — AudioShift Track 2 : Patch AOSP Source Tree
# =============================================================================
#
# Purpose (MASTER_ACTION_PLAN.md §2.3):
#   Copies AudioShift source files and configuration into a checked-out AOSP
#   source tree and applies the kernel DSP patch.  Run this ONCE after
#   `repo sync` and BEFORE running build_rom.sh.
#
# Usage:
#   ./apply_patches.sh [--aosp-root <path>] [--repo-root <path>] [--dry-run]
#
# Options:
#   --aosp-root   Path to AOSP source checkout  (default: $HOME/aosp)
#   --repo-root   Path to this git repository   (default: auto-detected)
#   --dry-run     Print actions without executing them
#   --force       Overwrite existing files without prompting
#
# Example:
#   cd /path/to/audioshift
#   ./path_b_rom/build_scripts/apply_patches.sh
#
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${CYAN}[INFO ]${RESET} $*"; }
ok()    { echo -e "${GREEN}[ OK  ]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN ]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
bail()  { error "$*"; exit 1; }

# ── Parse arguments ───────────────────────────────────────────────────────────
AOSP_ROOT="${AOSP_ROOT:-$HOME/aosp}"
DRY_RUN=false
FORCE=false

# Auto-detect repository root (the directory that contains path_b_rom/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --aosp-root) AOSP_ROOT="$2"; shift 2 ;;
        --repo-root) REPO_ROOT="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true;  shift ;;
        --force)     FORCE=true;    shift ;;
        -h|--help)
            sed -n '/^# Usage/,/^# ─/p' "$0" | head -n -1
            exit 0 ;;
        *) bail "Unknown option: $1" ;;
    esac
done

# ── Dry-run wrapper ───────────────────────────────────────────────────────────
run() {
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY ]${RESET} $*"
    else
        "$@"
    fi
}

# ── Source paths (in this repo) ───────────────────────────────────────────────
PATH_B="${REPO_ROOT}/path_b_rom"

SRC_EFFECT_H="${PATH_B}/android/frameworks/av/services/audioflinger/AudioShift432Effect.h"
SRC_EFFECT_CPP="${PATH_B}/android/frameworks/av/services/audioflinger/AudioShift432Effect.cpp"
SRC_ANDROID_BP="${PATH_B}/android/frameworks/av/services/audioflinger/Android.bp"
SRC_HAL_HEADER="${REPO_ROOT}/path_b_rom/android/hardware/libhardware/audio_effect_432hz.h"
SRC_KERNEL_PATCH="${PATH_B}/kernel/audioshift_dsp.patch"
SRC_DEVICE_DIR="${PATH_B}/android/device/samsung/s25plus"
SRC_AUDIO_POLICY_XML="${PATH_B}/device_configs/audio_policy_configuration.xml"
SRC_MIXER_PATHS_XML="${PATH_B}/device_configs/mixer_paths.xml"

# ── Destination paths (in AOSP checkout) ──────────────────────────────────────
DST_AUDIOFLINGER="${AOSP_ROOT}/frameworks/av/services/audioflinger"
DST_HAL_INCLUDE="${AOSP_ROOT}/hardware/libhardware/include/hardware"
DST_KERNEL="${AOSP_ROOT}/kernel/samsung/s25plus"
DST_DEVICE="${AOSP_ROOT}/device/samsung/s25plus"
DST_VENDOR_AUDIO="${AOSP_ROOT}/device/samsung/s25plus/vendor/etc/audio"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║    AudioShift Track 2 — AOSP Patch Application Script       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
info "Repository root : ${REPO_ROOT}"
info "AOSP root       : ${AOSP_ROOT}"
$DRY_RUN && warn "DRY-RUN mode: no files will be modified"
echo
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 0 — Pre-flight checks
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 0 — Pre-flight checks"

[[ -d "${AOSP_ROOT}" ]] || \
    bail "AOSP root not found: ${AOSP_ROOT}\n  Run setup_aosp_environment.sh first."
[[ -f "${AOSP_ROOT}/.repo/manifest.xml" ]] || \
    bail "No .repo found in ${AOSP_ROOT} — repo sync may not have completed."

for f in "${SRC_EFFECT_H}" "${SRC_EFFECT_CPP}" "${SRC_ANDROID_BP}" \
          "${SRC_KERNEL_PATCH}" "${SRC_AUDIO_POLICY_XML}" "${SRC_MIXER_PATHS_XML}"; do
    [[ -f "$f" ]] || bail "Source file missing: $f"
done

ok "Pre-flight passed"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 1 — Copy AudioShift effect sources → frameworks/av/services/audioflinger
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 1 — Copy AudioShift432Effect sources → audioflinger"

run mkdir -p "${DST_AUDIOFLINGER}"

for src in "${SRC_EFFECT_H}" "${SRC_EFFECT_CPP}"; do
    dst="${DST_AUDIOFLINGER}/$(basename "$src")"
    if [[ -f "$dst" ]] && ! $FORCE; then
        warn "  Already exists (use --force to overwrite): ${dst}"
    else
        info "  cp ${src} → ${dst}"
        run cp -v "$src" "$dst"
    fi
done
ok "Stage 1 complete"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 2 — Merge AudioShift entry into frameworks/av/…/Android.bp
#
# Strategy: If the AudioShift sources are not yet referenced in the upstream
# Android.bp, append the AudioShift static library target block.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 2 — Merge audioshift entry into Android.bp"

DST_BP="${DST_AUDIOFLINGER}/Android.bp"

if [[ ! -f "${DST_BP}" ]]; then
    warn "  ${DST_BP} not found — copying AudioShift Android.bp verbatim"
    run cp -v "${SRC_ANDROID_BP}" "${DST_BP}"
else
    if grep -q "AudioShift432Effect" "${DST_BP}" 2>/dev/null; then
        warn "  AudioShift already present in Android.bp — skipping"
    else
        info "  Appending AudioShift targets to ${DST_BP}"
        AUDIOSHIFT_BP_SNIPPET='
// ──────────────────────────────────────────────────────────────────────────
// AudioShift 432Hz — injected by apply_patches.sh (Track 2)
// ──────────────────────────────────────────────────────────────────────────
cc_library_shared {
    name: "libaudioshift432",
    srcs: [
        "AudioShift432Effect.cpp",
    ],
    shared_libs: [
        "liblog",
        "libcutils",
        "libhardware",
        "libeffects",
    ],
    cflags: [
        "-Wall",
        "-Werror",
        "-DAUDIOSHIFT_VERSION=\"2.0.0\"",
        "-DAUDIOSHIFT_PITCH_CENTS=-52",
    ],
    export_include_dirs: ["."],
}
'
        if $DRY_RUN; then
            echo -e "  ${YELLOW}[DRY ]${RESET} Would append AudioShift targets to ${DST_BP}"
        else
            echo "${AUDIOSHIFT_BP_SNIPPET}" >> "${DST_BP}"
        fi
    fi
fi
ok "Stage 2 complete"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 3 — Copy HAL header → hardware/libhardware/include/hardware
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 3 — Copy HAL header → ${DST_HAL_INCLUDE}"

if [[ -f "${SRC_HAL_HEADER}" ]]; then
    run mkdir -p "${DST_HAL_INCLUDE}"
    dst_hal="${DST_HAL_INCLUDE}/audio_effect_432hz.h"
    if [[ -f "${dst_hal}" ]] && ! $FORCE; then
        warn "  Already exists (use --force to overwrite): ${dst_hal}"
    else
        info "  cp ${SRC_HAL_HEADER} → ${dst_hal}"
        run cp -v "${SRC_HAL_HEADER}" "${dst_hal}"
    fi
    ok "Stage 3 complete"
else
    warn "HAL header not found at ${SRC_HAL_HEADER} — skipping (non-fatal)"
fi
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 4 — Apply kernel DSP patch via git am
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 4 — Apply kernel patch: audioshift_dsp.patch"

if [[ ! -d "${DST_KERNEL}" ]]; then
    warn "  Kernel source not found at ${DST_KERNEL}"
    warn "  Ensure 'repo sync' has fetched kernel/samsung/s25plus"
    warn "  Skipping kernel patch (non-fatal — patch manually later)"
else
    pushd "${DST_KERNEL}" > /dev/null

    # Check if already applied by looking for the introduced file
    if [[ -d "sound/soc/qcom/audioshift" ]]; then
        warn "  audioshift kernel patch appears already applied — skipping"
    else
        # Attempt git am (clean, rebased patch)
        if $DRY_RUN; then
            info "  [DRY] git am ${SRC_KERNEL_PATCH}"
        else
            if git am --check "${SRC_KERNEL_PATCH}" 2>/dev/null; then
                run git am "${SRC_KERNEL_PATCH}"
                ok "  Kernel patch applied via git am"
            else
                warn "  git am checks failed — falling back to 'patch -p1'"
                run patch -p1 --forward < "${SRC_KERNEL_PATCH}" || \
                    warn "  patch returned non-zero (may already be applied)"
            fi
        fi
    fi

    popd > /dev/null
    ok "Stage 4 complete"
fi
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 5 — Copy device tree files → device/samsung/s25plus
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 5 — Copy device tree → ${DST_DEVICE}"

run mkdir -p "${DST_DEVICE}"

# Device-tree Makefile + config files
for f in Android.mk BoardConfig.mk audioshift_product.mk audioshift.prop \
          audio_policy_configuration.xml; do
    src="${SRC_DEVICE_DIR}/${f}"
    dst="${DST_DEVICE}/${f}"
    if [[ ! -f "${src}" ]]; then
        warn "  Source missing: ${src} — skipping"
        continue
    fi
    if [[ -f "${dst}" ]] && ! $FORCE; then
        warn "  Already exists (use --force): ${dst}"
    else
        info "  cp ${src} → ${dst}"
        run cp -v "${src}" "${dst}"
    fi
done

# Vendor audio configs
run mkdir -p "${DST_VENDOR_AUDIO}"
for xml in "${SRC_AUDIO_POLICY_XML}" "${SRC_MIXER_PATHS_XML}"; do
    dst_xml="${DST_VENDOR_AUDIO}/$(basename "$xml")"
    if [[ -f "${dst_xml}" ]] && ! $FORCE; then
        warn "  Already exists (use --force): ${dst_xml}"
    else
        info "  cp ${xml} → ${dst_xml}"
        run cp -v "${xml}" "${dst_xml}"
    fi
done

ok "Stage 5 complete"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 6 — Verification
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
info "STAGE 6 — Verification"

PASS=0; WARN=0

check_exists() {
    local path="$1"; local label="$2"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY ]${RESET} Would verify: ${path}"
        return
    fi
    if [[ -e "${path}" ]]; then
        ok "  [✓] ${label}"
        ((PASS++)); true
    else
        warn "  [✗] ${label} NOT FOUND: ${path}"
        ((WARN++)); false
    fi
}

check_exists "${DST_AUDIOFLINGER}/AudioShift432Effect.h"    "AudioShift432Effect.h"
check_exists "${DST_AUDIOFLINGER}/AudioShift432Effect.cpp"  "AudioShift432Effect.cpp"
check_exists "${DST_HAL_INCLUDE}/audio_effect_432hz.h"      "HAL header" || true
check_exists "${DST_DEVICE}/BoardConfig.mk"                 "BoardConfig.mk"
check_exists "${DST_DEVICE}/audioshift_product.mk"          "audioshift_product.mk"
check_exists "${DST_VENDOR_AUDIO}/audio_policy_configuration.xml" "audio_policy_configuration.xml"
check_exists "${DST_VENDOR_AUDIO}/mixer_paths.xml"          "mixer_paths.xml"

# Check that audioshift entry appears in Android.bp
if ! $DRY_RUN && [[ -f "${DST_BP}" ]]; then
    if grep -q "libaudioshift432\|AudioShift432" "${DST_BP}"; then
        ok "  [✓] Android.bp contains AudioShift entry"
        ((PASS++))
    else
        warn "  [✗] Android.bp does NOT contain AudioShift entry"
        ((WARN++))
    fi
fi

# Check kernel patch
if ! $DRY_RUN && [[ -d "${DST_KERNEL}/sound/soc/qcom/audioshift" ]]; then
    ok "  [✓] Kernel audioshift module directory present"
    ((PASS++))
fi

echo
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
if [[ $WARN -eq 0 && ! $DRY_RUN ]]; then
    echo -e "${GREEN}${BOLD}  All verification checks passed (${PASS} checks).${RESET}"
else
    echo -e "${YELLOW}${BOLD}  Verification: ${PASS} passed, ${WARN} warnings.${RESET}"
    echo   "  Warnings are non-fatal for a first-time patch run."
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo

# ─────────────────────────────────────────────────────────────────────────────
info "Patch application complete."
info "Next step: run build_rom.sh to compile the AudioShift custom ROM."
info "  cd ${AOSP_ROOT}"
info "  source build/envsetup.sh"
info "  lunch aosp_s25plus-user"
info "  ${REPO_ROOT}/path_b_rom/build_scripts/build_rom.sh"
