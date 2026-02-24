#!/usr/bin/env bash
##
# AudioShift — AOSP Repository Initialization Script
# Phase 5 § Sprint 5.1.1
#
# Purpose:
#   Initialize and sync complete AOSP source tree for custom ROM builds.
#   Handles repo initialization, local manifest setup, and parallel sync.
#
# Usage:
#   ./scripts/aosp/init_aosp_repo.sh [--branch BRANCH] [--jobs N]
#
# Environment Variables:
#   AOSP_ROOT       — AOSP workspace (default: $HOME/aosp)
#   AOSP_BRANCH     — AOSP branch (default: android-14.0.0_r61)
#   SYNC_JOBS       — Parallel sync jobs (default: 8, auto-detect from nproc)
#
# Examples:
#   ./scripts/aosp/init_aosp_repo.sh
#   ./scripts/aosp/init_aosp_repo.sh --branch android-15-initial --jobs 16
#
# Requirements:
#   - repo tool installed (https://source.android.com/setup/build/downloading)
#   - git, curl, python3
#   - ~250GB free disk space
#   - Network connectivity
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

AOSP_ROOT="${AOSP_ROOT:-$HOME/aosp}"
AOSP_BRANCH="${AOSP_BRANCH:-android-14.0.0_r61}"
SYNC_JOBS="${SYNC_JOBS:-$(nproc 2>/dev/null || echo 8)}"

MANIFEST_URL="https://android.googlesource.com/platform/manifest"
REPO_TOOL_URL="https://gerrit.googlesource.com/git-repo"

# ─────────────────────────────────────────────────────────────────────────────
# Colors for output
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────────────────────────────────

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $*"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)
                AOSP_BRANCH="$2"
                shift 2
                ;;
            --jobs)
                SYNC_JOBS="$2"
                shift 2
                ;;
            --root)
                AOSP_ROOT="$2"
                shift 2
                ;;
            --help)
                cat << EOF
AudioShift AOSP Repository Initialization

Usage: $(basename "$0") [OPTIONS]

Options:
  --branch BRANCH    AOSP branch to sync (default: android-14.0.0_r61)
  --jobs N           Parallel sync jobs (default: auto-detect)
  --root PATH        AOSP root directory (default: \$HOME/aosp)
  --help             Show this help message

Environment Variables:
  AOSP_ROOT          Override --root
  AOSP_BRANCH        Override --branch
  SYNC_JOBS          Override --jobs

Examples:
  $(basename "$0")
  $(basename "$0") --branch android-15-initial --jobs 16
  AOSP_ROOT=/mnt/aosp $(basename "$0")

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
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────

