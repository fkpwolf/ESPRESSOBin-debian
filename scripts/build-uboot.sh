#!/bin/bash

set -e

# Build U-Boot for ESPRESSOBin

UBOOT_VERSION="2024.01"
UBOOT_DIR="/build/u-boot"
OUTPUT_DIR="/build/output"

echo "Building U-Boot ${UBOOT_VERSION} for ESPRESSOBin..."

# Download U-Boot if not already present
if [ ! -d "${UBOOT_DIR}" ]; then
    echo "Downloading U-Boot ${UBOOT_VERSION}..."
    cd /build
    wget "https://github.com/u-boot/u-boot/archive/v${UBOOT_VERSION}.tar.gz" -O u-boot.tar.gz
    tar -xzf u-boot.tar.gz
    mv "u-boot-${UBOOT_VERSION}" u-boot
    rm u-boot.tar.gz
fi

cd "${UBOOT_DIR}"

# Clean previous builds
make distclean

# Configure for ESPRESSOBin
echo "Configuring U-Boot for ESPRESSOBin..."
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- mvebu_espressobin-88f3720_defconfig

# Apply any custom configuration
if [ -f "/build/configs/uboot.config" ]; then
    echo "Applying custom U-Boot configuration..."
    cat /build/configs/uboot.config >> .config
    make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
fi

# Build U-Boot
echo "Building U-Boot..."
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# Copy output files
mkdir -p "${OUTPUT_DIR}/u-boot"
cp u-boot.bin "${OUTPUT_DIR}/u-boot/"
if [ -f "u-boot.img" ]; then
    cp u-boot.img "${OUTPUT_DIR}/u-boot/"
fi

# Download ARM Trusted Firmware for ESPRESSOBin if needed (optional)  
# This creates a complete flash image combining ATF and U-Boot
if [ "${BUILD_ATF:-yes}" = "yes" ] && [ ! -f "${OUTPUT_DIR}/u-boot/flash-image.bin" ]; then
    echo "Building ARM Trusted Firmware..."
    cd /build
    if [ ! -d "arm-trusted-firmware" ]; then
        git clone --depth 1 https://github.com/ARM-software/arm-trusted-firmware.git
    fi
    cd arm-trusted-firmware
    
    # Build ATF for A3700 (ESPRESSOBin SoC)
    make CROSS_COMPILE=aarch64-linux-gnu- PLAT=a3700 BL33="${UBOOT_DIR}/u-boot.bin" all fip
    
    # Create the proper flash image for ESPRESSOBin
    # The ESPRESSOBin bubt command requires a specific image format
    # The issue with "Unsupported Image version" occurs because the bubt command
    # expects either a raw binary or a properly formatted U-Boot image
    
    echo "Creating flash images for ESPRESSOBin..."
    
    # Create the raw ATF+U-Boot image (traditional method)
    cat build/a3700/release/bl1.bin build/a3700/release/fip.bin > "${OUTPUT_DIR}/u-boot/flash-image-raw.bin"
    
    # For the ESPRESSOBin SPI flash, the bubt command works best with the U-Boot binary directly
    # Copy the u-boot.bin as an alternative flash image that bubt can handle
    cp "${UBOOT_DIR}/u-boot.bin" "${OUTPUT_DIR}/u-boot/u-boot-spi.bin"
    
    # The main flash-image.bin should be the complete ATF+U-Boot for SPI flashing
    # But we need to ensure it has the proper format expected by bubt
    cp "${OUTPUT_DIR}/u-boot/flash-image-raw.bin" "${OUTPUT_DIR}/u-boot/flash-image.bin"
    
    # Create individual ATF components for manual flashing if needed
    cp build/a3700/release/bl1.bin "${OUTPUT_DIR}/u-boot/"
    cp build/a3700/release/fip.bin "${OUTPUT_DIR}/u-boot/"
    
    echo "Flash images created:"
    echo "  flash-image.bin     - Complete ATF+U-Boot image for SPI (recommended)"
    echo "  u-boot-spi.bin      - U-Boot only binary (alternative for bubt)"
    echo "  bl1.bin            - ARM Trusted Firmware BL1"
    echo "  fip.bin            - Firmware Image Package"
else
    echo "Skipping ARM Trusted Firmware build (BUILD_ATF=${BUILD_ATF:-no})"
fi

echo "U-Boot build completed successfully!"
echo "Files created in: ${OUTPUT_DIR}/u-boot/"