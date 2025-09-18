# ESPRESSOBin Debian Image Builder

This project builds a complete Debian 13 (Trixie) ARM64 image for the ESPRESSOBin single-board computer, featuring:

- **Debian 13 (Trixie)** ARM64 base system
- **Latest stable LTS Linux kernel** (6.12.x series) with ESPRESSOBin support
- **Latest U-Boot bootloader** (2024.01) with proper ESPRESSOBin configuration
- **ARM Trusted Firmware** for secure boot
- **Complete embedded Linux system** ready to flash and boot

## Features

- **Cross-compilation environment** using Docker for reproducible builds
- **Optimized kernel configuration** for ESPRESSOBin hardware (Armada 3720 SoC)
- **Complete device support** including GPIO, SPI, I2C, UART, USB, SATA, and networking
- **Systemd-based init system** with proper embedded system optimizations
- **SSH access** with default credentials for initial setup
- **Network-ready** with DHCP and NetworkManager
- **Development tools** included for on-device compilation

## Requirements

- Docker with privileged container support
- At least 8GB of free disk space
- Internet connection for downloading sources

## Quick Start

### Build the complete image:

```bash
make build
```

This will:
1. Build the Docker container with all build dependencies
2. Download and compile U-Boot for ESPRESSOBin
3. Download and compile the Linux kernel with ESPRESSOBin support
4. Create a Debian 13 ARM64 root filesystem
5. Generate the final flashable image

### Individual build steps (for development):

```bash
make uboot    # Build only U-Boot
make kernel   # Build only Linux kernel  
make rootfs   # Build only root filesystem
```

### Development shell:

```bash
make shell    # Open interactive shell in build container
```

## Output Files

After successful build, the `output/` directory contains:

- `espressobin-debian.img` - Raw disk image (ready to flash)
- `espressobin-debian.img.gz` - Compressed disk image
- `espressobin-debian.img.sha256` - Checksum file
- `u-boot/` - U-Boot bootloader files
- `kernel/` - Linux kernel and device tree files
- `FLASH_INSTRUCTIONS.txt` - Detailed flashing instructions

## Flashing Instructions

### To microSD card:

1. Extract the compressed image:
   ```bash
   gunzip output/espressobin-debian.img.gz
   ```

2. Flash to microSD card (replace `/dev/sdX` with your SD card):
   ```bash
   sudo dd if=output/espressobin-debian.img of=/dev/sdX bs=4M status=progress oflag=sync
   ```

3. Insert microSD card into ESPRESSOBin and boot

### To eMMC module:

**⚠️ WARNING: Flashing to eMMC will permanently overwrite existing data. Ensure you have backups if needed.**

If your ESPRESSOBin has an eMMC module installed, you can flash directly to it for better performance and reliability:

1. **Prerequisites:**
   - ESPRESSOBin with eMMC module installed
   - Working boot environment (microSD with working system or U-Boot via TFTP/USB)
   - Serial console access (115200 8N1)

2. **Detect eMMC module:**
   Boot your ESPRESSOBin and check if eMMC is detected:
   ```bash
   # Check if eMMC is present
   lsblk
   # Look for mmcblk1 (eMMC) - mmcblk0 is typically microSD
   
   # Or check dmesg for eMMC detection
   dmesg | grep -i mmc
   ```

3. **Flash the image:**
   
   **Method 1: Direct flash from running Linux system**
   ```bash
   # Extract the image
   gunzip espressobin-debian.img.gz
   
   # Flash to eMMC (usually /dev/mmcblk1)
   sudo dd if=espressobin-debian.img of=/dev/mmcblk1 bs=4M status=progress oflag=sync
   
   # Verify the flash
   sudo sync
   ```
   
   **Method 2: Flash via U-Boot console**
   ```bash
   # Boot to U-Boot prompt and load image via TFTP or USB
   # Example using TFTP:
   setenv serverip 192.168.1.100
   setenv ipaddr 192.168.1.50
   tftp $loadaddr espressobin-debian.img
   
   # Flash to eMMC
   mmc dev 1  # Select eMMC device
   mmc write $loadaddr 0 $filesize
   
   # Example using USB:
   usb start
   fatload usb 0 $loadaddr espressobin-debian.img
   mmc dev 1
   mmc write $loadaddr 0 $filesize
   ```

4. **Configure boot from eMMC:**
   Update U-Boot environment to boot from eMMC:
   ```bash
   # In U-Boot console:
   setenv bootcmd 'setenv bootargs "console=ttyMV0,115200 earlycon=ar3700_uart,0xd0012000 root=/dev/mmcblk1p1 rootfstype=ext4 rootwait net.ifnames=0"; ext4load mmc 1:1 $kernel_addr_r /boot/Image; ext4load mmc 1:1 $fdt_addr_r /boot/dtbs/armada-3720-espressobin-emmc.dtb; booti $kernel_addr_r - $fdt_addr_r'
   saveenv
   ```

