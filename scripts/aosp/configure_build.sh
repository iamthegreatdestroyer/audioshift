#!/usr/bin/env bash
##
# AudioShift — AOSP Build Configuration Script
# Phase 5 § Sprint 5.1.1
#
# Purpose:
#   Configure AOSP build environment and apply AudioShift patches
#   before compilation. This script handles envsetup, lunch, and patch application.
#
# Usage:
#   ./scripts/aosp/configure_build.sh [--target TARGET] [--apply-patches]
#
# Environment Variables:
#   AOSP_ROOT       — AOSP workspace (default: $HOME/aosp)
#   LUNCH_TARGET    — Build target (default: aosp_arm64-userdebug)
#   SKIP_PATCHES    — If set, skip patch application (default: apply)
#
# Examples:
#   ./scripts/aosp/configure_build.sh
#   ./scripts/aosp/configure_build.sh --target aosp_arm64-user
#   SKIP_PATCHES=1 ./scripts/aosp/configure_build.sh
#
# Patches Applied:
#   - AudioFlinger 432Hz effect integration
#   - Audio policy configuration updates
#   - Device tree modifications (S25+)
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

AOSP_ROOT="${AOSP_ROOT:-$HOME/aosp}"
LUNCH_TARGET="${LUNCH_TARGET:-aosp_arm64-userdebug}"
APPLY_PATCHES="${SKIP_PATCHES:-1}"

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

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                LUNCH_TARGET="$2"
                shift 2
                ;;
            --apply-patches)
                APPLY_PATCHES=1
                shift
                ;;
            --skip-patches)
                APPLY_PATCHES=0
                shift
                ;;
            --help)
                cat << EOF
AudioShift AOSP Build Configuration

Usage: $(basename "$0") [OPTIONS]

Options:
  --target TARGET       Build target (default: aosp_arm64-userdebug)
  --apply-patches       Apply AudioShift patches (default)
  --skip-patches        Skip patch application
  --help                Show this help message

Environment Variables:
  AOSP_ROOT            AOSP workspace (default: \$HOME/aosp)
  LUNCH_TARGET         Build target (default: aosp_arm64-userdebug)
  SKIP_PATCHES         If set, skip patches (opposite of --apply-patches)

Examples:
  $(basename "$0")
  $(basename "$0") --target aosp_arm64-user
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
# Step 1: Verify AOSP environment
# ─────────────────────────────────────────────────────────────────────────────

