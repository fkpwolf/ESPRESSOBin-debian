#!/bin/bash

set -e

# Build Linux Kernel for ESPRESSOBin

KERNEL_VERSION="6.12"
KERNEL_DIR="/build/linux"
OUTPUT_DIR="/build/output"

echo "Building Linux Kernel ${KERNEL_VERSION} for ESPRESSOBin..."

# Download kernel if not already present
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "Downloading Linux Kernel ${KERNEL_VERSION}..."
    cd /build
    # Get the latest longterm 6.12.x version
    KERNEL_FULL_VERSION=$(curl -s https://www.kernel.org/releases.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for release in data['releases']:
    if release['version'].startswith('${KERNEL_VERSION}.') and release['moniker'] == 'longterm':
        print(release['version'])
        break
")
    if [ -z "${KERNEL_FULL_VERSION}" ]; then
        KERNEL_FULL_VERSION="${KERNEL_VERSION}.0"
    fi
    
    echo "Using kernel version: ${KERNEL_FULL_VERSION}"
    wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_FULL_VERSION}.tar.xz"
    tar -xf "linux-${KERNEL_FULL_VERSION}.tar.xz"
    mv "linux-${KERNEL_FULL_VERSION}" linux
    rm "linux-${KERNEL_FULL_VERSION}.tar.xz"
fi

cd "${KERNEL_DIR}"

# Clean previous builds
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- distclean

# Configure kernel for ARM64
echo "Configuring kernel for ARM64/ESPRESSOBin..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

# Apply ESPRESSOBin specific configuration
if [ -f "/build/configs/kernel.config" ]; then
    echo "Applying custom kernel configuration..."
    cat /build/configs/kernel.config >> .config
else
    # Enable ESPRESSOBin specific features
    echo "Enabling ESPRESSOBin specific features..."
    cat >> .config << EOF
# ESPRESSOBin specific configuration
CONFIG_ARCH_MVEBU=y
CONFIG_MACH_ARMADA_3720=y
CONFIG_ARM64_DMA_USE_IOMMU=y
CONFIG_ARMADA_3700_CLK=y
CONFIG_ARMADA_THERMAL=y
CONFIG_MVNETA=y
CONFIG_MV_XOR_V2=y
CONFIG_CRYPTO_DEV_MARVELL_CESA=y
CONFIG_MMC_SDHCI_XENON=y
CONFIG_PINCTRL_ARMADA_37XX=y
CONFIG_GPIO_ARMADA_37XX=y
CONFIG_SERIAL_MVEBU_UART=y
CONFIG_SPI_ARMADA_3700=y
CONFIG_I2C_MV64XXX=y
CONFIG_AHCI_MVEBU=y
CONFIG_USB_XHCI_MVEBU=y
CONFIG_PHY_MVEBU_A3700_COMPHY=y
CONFIG_PHY_MVEBU_A3700_UTMI=y
# DSA support for Topaz switch chip
CONFIG_NET_DSA=y
CONFIG_NET_DSA_MV88E6XXX=y
CONFIG_NET_DSA_MV88E6XXX_GLOBAL2=y
CONFIG_NET_DSA_TAG_EDSA=y
CONFIG_NET_DSA_TAG_DSA=y
EOF
fi

# Update configuration
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# Build kernel and device tree
echo "Building kernel..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules

# Install modules to temporary directory
MODULES_DIR="${OUTPUT_DIR}/modules"
mkdir -p "${MODULES_DIR}"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH="${MODULES_DIR}" modules_install

# Copy kernel and device tree files
mkdir -p "${OUTPUT_DIR}/kernel"
cp arch/arm64/boot/Image "${OUTPUT_DIR}/kernel/"
cp arch/arm64/boot/dts/marvell/armada-3720-espressobin*.dtb "${OUTPUT_DIR}/kernel/" 2>/dev/null || \
cp arch/arm64/boot/dts/marvell/armada-3720-espressobin.dtb "${OUTPUT_DIR}/kernel/" 2>/dev/null || \
echo "Warning: ESPRESSOBin device tree not found, using default marvell dtbs"

# Create uImage for U-Boot
mkimage -A arm64 -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 \
    -n "Linux Kernel" -d arch/arm64/boot/Image "${OUTPUT_DIR}/kernel/uImage"

echo "Kernel build completed successfully!"
echo "Files created in: ${OUTPUT_DIR}/kernel/"
echo "Modules installed in: ${OUTPUT_DIR}/modules/"