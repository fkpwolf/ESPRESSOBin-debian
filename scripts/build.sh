#!/bin/bash

set -e

# ESPRESSOBin Debian Image Builder
# Builds a complete Debian image for ESPRESSOBin device

# Configuration
DEBIAN_VERSION="trixie"  # Debian 13
KERNEL_VERSION="6.6"     # Latest stable LTS
UBOOT_VERSION="2024.01"  # Latest stable u-boot
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"
DEVICE="espressobin"

# Directories
BUILD_DIR="/build"
OUTPUT_DIR="${BUILD_DIR}/output"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
KERNEL_DIR="${BUILD_DIR}/linux"
UBOOT_DIR="${BUILD_DIR}/u-boot"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "========================================"
echo "ESPRESSOBin Debian Image Builder"
echo "========================================"
echo "Debian Version: ${DEBIAN_VERSION}"
echo "Kernel Version: ${KERNEL_VERSION}"
echo "U-Boot Version: ${UBOOT_VERSION}"
echo "Architecture: ${ARCH}"
echo "========================================"

# Build U-Boot
echo "Building U-Boot..."
./scripts/build-uboot.sh

# Build Linux Kernel
echo "Building Linux Kernel..."
./scripts/build-kernel.sh

# Create Debian Root Filesystem
echo "Creating Debian Root Filesystem..."
./scripts/build-rootfs.sh

# Generate final image
echo "Generating final image..."
./scripts/create-image.sh

echo "========================================"
echo "Build completed successfully!"
echo "Output files are in: ${OUTPUT_DIR}"
echo "========================================"