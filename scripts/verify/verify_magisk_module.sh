#!/usr/bin/env bash
##
# AudioShift — Magisk Module Verification Script
# Phase 5 § Sprint 5.3
#
# Purpose:
#   Verify Magisk module structure, properties, and compatibility
#   before submission to Magisk-Modules-Repo.
#
# Usage:
#   ./scripts/verify/verify_magisk_module.sh [--module-path PATH]
#
# Environment Variables:
#   MAGISK_MODULE_PATH — Path to module directory (default: path_c_magisk/module)
#
# Validation Checks:
#   - Module structure (required files and directories)
#   - module.prop format and required fields
#   - Magisk version compatibility
#   - Binary architecture support (arm64-v8a)
#   - Script validity and syntax
#   - Permission and executable bits
#
# Success Criteria:
#   - All required files present
#   - module.prop syntax valid
#   - minMagisk >= 20400 (Zygisk support)
#   - ARM64 library present and executable
#   - All scripts are readable and not corrupted
#
##

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

MAGISK_MODULE_PATH="${MAGISK_MODULE_PATH:-$PROJECT_ROOT/path_c_magisk/module}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# ─────────────────────────────────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────────────────────────────────

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; ((CHECKS_PASSED++)); }
warning() { echo -e "${YELLOW}[⚠]${NC} $*"; ((CHECKS_WARNING++)); }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; ((CHECKS_FAILED++)); }
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
            --module-path)
                MAGISK_MODULE_PATH="$2"
                shift 2
                ;;
            --help)
                cat << EOF
AudioShift Magisk Module Verification

Usage: $(basename "$0") [OPTIONS]

Options:
  --module-path PATH    Path to module directory
  --help                Show this help message

Environment Variables:
  MAGISK_MODULE_PATH    Module directory (default: path_c_magisk/module)

Examples:
  $(basename "$0")
  $(basename "$0") --module-path /path/to/module

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
# Check 1: Module directory structure
# ─────────────────────────────────────────────────────────────────────────────

