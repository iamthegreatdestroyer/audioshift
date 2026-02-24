#!/usr/bin/env bash
# =============================================================================
# setup_selfhosted_runner.sh — Track 3.1: GitHub Actions Self-Hosted Runner
# AudioShift Project
#
# PURPOSE
#   Registers this development machine as a GitHub Actions self-hosted runner
#   labelled `android-device` so that the `device_test` CI job can execute
#   on-device tests against a connected Samsung Galaxy S25+.
#
# USAGE
#   1. Connect the Galaxy S25+ via USB with USB debugging enabled.
#   2. Generate a runner registration token in GitHub:
#        Repo → Settings → Actions → Runners → New self-hosted runner
#   3. Run this script:
#        bash scripts/setup_selfhosted_runner.sh --token <REGISTRATION_TOKEN>
#
# REQUIREMENTS
#   • Linux x64 host (WSL2 on Windows is supported)
#   • ADB installed and in PATH
#   • curl, tar, sudo access
#   • Samsung Galaxy S25+ with:
#       - Developer Options enabled
#       - USB Debugging enabled
#       - Authorised host fingerprint accepted on device
#
# RUNNER LABELS (must match .github/workflows/build_and_test.yml)
#   android-device   — consumed by `device_test` CI job
#
# RUNNER NAME (default)
#   audioshift-device-runner
# =============================================================================
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
head()  { echo ""; echo -e "${CYAN}${BOLD}════ $* ════${NC}"; }
die()   { error "$*"; exit 1; }

# ── Defaults ─────────────────────────────────────────────────────────────────
RUNNER_VERSION="2.317.0"
RUNNER_ARCH="linux-x64"
RUNNER_TARBALL="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TARBALL}"

REPO_URL="https://github.com/iamthegreatdestroyer/audioshift"
RUNNER_LABEL="android-device"
RUNNER_NAME="audioshift-device-runner"
RUNNER_DIR="${HOME}/actions-runner"
REGISTRATION_TOKEN=""

# ── CLI args ─────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)        REGISTRATION_TOKEN="$2"; shift 2 ;;
    --runner-dir)   RUNNER_DIR="$2"; shift 2 ;;
    --runner-name)  RUNNER_NAME="$2"; shift 2 ;;
    --runner-ver)   RUNNER_VERSION="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,35p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# =============================================================================
# PHASE 1: Pre-flight Checks
# =============================================================================
head "Phase 1/5 — Pre-flight Checks"

# ── ADB ──────────────────────────────────────────────────────────────────────
if ! command -v adb &>/dev/null; then
  die "ADB not found in PATH. Install Android Platform Tools:
  Ubuntu/Debian : sudo apt-get install android-tools-adb
  macOS/Homebrew: brew install android-platform-tools
  Windows WSL2  : install Android Platform Tools in Windows and add to PATH"
fi
ADB_VERSION=$(adb version | head -1)
ok "ADB found: ${ADB_VERSION}"

# ── Device check ─────────────────────────────────────────────────────────────
info "Listing connected Android devices..."
adb devices

DEVICE_COUNT=$(adb devices | grep -c "device$" || true)
if [[ "${DEVICE_COUNT}" -eq 0 ]]; then
  warn "No authorised Android device detected."
  warn "Ensure USB debugging is enabled and you have accepted the host key on the device."
  warn "Continuing with runner registration — device can be connected later."
else
  ok "${DEVICE_COUNT} device(s) detected"
  adb shell getprop ro.product.model 2>/dev/null \
    | while read -r model; do info "  Connected: ${model}"; done
fi

# ── curl / tar ───────────────────────────────────────────────────────────────
command -v curl &>/dev/null || die "curl is required. sudo apt-get install curl"
command -v tar  &>/dev/null || die "tar is required"
ok "curl and tar available"

# ── Token ─────────────────────────────────────────────────────────────────────
if [[ -z "${REGISTRATION_TOKEN}" ]]; then
  warn "No registration token provided."
  warn ""
  warn "To generate a token:"
  warn "  1. Go to: ${REPO_URL}/settings/actions/runners/new"
  warn "  2. Copy the token shown under 'Configure' step"
  warn "  3. Re-run: bash scripts/setup_selfhosted_runner.sh --token <TOKEN>"
  warn ""
  warn "The token is single-use and expires after 1 hour."
  echo ""
  echo -n "Paste the token now (or Ctrl+C to abort): "
  read -r REGISTRATION_TOKEN
fi
[[ -n "${REGISTRATION_TOKEN}" ]] || die "Registration token is required."

