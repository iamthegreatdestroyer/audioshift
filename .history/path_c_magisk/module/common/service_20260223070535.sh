#!/sbin/sh
# AudioShift Magisk Module — Late-start service
# Runs after /data is decrypted and fully mounted.
# Sets system properties and verifies effect registration.

MODDIR=${0%/*}

# Wait for system to be fully booted
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 2   # extra settle time for AudioFlinger

# ──────────────────────────────────────────────────────────────
# Set system properties readable by apps and effects framework
# ──────────────────────────────────────────────────────────────
resetprop persist.audioshift.enabled     "1"
resetprop persist.audioshift.pitch_ratio "0.981818"   # 432/440
resetprop persist.audioshift.version     "1.0.0"

# ──────────────────────────────────────────────────────────────
# Verify effect library is accessible to AudioFlinger
# ──────────────────────────────────────────────────────────────
LIB=/system/lib64/soundfx/libaudioshift_effect.so
XML=/vendor/etc/audio_effects.xml         # Samsung path (S25+)
XML_ALT=/system/etc/audio_effects.xml

status=0

if [ ! -f "$LIB" ]; then
    resetprop persist.audioshift.status "error_no_lib"
    log -t AudioShift "service: ERROR — $LIB missing"
    status=1
fi

# Verify AudioShift UUID appears in effects config
if grep -q "f1a2b3c4" "$XML" 2>/dev/null || grep -q "f1a2b3c4" "$XML_ALT" 2>/dev/null; then
    log -t AudioShift "service: effects XML registration OK ✓"
else
    log -t AudioShift "service: WARNING — AudioShift UUID not found in audio_effects XML"
    log -t AudioShift "service: Using module-injected XML at /vendor/etc/audio_effects_audioshift.xml"
fi

if [ $status -eq 0 ]; then
    resetprop persist.audioshift.status "active"
    log -t AudioShift "service: AudioShift 432Hz active — have a pleasant listening experience ♪"
fi
