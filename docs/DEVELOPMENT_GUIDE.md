# Development Guide

## Setup Development Environment

### Prerequisites
```bash
# Ubuntu 22.04 LTS
sudo apt-get update
sudo apt-get install -y \
  git curl wget openssh-client \
  build-essential zip zlib1g-dev \
  python3 python3-pip ccache
```

### Clone AudioShift Repository
```bash
git clone https://github.com/YOUR_USERNAME/audioshift.git
cd audioshift
git checkout -b feature/your-feature-name
```

## Build Process

### Build Shared DSP Library
```bash
cd shared/dsp
mkdir build && cd build
cmake ..
make -j$(nproc)
```

### Build PATH-B ROM
```bash
cd path_b_rom
./build_scripts/build_rom.sh
```

### Build PATH-C Magisk Module
```bash
cd path_c_magisk
./build_scripts/build_module.sh
```

## Code Organization

### Naming Conventions
- **C++ files:** snake_case.cpp
- **Header files:** snake_case.h
- **Directories:** snake_case/
- **Classes:** PascalCase
- **Functions:** camelCase
- **Constants:** UPPER_SNAKE_CASE

### Comment Style
- Document public APIs with Doxygen comments
- Include high-level intent, not just what code does
- Link to relevant architecture docs

### Git Workflow

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make commits with clear messages
3. Push to fork: `git push origin feature/your-feature`
4. Create pull request with:
   - Clear description
   - Link to relevant issues
   - Testing results
   - Any performance impact

## Testing

### Run Unit Tests
```bash
./scripts/run_unit_tests.sh
```

### Run Integration Tests
```bash
./scripts/run_integration_tests.sh
```

### Performance Benchmarking
```bash
./tests/performance/benchmark_latency.cpp
```

## Documentation

- Update README for significant changes
- Add comments for complex algorithms
- Document discoveries in [DISCOVERY_LOG.md](../DISCOVERY_LOG.md)
- Reference [ANDROID_INTERNALS.md](ANDROID_INTERNALS.md) for deep-dive topics