# =============================================================================
# PHASE 2: Download Runner
# =============================================================================
head "Phase 2/5 — Download GitHub Actions Runner v${RUNNER_VERSION}"

mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

if [[ -f "${RUNNER_TARBALL}" ]]; then
  info "Archive already present — skipping download"
else
  info "Downloading from: ${RUNNER_URL}"
  curl -OL "${RUNNER_URL}"
fi

if [[ ! -f "run.sh" ]]; then
  info "Extracting ${RUNNER_TARBALL}..."
  tar xzf "${RUNNER_TARBALL}"
  ok "Extracted to ${RUNNER_DIR}"
else
  ok "Runner already extracted"
fi

# =============================================================================
# PHASE 3: Configure Runner
# =============================================================================
head "Phase 3/5 — Configure Runner"

info "Repository : ${REPO_URL}"
info "Name       : ${RUNNER_NAME}"
info "Labels     : ${RUNNER_LABEL}"
info "Directory  : ${RUNNER_DIR}"

./config.sh \
  --url    "${REPO_URL}" \
  --token  "${REGISTRATION_TOKEN}" \
  --name   "${RUNNER_NAME}" \
  --labels "${RUNNER_LABEL}" \
  --work   "_work" \
  --unattended \
  --replace

ok "Runner configured"

# =============================================================================
# PHASE 4: Install as System Service
# =============================================================================
head "Phase 4/5 — Install System Service"

if [[ -f "./svc.sh" ]]; then
  info "Installing runner as a system service (sudo required)..."
  sudo ./svc.sh install
  sudo ./svc.sh start
  ok "Runner service installed and started"
  sudo ./svc.sh status
else
  warn "svc.sh not found — skipping service installation."
  warn "To start the runner manually:"
  warn "  cd ${RUNNER_DIR} && ./run.sh"
fi

# =============================================================================
# PHASE 5: Post-Installation Verification
# =============================================================================
head "Phase 5/5 — Verification"

echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Self-Hosted Runner Setup Complete${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Runner   : ${RUNNER_NAME}"
echo "  Labels   : ${RUNNER_LABEL}"
echo "  Directory: ${RUNNER_DIR}"
echo "  Repo     : ${REPO_URL}"
echo ""
echo -e "${BOLD}Verify at:${NC}"
echo "  ${REPO_URL}/settings/actions/runners"
echo ""
echo -e "${BOLD}Trigger the device_test CI job:${NC}"
echo "  1. Push a commit to main, OR"
echo "  2. GitHub Actions → build_and_test → Run workflow → main"
echo ""
echo -e "${BOLD}ADB check before each CI run:${NC}"
echo "  adb devices   # S25+ must appear as 'device', not 'unauthorized'"
echo ""

# ── Quick ADB connectivity validation ────────────────────────────────────────
info "Current ADB device status:"
adb devices
echo ""

DEVICE_COUNT=$(adb devices | grep -c "device$" || true)
if [[ "${DEVICE_COUNT}" -gt 0 ]]; then
  ok "Device connected — CI pipeline ready"
else
  warn "No device detected — connect Galaxy S25+ before triggering device_test job"
fi

# =============================================================================
# TROUBLESHOOTING NOTES
# =============================================================================
# ── Device not detected ────────────────────────────────────────────────────
# 1. Unlock the device and accept the "Allow USB debugging" dialog for this host
# 2. adb kill-server && adb start-server && adb devices
# 3. On WSL2: ensure `ANDROID_ADB_SERVER_PORT` env var is not conflicting
#
# ── Runner appears offline in GitHub ──────────────────────────────────────
# sudo ${RUNNER_DIR}/svc.sh status
# sudo ${RUNNER_DIR}/svc.sh start
# If using manual run.sh mode: check ${RUNNER_DIR}/_diag/ logs
#
# ── Runner token expired ──────────────────────────────────────────────────
# Tokens expire after 1 hour. Generate a new one:
#   Repo → Settings → Actions → Runners → (runner name) → Re-register
# Then re-run: bash scripts/setup_selfhosted_runner.sh --token <NEW_TOKEN>
#
# ── Change runner version ─────────────────────────────────────────────────
# bash scripts/setup_selfhosted_runner.sh --token <TOKEN> --runner-ver 2.319.0
#
# ── Unregister and remove runner ─────────────────────────────────────────
# sudo ${RUNNER_DIR}/svc.sh stop
# sudo ${RUNNER_DIR}/svc.sh uninstall
# cd ${RUNNER_DIR} && ./config.sh remove --token <REMOVE_TOKEN>
