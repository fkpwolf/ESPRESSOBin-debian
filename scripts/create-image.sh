#!/bin/bash

set -e

# Create final ESPRESSOBin image

OUTPUT_DIR="/build/output"
ROOTFS_DIR="/build/rootfs"
IMAGE_FILE="${OUTPUT_DIR}/espressobin-debian.img"
IMAGE_SIZE="2G"

echo "Creating ESPRESSOBin Debian image..."

# Create image file
dd if=/dev/zero of="${IMAGE_FILE}" bs=1 count=0 seek="${IMAGE_SIZE}" status=progress

# Create partition table
parted "${IMAGE_FILE}" --script -- \
    mklabel msdos \
    mkpart primary ext4 1MiB 100%

# Setup loop device
LOOP_DEVICE=$(losetup -f --show "${IMAGE_FILE}")
PARTITION_DEVICE="${LOOP_DEVICE}p1"

# Wait for partition device to be available
sleep 2
if [ ! -b "${PARTITION_DEVICE}" ]; then
    # Try kpartx if direct partition access doesn't work
    kpartx -av "${LOOP_DEVICE}"
    PARTITION_DEVICE="/dev/mapper/$(basename ${LOOP_DEVICE})p1"
fi

# Format partition
mkfs.ext4 -F -L "ROOTFS" "${PARTITION_DEVICE}"

# Mount partition
MOUNT_POINT="/mnt/espressobin"
mkdir -p "${MOUNT_POINT}"
mount "${PARTITION_DEVICE}" "${MOUNT_POINT}"

# Copy root filesystem
echo "Copying root filesystem to image..."
rsync -a "${ROOTFS_DIR}/" "${MOUNT_POINT}/"

# Copy kernel to boot partition
mkdir -p "${MOUNT_POINT}/boot"
if [ -f "${OUTPUT_DIR}/kernel/Image" ]; then
    cp "${OUTPUT_DIR}/kernel/Image" "${MOUNT_POINT}/boot/"
fi
if [ -f "${OUTPUT_DIR}/kernel/uImage" ]; then
    cp "${OUTPUT_DIR}/kernel/uImage" "${MOUNT_POINT}/boot/"
fi

# Sync and unmount
sync
umount "${MOUNT_POINT}"

# Cleanup loop device
if [ -b "/dev/mapper/$(basename ${LOOP_DEVICE})p1" ]; then
    kpartx -dv "${LOOP_DEVICE}"
fi
losetup -d "${LOOP_DEVICE}"

# Compress image
echo "Compressing image..."
gzip -c "${IMAGE_FILE}" > "${IMAGE_FILE}.gz"

# Create checksums
cd "${OUTPUT_DIR}"
sha256sum "$(basename ${IMAGE_FILE})" > "$(basename ${IMAGE_FILE}).sha256"
sha256sum "$(basename ${IMAGE_FILE}).gz" > "$(basename ${IMAGE_FILE}).gz.sha256"

# Create flash instructions
cat > "${OUTPUT_DIR}/FLASH_INSTRUCTIONS.txt" << 'INSTRUCTIONS'
ESPRESSOBin Debian Image Flash Instructions
==========================================

Files included:
- espressobin-debian.img: Raw disk image
- espressobin-debian.img.gz: Compressed disk image
- u-boot/: U-Boot bootloader files
- kernel/: Linux kernel files

=== FLASHING TO MICROSD CARD ===

1. Extract the compressed image:
   gunzip espressobin-debian.img.gz

2. Flash to microSD card (replace /dev/sdX with your SD card device):
   sudo dd if=espressobin-debian.img of=/dev/sdX bs=4M status=progress oflag=sync

3. Insert microSD card into ESPRESSOBin and boot

=== FLASHING TO eMMC MODULE ===

WARNING: Flashing to eMMC will permanently overwrite existing data!

Prerequisites:
- ESPRESSOBin with eMMC module installed  
- Working boot environment (microSD or U-Boot via network/USB)
- Serial console access (115200 8N1)

Method 1 - Direct flash from running Linux:
1. Check if eMMC is detected: lsblk (look for mmcblk1)
2. Extract: gunzip espressobin-debian.img.gz  
3. Flash: sudo dd if=espressobin-debian.img of=/dev/mmcblk1 bs=4M status=progress oflag=sync
4. Configure U-Boot to boot from eMMC (see README.md)

Method 2 - Flash via U-Boot console:
1. Load image via TFTP: tftp $loadaddr espressobin-debian.img
2. Select eMMC: mmc dev 1
3. Flash: mmc write $loadaddr 0 $filesize
4. Configure boot environment for eMMC

=== U-BOOT SPI FLASH UPDATE ===

3. Flash U-Boot to SPI flash (if needed):
   - Connect to ESPRESSOBin via serial console
   - Boot from existing bootloader or recovery mode
   - Use tftp or fatload to load u-boot/flash-image.bin
   - Flash to SPI: sf probe; sf erase 0 +200000; sf write $loadaddr 0 $filesize

Default credentials:
- Username: debian
- Password: debian
- Root password: root

Serial console: 115200 8N1 on microUSB connector
Network: DHCP enabled on eth0

First boot may take several minutes to complete initial setup.

For detailed instructions and troubleshooting, see README.md
INSTRUCTIONS

echo "========================================"
echo "Image creation completed successfully!"
echo "========================================"
echo "Image file: ${IMAGE_FILE}"
echo "Compressed: ${IMAGE_FILE}.gz"
echo "Size: $(du -h ${IMAGE_FILE} | cut -f1)"
echo "Compressed size: $(du -h ${IMAGE_FILE}.gz | cut -f1)"
echo "========================================"