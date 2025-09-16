#!/bin/bash

# Quick validation test for ESPRESSOBin build system

set -e

echo "========================================"
echo "ESPRESSOBin Build System Validation Test"
echo "========================================"

# Test 1: Docker build
echo "Test 1: Docker build validation..."
if command -v docker &> /dev/null; then
    echo "✓ Docker is available"
    if docker image inspect espressobin-builder:latest &> /dev/null; then
        echo "✓ Build container image exists"
    else
        echo "✗ Build container image not found, building..."
        make build-docker
    fi
else
    echo "✗ Docker not available, cannot test container build"
    exit 1
fi

# Test 2: Cross-compilation tools
echo -e "\nTest 2: Cross-compilation tools validation..."

# Test cross-compiler
if docker run --rm espressobin-builder:latest which aarch64-linux-gnu-gcc > /dev/null; then
    echo "✓ Cross-compiler available"
else
    echo "✗ Cross-compiler not found"
    exit 1
fi

# Test basic build tools
if docker run --rm espressobin-builder:latest which make > /dev/null; then
    echo "✓ Build tools available"
else
    echo "✗ Build tools not available"
    exit 1
fi

echo "✓ Cross-compilation tools validated"

# Test 3: Scripts syntax validation
echo -e "\nTest 3: Build scripts validation..."
for script in scripts/*.sh; do
    if bash -n "$script"; then
        echo "✓ $(basename $script) syntax OK"
    else
        echo "✗ $(basename $script) has syntax errors"
        exit 1
    fi
done

# Test 4: Configuration files
echo -e "\nTest 4: Configuration files validation..."
if [ -f "configs/kernel.config" ]; then
    echo "✓ Kernel configuration file exists"
else
    echo "✗ Kernel configuration file missing"
    exit 1
fi

# Test 5: Documentation
echo -e "\nTest 5: Documentation validation..."
if [ -f "README.md" ] && [ -f "Makefile" ]; then
    echo "✓ Documentation files exist"
    if grep -q "ESPRESSOBin" README.md; then
        echo "✓ README contains ESPRESSOBin documentation"
    else
        echo "✗ README appears incomplete"
        exit 1
    fi
else
    echo "✗ Required documentation files missing"
    exit 1
fi

echo -e "\n========================================"
echo "✅ All validation tests passed!"
echo "========================================"
echo -e "\nBuild system is ready. To build complete image run:"
echo "  make build"
echo -e "\nFor help run:"
echo "  make help"