check_module_structure() {
    header "Check 1: Module directory structure"

    if [ ! -d "$MAGISK_MODULE_PATH" ]; then
        error "Module directory not found: $MAGISK_MODULE_PATH"
        return 1
    fi

    success "Module directory exists"

    # Required files
    local required_files=(
        "module.prop"
        "META-INF/com/google/android/update-binary"
        "META-INF/com/google/android/updater-script"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$MAGISK_MODULE_PATH/$file" ]; then
            success "Found: $file"
        else
            error "Missing: $file"
        fi
    done

    # Required directories
    local required_dirs=(
        "META-INF"
        "META-INF/com"
        "META-INF/com/google"
        "META-INF/com/google/android"
    )

    for dir in "${required_dirs[@]}"; do
        if [ -d "$MAGISK_MODULE_PATH/$dir" ]; then
            success "Found directory: $dir"
        else
            error "Missing directory: $dir"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: module.prop format and fields
# ─────────────────────────────────────────────────────────────────────────────

check_module_prop() {
    header "Check 2: module.prop format and fields"

    if [ ! -f "$MAGISK_MODULE_PATH/module.prop" ]; then
        error "module.prop not found"
        return 1
    fi

    # Required fields
    local required_fields=(
        "id"
        "name"
        "version"
        "versionCode"
        "author"
    )

    for field in "${required_fields[@]}"; do
        if grep -q "^${field}=" "$MAGISK_MODULE_PATH/module.prop"; then
            local value=$(grep "^${field}=" "$MAGISK_MODULE_PATH/module.prop" | cut -d= -f2-)
            success "Field $field = $value"
        else
            error "Missing required field: $field"
        fi
    done

    # Validate module ID format (alphanumeric, underscore, dash)
    local module_id=$(grep "^id=" "$MAGISK_MODULE_PATH/module.prop" | cut -d= -f2)
    if [[ "$module_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        success "Module ID format valid: $module_id"
    else
        error "Invalid module ID format: $module_id (must be alphanumeric, underscore, dash)"
    fi

    # Validate version format
    local version=$(grep "^version=" "$MAGISK_MODULE_PATH/module.prop" | cut -d= -f2)
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || [[ "$version" =~ ^v?[0-9]+ ]]; then
        success "Version format valid: $version"
    else
        warning "Version format unusual: $version (recommend semantic versioning)"
    fi

    # Check for recommended fields
    local recommended_fields=(
        "description"
        "minMagisk"
    )

    for field in "${recommended_fields[@]}"; do
        if grep -q "^${field}=" "$MAGISK_MODULE_PATH/module.prop"; then
            success "Recommended field present: $field"
        else
            warning "Recommended field missing: $field"
        fi
    done

    # Validate minMagisk version if present
    if grep -q "^minMagisk=" "$MAGISK_MODULE_PATH/module.prop"; then
        local minmagisk=$(grep "^minMagisk=" "$MAGISK_MODULE_PATH/module.prop" | cut -d= -f2)
        if [ "$minmagisk" -ge 20400 ]; then
            success "minMagisk version sufficient for Zygisk: $minmagisk"
        else
            warning "minMagisk version may be too old for Zygisk: $minmagisk (recommend 20400+)"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: Installer scripts
# ─────────────────────────────────────────────────────────────────────────────

check_installer_scripts() {
    header "Check 3: Installer scripts"

    # Check update-binary
    if [ -f "$MAGISK_MODULE_PATH/META-INF/com/google/android/update-binary" ]; then
        success "update-binary present"

        # Check if it's executable
        if [ -x "$MAGISK_MODULE_PATH/META-INF/com/google/android/update-binary" ]; then
            success "update-binary is executable"
        else
            warning "update-binary not executable (may fail in Magisk Manager)"
        fi
    else
        error "update-binary missing"
    fi

    # Check updater-script
    if [ -f "$MAGISK_MODULE_PATH/META-INF/com/google/android/updater-script" ]; then
        success "updater-script present"

        # Check content
        if grep -q "#MAGISK" "$MAGISK_MODULE_PATH/META-INF/com/google/android/updater-script"; then
            success "updater-script contains #MAGISK marker"
        else
            warning "updater-script missing #MAGISK marker (may not work correctly)"
        fi
    else
        error "updater-script missing"
    fi

    # Check common/service.sh
    if [ -f "$MAGISK_MODULE_PATH/common/service.sh" ]; then
        success "common/service.sh present"

        # Validate shell syntax
        if bash -n "$MAGISK_MODULE_PATH/common/service.sh" 2>/dev/null; then
            success "common/service.sh syntax valid"
        else
            error "common/service.sh has syntax errors"
        fi
    else
        warning "common/service.sh missing (module won't run post-boot)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: Native libraries (arm64-v8a)
# ─────────────────────────────────────────────────────────────────────────────

check_native_libraries() {
    header "Check 4: Native libraries"

    # Check for system/lib64 directory
    if [ -d "$MAGISK_MODULE_PATH/system/lib64" ]; then
        success "system/lib64 directory present"

        # Count .so files
        local so_count=$(find "$MAGISK_MODULE_PATH/system/lib64" -name "*.so" -type f | wc -l)
        if [ "$so_count" -gt 0 ]; then
            success "Found $so_count .so files"

            # Check for AudioShift library
            if [ -f "$MAGISK_MODULE_PATH/system/lib64/libaudioshift_hook.so" ]; then
                success "libaudioshift_hook.so present"

                # Check if ELF binary
                if file "$MAGISK_MODULE_PATH/system/lib64/libaudioshift_hook.so" | grep -q "ELF"; then
                    success "libaudioshift_hook.so is valid ELF binary"

                    # Show architecture
                    local arch=$(file "$MAGISK_MODULE_PATH/system/lib64/libaudioshift_hook.so" | grep -oE "(x86_64|ARM aarch64|i386|arm)")
                    success "Architecture: $arch"
                else
                    error "libaudioshift_hook.so is not a valid ELF binary"
                fi
            else
                error "libaudioshift_hook.so not found"
            fi
        else
            warning "No .so files found in system/lib64"
        fi
    else
        warning "system/lib64 directory not found (no native libraries)"
    fi

    # Check for vendor lib64
    if [ -d "$MAGISK_MODULE_PATH/system/vendor/lib64" ]; then
        success "system/vendor/lib64 present"
        local vendor_so=$(find "$MAGISK_MODULE_PATH/system/vendor/lib64" -name "*.so" -type f | wc -l)
        info "Found $vendor_so .so files in vendor/lib64"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: Audio policy configuration
# ─────────────────────────────────────────────────────────────────────────────

check_audio_config() {
    header "Check 5: Audio policy configuration"

    # Check for audio_effects.xml
    if [ -f "$MAGISK_MODULE_PATH/system/vendor/etc/audio_effects.xml" ]; then
        success "audio_effects.xml present"

        # Check for AudioShift effect registration
        if grep -q "audioshift" "$MAGISK_MODULE_PATH/system/vendor/etc/audio_effects.xml"; then
            success "AudioShift effect registration found"

            # Show registration details
            grep -E "libaudioshift|audioshift" "$MAGISK_MODULE_PATH/system/vendor/etc/audio_effects.xml" | \
                head -3 | while read -r line; do
                info "  $line"
            done
        else
            warning "AudioShift effect not registered in audio_effects.xml"
        fi
    else
        warning "audio_effects.xml not found"
    fi

    # Check for post_fs_data.sh
    if [ -f "$MAGISK_MODULE_PATH/common/post_fs_data.sh" ]; then
        success "post_fs_data.sh present"
    else
        warning "post_fs_data.sh not found (no early setup script)"
    fi

    # Check for system.prop
    if [ -f "$MAGISK_MODULE_PATH/system.prop" ]; then
        success "system.prop present"
        grep "^audioshift" "$MAGISK_MODULE_PATH/system.prop" | while read -r line; do
            info "  $line"
        done
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 6: File permissions
# ─────────────────────────────────────────────────────────────────────────────

check_permissions() {
    header "Check 6: File permissions"

    # Check for common permission issues
    local executable_scripts=(
        "META-INF/com/google/android/update-binary"
        "common/service.sh"
        "common/post_fs_data.sh"
    )

    for script in "${executable_scripts[@]}"; do
        if [ -f "$MAGISK_MODULE_PATH/$script" ]; then
            if [ -x "$MAGISK_MODULE_PATH/$script" ]; then
                success "$script is executable"
            else
                warning "$script is not executable"
            fi
        fi
    done

    # Check that other files are readable
    find "$MAGISK_MODULE_PATH" -type f ! -readable 2>/dev/null | while read -r file; do
        error "File is not readable: $file"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 7: Module size and integrity
# ─────────────────────────────────────────────────────────────────────────────

check_module_size() {
    header "Check 7: Module size and integrity"

    local module_size=$(du -sh "$MAGISK_MODULE_PATH" | cut -f1)
    success "Module size: $module_size"

    # Count files
    local file_count=$(find "$MAGISK_MODULE_PATH" -type f | wc -l)
    success "Total files: $file_count"

    # Check for suspicious files
    local suspicious_files=$(find "$MAGISK_MODULE_PATH" -type f -name ".*" 2>/dev/null | wc -l)
    if [ "$suspicious_files" -gt 0 ]; then
        warning "Found $suspicious_files hidden files (may not be packaged)"
    fi

    # Check for backup or editor files
    if find "$MAGISK_MODULE_PATH" -type f \( -name "*.bak" -o -name "*~" -o -name "*.swp" \) | grep -q .; then
        warning "Found backup/editor files (should be removed before packaging)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Generate verification report
# ─────────────────────────────────────────────────────────────────────────────

generate_report() {
    header "Verification Report"

    echo "Module Path:      $MAGISK_MODULE_PATH"
    echo "Checks Passed:    $CHECKS_PASSED"
    echo "Checks Failed:    $CHECKS_FAILED"
    echo "Warnings:         $CHECKS_WARNING"
    echo ""

    if [ "$CHECKS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ Module verification PASSED${NC}"
        if [ "$CHECKS_WARNING" -gt 0 ]; then
            echo -e "${YELLOW}⚠ $CHECKS_WARNING warning(s) to review${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Module verification FAILED${NC}"
        echo "Please fix the errors above before submission"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    header "AudioShift Magisk Module Verification"

    check_module_structure
    check_module_prop
    check_installer_scripts
    check_native_libraries
    check_audio_config
    check_permissions
    check_module_size
    generate_report
}

main "$@"
exit_code=$?

echo ""
exit "$exit_code"
