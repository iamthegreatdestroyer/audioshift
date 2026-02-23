#!/bin/bash

echo "=== AudioShift Development Environment Setup ==="
echo ""

# Check OS
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "ERROR: This setup script requires Linux (Ubuntu 22.04+)"
    exit 1
fi

# Check if running in audioshift directory
if [ ! -f "README.md" ]; then
    echo "ERROR: Please run this script from the audioshift root directory"
    exit 1
fi

echo "[1/5] Installing system dependencies..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y \
  git curl wget openssh-client gnupg flex bison gperf build-essential \
  zip zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
  lib32ncurses5-dev x11-utils ccache libxml2-utils xsltproc unzip \
  fontconfig libfreetype6-dev libx11-dev libxext-dev libxrender-dev \
  libbz2-dev libesd0-dev libselinux1-dev gawk python3-mako \
  libwxgtk3.0-gtk3-dev ninja-build cmake android-tools-adb \
  android-tools-fastboot > /dev/null 2>&1

echo "[2/5] Verifying Java installation..."
JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[0-9]+')
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo "ERROR: Java 17+ required, found version $JAVA_VERSION"
    exit 1
fi
echo "✓ Java $JAVA_VERSION detected"

echo "[3/5] Creating build directories..."
mkdir -p shared/dsp/build
mkdir -p path_b_rom/out
mkdir -p path_c_magisk/out
mkdir -p test_results

echo "[4/5] Initializing git repository..."
git config user.name "AudioShift Developer" 2>/dev/null || true
git config user.email "dev@audioshift.local" 2>/dev/null || true

echo "[5/5] Verifying setup..."
if [ -d "shared/dsp" ] && [ -d "path_b_rom" ] && [ -d "path_c_magisk" ]; then
    echo ""
    echo "=== Setup Complete! ==="
    echo ""
    echo "Next steps:"
    echo "1. Read GETTING_STARTED.md"
    echo "2. Configure your Git credentials"
    echo "3. Choose your path: PATH-B (ROM) or PATH-C (Magisk)"
    echo ""
else
    echo "ERROR: Setup verification failed"
    exit 1
fi