5. **Remove microSD and reboot:**
   - Power off the ESPRESSOBin
   - Remove any microSD card
   - Power on - system should now boot from eMMC

### U-Boot to SPI Flash (optional):

If you need to update the SPI flash with new U-Boot:

1. Copy `output/u-boot/flash-image.bin` to TFTP server or FAT32 USB drive
2. Boot ESPRESSOBin and access U-Boot console
3. Load the file and flash:
   ```
   sf probe
   sf erase 0 +200000
   # Load via TFTP: tftp $loadaddr flash-image.bin
   # Or via USB: fatload usb 0 $loadaddr flash-image.bin
   sf write $loadaddr 0 $filesize
   ```

## System Details

### Default Credentials:
- Username: `debian` / Password: `debian`
- Root password: `root`

### Network Configuration:
- DHCP enabled on eth0
- SSH server enabled (port 22)
- **Switch Configuration:** The ESPRESSOBin features a built-in Marvell 88E6341 Topaz switch with 3 Gigabit Ethernet ports:
  - `wan`: Connects to internet/WAN (closest to power connector)
  - `lan0`: LAN port 1 (middle port)
  - `lan1`: LAN port 2 (closest to USB ports)
- DSA (Distributed Switch Architecture) provides full switch functionality
- **mv88e6xxx driver enabled** for full switch support
- Each port appears as a separate network interface (wan, lan0, lan1)
- VLAN support available for network segmentation

### Serial Console:
- **Baud rate:** 115200 8N1
- **Connector:** microUSB port on ESPRESSOBin

### Hardware Support:
- ✅ **Gigabit Ethernet (3 ports via Marvell 88E6341 Topaz switch)**
  - Port wan: WAN/Internet connection
  - Port lan0: LAN port 1
  - Port lan1: LAN port 2
  - Full DSA (Distributed Switch Architecture) support
  - VLAN support and port isolation
- ✅ USB 3.0 and USB 2.0 ports
- ✅ SATA 3.0 connector
- ✅ microSD card slot
- ✅ eMMC module support (if installed)
- ✅ SPI flash (for bootloader)
- ✅ GPIO expansion headers
- ✅ I2C, SPI, UART interfaces
- ✅ Mini-PCIe slot (for WiFi modules)
- ✅ CPU frequency scaling
- ✅ Hardware watchdog
- ✅ RTC support

## Customization

### Kernel Configuration:
Edit `configs/kernel.config` to add/modify kernel options.

### U-Boot Configuration:
Add custom U-Boot options in `configs/uboot.config`.

### Root Filesystem:
Modify `scripts/build-rootfs.sh` to customize the Debian installation.

## Troubleshooting

### Build Issues:
- Ensure Docker has privileged access
- Check available disk space (minimum 8GB)
- Verify internet connectivity for source downloads

### Boot Issues:
- Check serial console connection (115200 8N1)
- Verify microSD card is properly flashed
- Ensure ESPRESSOBin boot switches are set to boot from microSD

### Network Issues:
- Check Ethernet cable connections
- Verify DHCP server is available
- Check switch configuration: `ip link show` should display wan, lan0, lan1 interfaces
- **Switch troubleshooting:**
  - If switch ports don't appear, check kernel logs: `dmesg | grep -i dsa`
  - Verify switch chip detection: `dmesg | grep -i 88e6341`
  - Configure switch ports: `ip link set wan up`, `ip link set lan0 up`, `ip link set lan1 up`
  - Check port status: `cat /sys/class/net/*/operstate`

### eMMC Issues:
- Verify eMMC module is properly installed and detected: `lsblk` or `dmesg | grep mmc`
- Check that eMMC device appears as `/dev/mmcblk1` (microSD is typically `/dev/mmcblk0`)
- Ensure U-Boot environment is configured for eMMC boot (see eMMC flashing instructions)
- If eMMC fails to boot, try booting from microSD and reflashing eMMC
- For persistent eMMC boot issues, check boot switches and U-Boot configuration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build process
5. Submit a pull request

## License

This project is released under the MIT License. See individual component licenses for U-Boot, Linux kernel, and Debian packages.

## ESPRESSOBin Hardware Information

The ESPRESSOBin is an ARM64 development board featuring:
- **SoC:** Marvell Armada 3720 (dual-core ARM Cortex-A53)
- **RAM:** 1GB or 2GB DDR3
- **Storage:** microSD slot + optional eMMC module + SPI flash + SATA connector
- **Network:** 3x Gigabit Ethernet via Topaz switch
- **Connectivity:** USB 3.0, USB 2.0, mini-PCIe
- **Expansion:** 46-pin GPIO header

For more hardware details, visit: https://espressobin.net/