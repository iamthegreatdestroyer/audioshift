#!/usr/bin/env bash
# =============================================================================
# setup_aosp_environment.sh — Provision Ubuntu 22.04 for AOSP (Android 16)
#
# SCOPE: AOSP source checkout + build toolchain for Galaxy S25+ (SM-S936B).
#        Supplements setup_environment.sh (NDK / dev tools) — run THAT first.
#
# USAGE:
#   chmod +x scripts/setup_aosp_environment.sh
#   ./scripts/setup_aosp_environment.sh [--skip-sync]
#
# OPTIONS:
#   --skip-sync    Skip `repo sync` (useful when source already checked out)
#
# REQUIREMENTS:
#   - Ubuntu 22.04 LTS (x86_64)
#   - 400 GB+ free disk (AOSP source ~250 GB, build artifacts ~100 GB)
#   - 32 GB RAM recommended (16 GB minimum with swap)
#   - Internet access for initial sync
#
# AOSP branch: android-16.0.0_r1
# Target device: Samsung Galaxy S25+ (s25plus / e3q)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AOSP_BRANCH="android-16.0.0_r1"
AOSP_ROOT="${HOME}/aosp"
MANIFEST_URL="https://android.googlesource.com/platform/manifest"
LOCAL_MANIFESTS_DIR="${AOSP_ROOT}/.repo/local_manifests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${HOME}/.local/bin"
CCACHE_DIR="${HOME}/.ccache"
CCACHE_SIZE="50G"
SYNC_JOBS=8
SKIP_SYNC=false

log()  { echo "[AOSP-SETUP] $*"; }
die()  { echo "[AOSP-SETUP][ERROR] $*" >&2; exit 1; }
warn() { echo "[AOSP-SETUP][WARN]  $*"; }

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "${arg}" in
        --skip-sync) SKIP_SYNC=true ;;
        *) die "Unknown argument: ${arg}" ;;
    esac
done

# ---------------------------------------------------------------------------
# 1. Root sanity check
# ---------------------------------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run as root. Run as a regular user with sudo access."
fi

# ---------------------------------------------------------------------------
# 2. OS check
# ---------------------------------------------------------------------------
if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
    warn "Not Ubuntu 22.04 — continuing, but this is untested."
fi

log "=== Stage 1: System packages ==="

sudo apt-get update -qq

AOSP_PACKAGES=(
    # Core build tools
    git git-core gnupg flex bison build-essential
    zip curl wget unzip zlib1g-dev
    # Python
    python3 python3-pip python3-setuptools
    # AOSP-specific
    libxml2-utils xsltproc ninja-build
    gcc-multilib g++-multilib libc6-dev-i386 lib32z1-dev
    libncurses5 libncurses5-dev
    lib32ncurses5-dev lib32readline-dev lib32z1
    # OpenSSL / crypto
    libssl-dev sshpass
    # Misc utilities
    rsync jq bc lsb-release software-properties-common
    # Java 17 (required for Android 16 build)
    openjdk-17-jdk openjdk-17-jre
    # Ccache
    ccache
    # Repo dependencies
    python-is-python3
)

sudo apt-get install -y --no-install-recommends "${AOSP_PACKAGES[@]}"

log "=== Stage 2: Java 17 default ==="
sudo update-java-alternatives --set java-1.17.0-openjdk-amd64 2>/dev/null || true
java -version 2>&1 | grep -q "17" || die "Java 17 not active after install."
log "Java 17 active: $(java -version 2>&1 | head -1)"

log "=== Stage 3: repo tool ==="
mkdir -p "${REPO_DIR}"
if [[ ! -f "${REPO_DIR}/repo" ]]; then
    curl -fsSL "https://storage.googleapis.com/git-repo-downloads/repo" \
        -o "${REPO_DIR}/repo"
    chmod a+x "${REPO_DIR}/repo"
    log "repo downloaded to ${REPO_DIR}/repo"
else
    log "repo already installed at ${REPO_DIR}/repo"
fi