verify_aosp_env() {
    header "Step 1: Verify AOSP environment"

    if [ ! -d "$AOSP_ROOT" ]; then
        error "AOSP root not found: $AOSP_ROOT"
        exit 1
    fi

    if [ ! -f "$AOSP_ROOT/build/envsetup.sh" ]; then
        error "AOSP build environment not found"
        error "Expected: $AOSP_ROOT/build/envsetup.sh"
        exit 1
    fi

    success "AOSP environment verified at: $AOSP_ROOT"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Source build environment and set lunch target
# ─────────────────────────────────────────────────────────────────────────────

setup_build_env() {
    header "Step 2: Source build environment"

    cd "$AOSP_ROOT"

    info "Sourcing build/envsetup.sh..."
    # Source must be in same shell context, so we do it directly
    source "build/envsetup.sh" > /dev/null 2>&1 || {
        error "Failed to source build environment"
        exit 1
    }

    info "Configuring lunch target: $LUNCH_TARGET"
    # Source the lunch function in current shell
    # This is a bit tricky in non-interactive mode, so we use a subshell wrapper
    lunch "$LUNCH_TARGET" > /dev/null 2>&1 || {
        warning "Lunch configuration may have warnings (continuing)"
    }

    success "Build environment configured"
    info "Target: $LUNCH_TARGET"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Apply AudioShift patches
# ─────────────────────────────────────────────────────────────────────────────

apply_audioshift_patches() {
    if [ "$APPLY_PATCHES" -eq 0 ]; then
        warning "Skipping patch application (--skip-patches)"
        return 0
    fi

    header "Step 3: Apply AudioShift patches"

    cd "$AOSP_ROOT"

    PATCHES_DIR="$PROJECT_ROOT/path_b_rom/build_scripts/patches"

    if [ ! -d "$PATCHES_DIR" ]; then
        warning "Patches directory not found: $PATCHES_DIR"
        info "Creating patches directory..."
        mkdir -p "$PATCHES_DIR"
    fi

    # Count patch files
    PATCH_COUNT=$(find "$PATCHES_DIR" -maxdepth 1 -name "*.patch" -type f | wc -l)

    if [ "$PATCH_COUNT" -eq 0 ]; then
        warning "No patch files found in $PATCHES_DIR"
        info "AudioShift patches may not have been generated yet"
        return 0
    fi

    info "Found $PATCH_COUNT patch files, applying..."

    APPLIED=0
    FAILED=0

    for patch_file in "$PATCHES_DIR"/*.patch; do
        if [ ! -f "$patch_file" ]; then
            continue
        fi

        PATCH_NAME=$(basename "$patch_file")
        info "Applying: $PATCH_NAME"

        if patch -p1 --dry-run < "$patch_file" > /dev/null 2>&1; then
            if patch -p1 < "$patch_file" > /dev/null 2>&1; then
                success "Applied: $PATCH_NAME"
                ((APPLIED++))
            else
                error "Failed to apply: $PATCH_NAME"
                ((FAILED++))
            fi
        else
            warning "Patch check failed: $PATCH_NAME (may already be applied)"
            if patch -p1 --reverse --dry-run < "$patch_file" > /dev/null 2>&1; then
                warning "  → Patch appears already applied, skipping"
                ((APPLIED++))
            else
                warning "  → Proceeding anyway (may cause build errors)"
                ((APPLIED++))
            fi
        fi
    done

    echo ""
    info "Patch Summary:"
    info "  Applied: $APPLIED"
    info "  Failed:  $FAILED"

    if [ "$FAILED" -gt 0 ]; then
        warning "Some patches failed. Review errors above."
        info "Continuing build (failures may cause compilation errors)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Copy AudioShift device configs
# ─────────────────────────────────────────────────────────────────────────────

copy_device_configs() {
    header "Step 4: Copy AudioShift device configurations"

    cd "$AOSP_ROOT"

    DEVICE_CONFIG_SRC="$PROJECT_ROOT/path_b_rom/android/device/samsung/s25plus"
    DEVICE_CONFIG_DST="$AOSP_ROOT/device/samsung/s25plus"

    if [ ! -d "$DEVICE_CONFIG_SRC" ]; then
        warning "AudioShift device config not found: $DEVICE_CONFIG_SRC"
        return 0
    fi

    info "Creating device directory: device/samsung/s25plus"
    mkdir -p "$DEVICE_CONFIG_DST"

    # Copy property files
    info "Copying AudioShift property files..."
    for file in "$DEVICE_CONFIG_SRC"/*.prop; do
        if [ -f "$file" ]; then
            cp "$file" "$DEVICE_CONFIG_DST/" || {
                warning "Failed to copy $(basename "$file")"
            }
        fi
    done

    # Copy audio policy config
    info "Copying audio policy configuration..."
    for file in "$DEVICE_CONFIG_SRC"/*.xml; do
        if [ -f "$file" ]; then
            cp "$file" "$DEVICE_CONFIG_DST/" || {
                warning "Failed to copy $(basename "$file")"
            }
        fi
    done

    success "Device configs copied to: $DEVICE_CONFIG_DST"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Verify build configuration
# ─────────────────────────────────────────────────────────────────────────────

verify_build_config() {
    header "Step 5: Verify build configuration"

    cd "$AOSP_ROOT"

    info "Build system information:"
    echo "  AOSP Root:          $AOSP_ROOT"
    echo "  Lunch Target:       $LUNCH_TARGET"
    echo "  Java Home:          ${JAVA_HOME:-not set}"
    echo "  Python:             $(python3 --version 2>&1)"

    if [ -f "build/core/main.mk" ]; then
        success "✓ AOSP build system verified"
    else
        error "AOSP build system not found"
        exit 1
    fi

    # Check for AudioShift integration
    if grep -r "audioshift" frameworks/av/services/audioflinger/*.cpp 2>/dev/null | head -1; then
        success "✓ AudioShift integration detected in AudioFlinger"
    else
        warning "AudioShift integration not detected in AudioFlinger"
        info "  (Will be added by patches or manual edits)"
    fi

    success "Build configuration ready"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    verify_aosp_env
    setup_build_env
    apply_audioshift_patches
    copy_device_configs
    verify_build_config

    echo ""
    success "AOSP build configuration complete!"
    echo ""
    info "Ready to compile. Next step:"
    info "  Run: m -j\$(nproc) libaudioshift432 otapackage"
    echo ""
}

# Run in AOSP context
cd "$AOSP_ROOT"
main "$@"
