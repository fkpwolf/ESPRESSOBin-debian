#!/bin/bash

set -e

# Create Debian Root Filesystem for ESPRESSOBin

DEBIAN_VERSION="trixie"  # Debian 13
ROOTFS_DIR="/build/rootfs"
OUTPUT_DIR="/build/output"
MODULES_DIR="${OUTPUT_DIR}/modules"

echo "Creating Debian ${DEBIAN_VERSION} root filesystem..."

# Clean and create rootfs directory
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"

# Check if QEMU support is available
echo "Checking QEMU aarch64 support..."
if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "QEMU aarch64 support is enabled"
else
    echo "Warning: QEMU aarch64 support not found. This may cause debootstrap to fail."
    echo "Available binfmt_misc handlers:"
    ls -la /proc/sys/fs/binfmt_misc/ || echo "Cannot access binfmt_misc"
fi

# Bootstrap Debian base system
echo "Bootstrapping Debian ${DEBIAN_VERSION} arm64..."
debootstrap --arch=arm64 --include=systemd,udev,kmod,ifupdown,iproute2,iputils-ping,wget,curl,nano,openssh-server,sudo,locales \
    "${DEBIAN_VERSION}" "${ROOTFS_DIR}" http://deb.debian.org/debian/

# Configure QEMU for cross-architecture chroot
cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"

# Chroot and configure system
chroot "${ROOTFS_DIR}" /bin/bash << 'EOF'
set -e

# Set environment variables to prevent Python bytecode compilation issues
export PYTHONDONTWRITEBYTECODE=1
export DEB_PYTHON_INSTALL_LAYOUT=deb_system
export DEBIAN_FRONTEND=noninteractive

# Set up temporary /proc and /sys to help with systemd in chroot
mount -t proc proc /proc || true
mount -t sysfs sysfs /sys || true

# Configure locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Configure hostname
echo "espressobin" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
127.0.1.1   espressobin
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# Configure network interfaces
cat > /etc/network/interfaces << INTERFACES
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface (DHCP disabled)
# Configure manually or use network-manager
auto eth0
iface eth0 inet manual
INTERFACES

# Create a default user
useradd -m -s /bin/bash -G sudo debian
echo "debian:debian" | chpasswd
echo "root:root" | chpasswd

# Configure SSH
systemctl enable ssh
mkdir -p /home/debian/.ssh
chown debian:debian /home/debian/.ssh

# Ensure mv88e6xxx driver is available
# Create modules-load configuration to ensure switch driver is loaded
mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/espressobin.conf << MODULES
# ESPRESSOBin specific modules
# DSA switch support (mv88e6xxx is built-in but ensure dependencies are loaded)
mv88e6xxx
MODULES

# Enable systemd services
systemctl enable systemd-networkd
# Try to enable systemd-resolved, but don't fail if it doesn't exist
systemctl enable systemd-resolved || echo "systemd-resolved not available, skipping"

# Install additional useful packages
apt-get update

# Install packages in smaller batches to avoid issues
apt-get install -y --no-install-recommends \
    firmware-linux-free \
    firmware-atheros \
    firmware-misc-nonfree \
    wireless-tools \
    wpasupplicant \
    network-manager \
    htop \
    vim \
    git \
    ca-certificates \
    systemd-timesyncd

# Install build tools separately
apt-get install -y --no-install-recommends \
    build-essential

# Install Python packages with special handling for pip
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3

# Try to install python3-pip, but don't fail if it has issues
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3-pip || {
    echo "Warning: python3-pip installation failed, continuing without it"
    # Force configure any partially installed packages
    dpkg --configure -a || true
}

# Configure systemd-timesyncd for time synchronization
systemctl enable systemd-timesyncd

# Configure systemd for embedded system
systemctl mask systemd-logind.service
systemctl mask getty@tty2.service
systemctl mask getty@tty3.service
systemctl mask getty@tty4.service
systemctl mask getty@tty5.service
systemctl mask getty@tty6.service

# Enable serial console
systemctl enable serial-getty@ttyMV0.service

# Clean package cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Cleanup temporary mounts
umount /proc || true
umount /sys || true

EOF

# Install kernel modules
if [ -d "${MODULES_DIR}/lib/modules" ]; then
    echo "Installing kernel modules..."
    cp -r "${MODULES_DIR}/lib/modules"/* "${ROOTFS_DIR}/lib/modules/"
fi

# Install kernel firmware if available
if [ -d "${MODULES_DIR}/lib/firmware" ]; then
    echo "Installing kernel firmware..."
    cp -r "${MODULES_DIR}/lib/firmware"/* "${ROOTFS_DIR}/lib/firmware/" 2>/dev/null || true
fi

# Create device tree directory and install dtb files
mkdir -p "${ROOTFS_DIR}/boot/dtbs"
if [ -d "${OUTPUT_DIR}/kernel" ]; then
    cp "${OUTPUT_DIR}/kernel"/*.dtb "${ROOTFS_DIR}/boot/dtbs/" 2>/dev/null || true
fi

# Configure fstab
cat > "${ROOTFS_DIR}/etc/fstab" << 'FSTAB'
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root       /               ext4    defaults,noatime 0       1
tmpfs           /tmp            tmpfs   defaults,noatime,mode=1777 0 0
FSTAB

# Create boot script for U-Boot
cat > "${ROOTFS_DIR}/boot/boot.txt" << 'BOOTSCRIPT'
# ESPRESSOBin boot script
setenv bootargs "console=ttyMV0,115200 earlycon=ar3700_uart,0xd0012000 root=/dev/mmcblk0p1 rootfstype=ext4 rootwait net.ifnames=0 pci=nomsi"
ext4load mmc 0:1 $kernel_addr_r /boot/Image
ext4load mmc 0:1 $fdt_addr_r /boot/dtbs/armada-3720-espressobin.dtb
booti $kernel_addr_r - $fdt_addr_r
BOOTSCRIPT

# Compile boot script
mkimage -A arm64 -O linux -T script -C none -n "ESPRESSOBin Boot Script" \
    -d "${ROOTFS_DIR}/boot/boot.txt" "${ROOTFS_DIR}/boot/boot.scr" 2>/dev/null || true

# Remove QEMU static binary
rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

echo "Root filesystem created successfully!"
echo "Root filesystem is in: ${ROOTFS_DIR}"