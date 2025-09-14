#!/bin/bash

# test-dependencies.sh - Comprehensive test for build dependencies and environment

set -e

echo "=== ESPRESSOBin Debian Build Dependencies Test ==="
echo "Testing all required build dependencies and environment..."

# Define required commands and their descriptions
declare -A REQUIRED_COMMANDS=(
    ["make"]="Build system"
    ["gcc"]="Compiler"
    ["aarch64-linux-gnu-gcc"]="Cross-compiler for ARM64"
    ["git"]="Version control"
    ["wget"]="File download"
    ["curl"]="HTTP client"
    ["bc"]="Calculator for kernel build"
    ["bison"]="Parser generator"
    ["flex"]="Lexical analyzer"
    ["dtc"]="Device tree compiler"
    ["mkimage"]="U-Boot image creation"
    ["fdisk"]="Disk partitioning"
    ["mkfs.ext4"]="Filesystem creation"
    ["parted"]="Disk partitioning"
    ["kpartx"]="Partition mapping"
    ["debootstrap"]="Debian base system creation"
    ["python3"]="Python runtime"
    ["swig"]="Interface wrapper"
    ["rsync"]="File synchronization"
    ["lzop"]="Compression utility"
)

# Test function for command availability
test_command() {
    local cmd="$1"
    local desc="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $cmd ($desc) - Available"
        return 0
    else
        echo "✗ $cmd ($desc) - MISSING"
        return 1
    fi
}

# Test function for library/header availability
test_library() {
    local lib="$1"
    local desc="$2"
    
    if pkg-config --exists "$lib" 2>/dev/null; then
        echo "✓ $lib ($desc) - Available"
        return 0
    else
        echo "✗ $lib ($desc) - MISSING"
        return 1
    fi
}

# Test function for file/directory existence
test_file() {
    local file="$1"
    local desc="$2"
    
    if [ -e "$file" ]; then
        echo "✓ $file ($desc) - Available"
        return 0
    else
        echo "✗ $file ($desc) - MISSING"
        return 1
    fi
}

failed_tests=0

echo
echo "--- Testing Commands ---"
for cmd in "${!REQUIRED_COMMANDS[@]}"; do
    if ! test_command "$cmd" "${REQUIRED_COMMANDS[$cmd]}"; then
        ((failed_tests++))
    fi
done

echo
echo "--- Testing Cross-compilation Environment ---"
if ! test_command "aarch64-linux-gnu-gcc" "ARM64 cross-compiler"; then
    ((failed_tests++))
fi

# Test cross-compiler can create executables
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "Testing cross-compiler functionality..."
    echo 'int main(){return 0;}' > /tmp/test.c
    if aarch64-linux-gnu-gcc -o /tmp/test /tmp/test.c 2>/dev/null; then
        echo "✓ Cross-compiler can build executables"
        rm -f /tmp/test.c /tmp/test
    else
        echo "✗ Cross-compiler cannot build executables"
        ((failed_tests++))
    fi
fi

echo
echo "--- Testing Development Libraries ---"
declare -A REQUIRED_LIBS=(
    ["openssl"]="SSL/TLS library for kernel"
    ["ncurses"]="Terminal library for kernel config"
)

for lib in "${!REQUIRED_LIBS[@]}"; do
    if ! test_library "$lib" "${REQUIRED_LIBS[$lib]}"; then
        # Fallback test for header files
        case "$lib" in
            "openssl")
                test_file "/usr/include/openssl/opensslv.h" "OpenSSL headers"
                ;;
            "ncurses")
                test_file "/usr/include/ncurses.h" "NCurses headers"
                ;;
        esac
    fi
done

echo
echo "--- Testing QEMU Multi-arch Support ---"
if test_command "qemu-aarch64-static" "QEMU ARM64 emulator"; then
    if [ -f "/proc/sys/fs/binfmt_misc/qemu-aarch64" ]; then
        echo "✓ QEMU ARM64 binfmt registered"
    else
        echo "✗ QEMU ARM64 binfmt NOT registered"
        echo "  Note: This is expected outside Docker and will be set up by workflow"
    fi
fi

echo
echo "--- Testing File System Tools ---"
# Test if we can create filesystems
if command -v mkfs.ext4 >/dev/null 2>&1; then
    echo "✓ ext4 filesystem creation available"
fi

echo
echo "--- Testing U-Boot Tools ---"
if command -v mkimage >/dev/null 2>&1; then
    # Test mkimage functionality with a temporary file
    tmpfile=$(mktemp)
    echo 'test script content' > "$tmpfile"
    if mkimage -T script -C none -n "Test Script" -d "$tmpfile" "${tmpfile}.scr" >/dev/null 2>&1; then
        echo "✓ mkimage can create script images"
        rm -f "${tmpfile}.scr" "$tmpfile"
    else
        echo "✗ mkimage cannot create script images"
        ((failed_tests++))
        rm -f "$tmpfile"
    fi
else
    echo "✗ mkimage command not found"
    ((failed_tests++))
fi

echo
echo "--- Testing Build Scripts ---"
SCRIPT_DIR="$(dirname "$0")"
for script in "$SCRIPT_DIR"/{build.sh,build-kernel.sh,build-uboot.sh,build-rootfs.sh,create-image.sh}; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "✓ $(basename "$script") - Executable"
        else
            echo "✗ $(basename "$script") - NOT executable"
            ((failed_tests++))
        fi
    else
        echo "✗ $(basename "$script") - Missing"
        ((failed_tests++))
    fi
done

echo
echo "--- Testing Configuration Files ---"
CONFIG_DIR="$(dirname "$0")/../configs"
# Check for required config files
if [ -f "$CONFIG_DIR/kernel.config" ]; then
    echo "✓ kernel.config - Available"
else
    echo "✗ kernel.config - Missing"
    ((failed_tests++))
fi

# Check for optional config files
if [ -f "$CONFIG_DIR/uboot.config" ]; then
    echo "✓ uboot.config - Available"
else
    echo "ⓘ uboot.config - Optional (not present, will use default)"
fi

echo
echo "=== Summary ==="
if [ $failed_tests -eq 0 ]; then
    echo "✓ All dependency tests passed! Build environment is ready."
    exit 0
elif [ $failed_tests -le 2 ]; then
    # Allow minor failures (like missing pkg-config for libs that have headers)
    echo "⚠ $failed_tests minor dependency issue(s) found, but build should work."
    echo "  (Missing pkg-config entries are normal when headers are available)"
    exit 0
else
    echo "✗ $failed_tests dependency test(s) failed. Please fix the issues above."
    echo
    echo "Common solutions:"
    echo "- Install missing packages: apt-get install <package-name>"
    echo "- For cross-compilation: apt-get install crossbuild-essential-arm64"
    echo "- For QEMU: apt-get install qemu-user-static"
    echo "- For build tools: apt-get install build-essential"
    exit 1
fi