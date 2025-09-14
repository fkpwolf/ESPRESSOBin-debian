# ESPRESSOBin Debian Image Builder

This project builds a complete Debian 13 (Trixie) ARM64 image for the ESPRESSOBin single-board computer, featuring:

- **Debian 13 (Trixie)** ARM64 base system
- **Latest stable LTS Linux kernel** (6.6.x series) with ESPRESSOBin support
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

### Serial Console:
- **Baud rate:** 115200 8N1
- **Connector:** microUSB port on ESPRESSOBin

### Hardware Support:
- ✅ Gigabit Ethernet (3 ports via switch)
- ✅ USB 3.0 and USB 2.0 ports
- ✅ SATA 3.0 connector
- ✅ microSD card slot
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
- Check switch configuration (if using managed network)

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
- **Storage:** microSD slot + SPI flash + SATA connector
- **Network:** 3x Gigabit Ethernet via Topaz switch
- **Connectivity:** USB 3.0, USB 2.0, mini-PCIe
- **Expansion:** 46-pin GPIO header

For more hardware details, visit: https://espressobin.net/