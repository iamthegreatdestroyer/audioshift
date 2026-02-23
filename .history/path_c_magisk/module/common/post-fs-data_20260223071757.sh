#!/sbin/sh
# AudioShift Magisk Module — post-install service
# Runs after system boot in Magisk's post-fs-data phase (early, before /data decryption).
# Only lightweight, read-only operations here.

# If anything fails, fail silently (Magisk will continue regardless)
set -e 2>/dev/null || true

MODDIR=${0%/*}

# Mark module as active
touch "$MODDIR/skip_mount" 2>/dev/null || true   # don't needed — we want the overlay
rm -f "$MODDIR/skip_mount" 2>/dev/null || true

# Verify the .so was deployed by the Magisk overlay
LIB_PATH=/system/lib64/soundfx/libaudioshift_effect.so
if [ -f "$LIB_PATH" ]; then
    log -t AudioShift "post-fs-data: libaudioshift_effect.so present ✓"
else
    log -t AudioShift "post-fs-data: WARNING — $LIB_PATH not found (overlay may not have applied)"
fi
