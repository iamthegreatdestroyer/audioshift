#!/bin/bash

# Build all AudioShift components
# Usage: ./build_all.sh [options]

set -e

echo "=== AudioShift Complete Build ==="
echo ""

# Build shared DSP library
echo "[1/3] Building shared DSP library..."
cd shared/dsp
mkdir -p build
cd build
cmake .. > /dev/null
make -j$(nproc) > /dev/null
cd ../../..
echo "✓ DSP library built"

# Build PATH-B ROM
echo "[2/3] Building PATH-B custom ROM..."
cd path_b_rom
./build_scripts/build_rom.sh
cd ..
echo "✓ PATH-B ROM built"

# Build PATH-C Magisk module
echo "[3/3] Building PATH-C Magisk module..."
cd path_c_magisk
./build_scripts/build_module.sh
cd ..
echo "✓ PATH-C module built"

echo ""
echo "=== Build Complete ==="
echo "Artifacts available in:"
echo "  - PATH-B: path_b_rom/out/"
echo "  - PATH-C: path_c_magisk/out/"
