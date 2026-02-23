# Troubleshooting Guide

## Common Issues

### Issue: "fastboot devices" returns empty
**Cause:** USB drivers not installed or device not in fastboot mode
**Solution:**
1. Check device is in fastboot mode: `adb devices` should show device
2. Install USB drivers for your platform
3. See bootloader unlock guide for platform-specific steps

### Issue: AOSP build fails
**Cause:** Missing dependencies or Java version mismatch
**Solution:** Verify Java 17+ installed: `java -version`

### Issue: Magisk module won't install
**Cause:** Incorrect permissions or module.prop syntax
**Solution:** Check Magisk logs: `adb shell cat /data/adb/magisk/magisk.log`

### Issue: Setup script fails on Windows
**Cause:** This is a Linux/macOS only script
**Solution:** Use Windows Subsystem for Linux (WSL2) or a Linux VM

## Build Environment Issues

### Out of disk space
- AOSP builds require 200GB+ free space
- Clean build: `cd path_b_rom && make clean`
- Remove ccache: `rm -rf ~/.ccache`

### Java version conflicts
```bash
# Check current version
java -version

# Install Java 17
sudo apt-get install openjdk-17-jdk

# Set as default
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 100
```

## Debugging

### Enable verbose build output
```bash
./build_scripts/build_rom.sh -v
./build_scripts/build_module.sh -v
```

### Check device logs
```bash
adb logcat | grep -i audioshift
```

### Verify module installation
```bash
adb shell ls -la /data/adb/modules/audioshift/
```