preflight_checks() {
    header "Pre-flight Checks"

    # Check required tools
    for tool in repo git curl python3; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool not found: $tool"
            exit 1
        fi
    done
    success "All required tools installed"

    # Check disk space
    DISK_AVAILABLE_GB=$(($(df "$AOSP_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0) / 1024 / 1024))
    if [ "$DISK_AVAILABLE_GB" -lt 250 ]; then
        warning "Available disk space: ${DISK_AVAILABLE_GB}GB (recommend 250GB+)"
        read -p "Continue anyway? (y/n) " -r
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    else
        success "Available disk space: ${DISK_AVAILABLE_GB}GB"
    fi

    # Show configuration
    info "Configuration:"
    info "  AOSP Root:     $AOSP_ROOT"
    info "  AOSP Branch:   $AOSP_BRANCH"
    info "  Sync Jobs:     $SYNC_JOBS"
    info "  Project Root:  $PROJECT_ROOT"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Initialize repo
# ─────────────────────────────────────────────────────────────────────────────

init_repo() {
    header "Step 1: Initialize repo (manifest branch: $AOSP_BRANCH)"

    mkdir -p "$AOSP_ROOT"
    cd "$AOSP_ROOT"

    if [ -d ".repo" ]; then
        warning "AOSP repository already initialized at $AOSP_ROOT"
        info "Proceeding to next step (sync will update existing repos)"
        return 0
    fi

    info "Initializing repo with depth=1 (shallow clone)..."
    repo init \
        -u "$MANIFEST_URL" \
        -b "$AOSP_BRANCH" \
        --depth=1 \
        --repo-url="$REPO_TOOL_URL" \
        -q

    success "Repo initialized successfully"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Configure local manifests (AudioShift patches)
# ─────────────────────────────────────────────────────────────────────────────

setup_local_manifests() {
    header "Step 2: Configure local manifests (AudioShift integration)"

    MANIFEST_DIR="$AOSP_ROOT/.repo/local_manifests"
    mkdir -p "$MANIFEST_DIR"

    # Create AudioShift local manifest for custom device configs
    if [ -f "$PROJECT_ROOT/path_b_rom/build_scripts/local_manifest.xml" ]; then
        info "Installing AudioShift local manifest..."
        cp "$PROJECT_ROOT/path_b_rom/build_scripts/local_manifest.xml" \
           "$MANIFEST_DIR/audioshift.xml"
        success "Local manifest installed"
    else
        warning "AudioShift local manifest not found at $PROJECT_ROOT/path_b_rom/build_scripts/"
        info "Creating stub local manifest..."
        cat > "$MANIFEST_DIR/audioshift.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- AudioShift Custom Device Trees
       This would typically include custom device repos, but proceeding with standard AOSP
  -->
</manifest>
EOF
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Sync repositories (with retry logic)
# ─────────────────────────────────────────────────────────────────────────────

sync_repos() {
    header "Step 3: Sync AOSP repositories (parallel jobs: $SYNC_JOBS)"

    cd "$AOSP_ROOT"

    info "Syncing repositories with shallow clone (depth=1)..."
    info "This may take 30-60 minutes depending on network speed..."
    echo ""

    # Attempt sync with full parallelism
    if repo sync -j "$SYNC_JOBS" -c --fail-fast --no-tags -q 2>&1 | tee sync.log; then
        success "Repository sync completed"
        return 0
    fi

    # If sync failed, try with reduced job count
    FAILED_JOBS=$SYNC_JOBS
    SYNC_JOBS=$((SYNC_JOBS / 2))
    warning "Full sync failed, retrying with reduced jobs ($SYNC_JOBS)..."

    if repo sync -j "$SYNC_JOBS" -c --fail-fast --no-tags -q 2>&1 | tee -a sync.log; then
        success "Repository sync completed (with reduced parallelism)"
        return 0
    fi

    # Final attempt with minimal parallelism
    warning "Reduced sync still failed, final attempt with 2 jobs..."
    if repo sync -j 2 -c --fail-fast --no-tags -q 2>&1 | tee -a sync.log; then
        success "Repository sync completed (with minimal parallelism)"
        return 0
    fi

    error "Repository sync failed after all retries"
    echo ""
    info "Last 30 lines of sync.log:"
    tail -30 sync.log
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Verify sync and show summary
# ─────────────────────────────────────────────────────────────────────────────

verify_sync() {
    header "Step 4: Verify sync and report summary"

    cd "$AOSP_ROOT"

    # Check for required directories
    REQUIRED_DIRS=("build" "frameworks/av" "device" "vendor")
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            error "Required directory not found: $dir"
            exit 1
        fi
        success "✓ Found $dir"
    done

    # Show disk usage
    AOSP_SIZE_GB=$(($(du -s . 2>/dev/null | awk '{print $1}') / 1024 / 1024))
    info "AOSP source tree size: ${AOSP_SIZE_GB}GB"

    # Show repo status summary
    info "Repository sync summary:"
    repo status 2>&1 | head -20 || true

    success "AOSP repository initialization and sync complete!"
    echo ""
    info "Next steps:"
    info "  1. Run: source build/envsetup.sh"
    info "  2. Run: lunch aosp_arm64-userdebug"
    info "  3. Run: m -j\$(nproc) libaudioshift432 otapackage"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    preflight_checks
    init_repo
    setup_local_manifests
    sync_repos
    verify_sync

    echo ""
    success "AOSP repository ready at: $AOSP_ROOT"
}

main "$@"