# Ensure repo is on PATH
if ! echo "${PATH}" | grep -q "${REPO_DIR}"; then
    echo "export PATH=\"${REPO_DIR}:\$PATH\"" >> "${HOME}/.bashrc"
    export PATH="${REPO_DIR}:${PATH}"
fi

"${REPO_DIR}/repo" version || die "repo not functional."

log "=== Stage 4: ccache configuration ==="
mkdir -p "${CCACHE_DIR}"
ccache --max-size="${CCACHE_SIZE}"
ccache --set-config=compression=true
ccache --set-config=compression_level=6
log "ccache configured: dir=${CCACHE_DIR} max-size=${CCACHE_SIZE}"

# Add ccache env vars to .bashrc
if ! grep -q "USE_CCACHE" "${HOME}/.bashrc"; then
    cat >> "${HOME}/.bashrc" << 'EOF'

# AOSP ccache
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
EOF
fi
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

log "=== Stage 5: AOSP source directory ==="
mkdir -p "${AOSP_ROOT}"

log "=== Stage 6: git config for repo ==="
if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
    git config --global user.email "aosp-build@audioshift.local"
    git config --global user.name  "AudioShift AOSP Bot"
    log "git global config set (placeholder values — update if needed)"
fi
git config --global color.ui      false
git config --global http.postBuffer 524288000

log "=== Stage 7: repo init ==="
cd "${AOSP_ROOT}"
if [[ ! -d ".repo" ]]; then
    log "Initialising repo with branch ${AOSP_BRANCH}…"
    "${REPO_DIR}/repo" init \
        --no-clone-bundle \
        --depth=1 \
        -u "${MANIFEST_URL}" \
        -b "${AOSP_BRANCH}"
else
    log ".repo already exists — skipping repo init."
fi

log "=== Stage 8: Install AudioShift local manifest ==="
mkdir -p "${LOCAL_MANIFESTS_DIR}"
SRC_MANIFEST="${SCRIPT_DIR}/../path_b_rom/android/build/local_manifests/audioshift.xml"
DEST_MANIFEST="${LOCAL_MANIFESTS_DIR}/audioshift.xml"

if [[ -f "${SRC_MANIFEST}" ]]; then
    cp -v "${SRC_MANIFEST}" "${DEST_MANIFEST}"
    log "AudioShift local manifest installed to ${DEST_MANIFEST}"
else
    warn "AudioShift manifest not found at ${SRC_MANIFEST} — skipping."
fi

log "=== Stage 9: repo sync ==="
if [[ "${SKIP_SYNC}" == "true" ]]; then
    log "Skipping repo sync (--skip-sync passed)."
else
    log "Starting repo sync (jobs=${SYNC_JOBS}) — this may take 1–3 hours…"
    "${REPO_DIR}/repo" sync \
        --no-clone-bundle \
        --no-tags \
        --optimized-fetch \
        --prune \
        -j"${SYNC_JOBS}" \
        2>&1 | tee /tmp/repo_sync.log
    log "repo sync complete. Log: /tmp/repo_sync.log"
fi

log "=== Stage 10: Verify AOSP directories ==="
REQUIRED_DIRS=(
    "${AOSP_ROOT}/frameworks/av"
    "${AOSP_ROOT}/hardware/libhardware"
    "${AOSP_ROOT}/system/core"
)
for d in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "${d}" ]]; then
        log "  ✓  ${d}"
    else
        warn "  ✗  ${d} — not found (expected after sync)"
    fi
done

log ""
log "========================================================="
log "  AOSP environment ready."
log "  Source root : ${AOSP_ROOT}"
log "  Branch      : ${AOSP_BRANCH}"
log ""
log "  NEXT STEPS:"
log "  1. cd ${AOSP_ROOT}"
log "  2. source build/envsetup.sh"
log "  3. lunch aosp_s25plus-eng   (or -userdebug)"
log "  4. path_b_rom/build_scripts/apply_patches.sh ${AOSP_ROOT}"
log "  5. path_b_rom/build_scripts/build_rom.sh"
log "========================================================="
