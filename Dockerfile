FROM debian:trixie-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

# Install build dependencies and cross-compilation tools
RUN apt-get update && apt-get install -y \
    build-essential \
    crossbuild-essential-arm64 \
    gcc-aarch64-linux-gnu \
    git \
    wget \
    curl \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses-dev \
    device-tree-compiler \
    u-boot-tools \
    fdisk \
    dosfstools \
    e2fsprogs \
    parted \
    kpartx \
    debootstrap \
    qemu-user-static \
    python3 \
    python3-pip \
    python3-setuptools \
    swig \
    libpython3-dev \
    uuid-dev \
    liblz4-tool \
    lzop \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Copy build scripts
COPY scripts/ ./scripts/
COPY configs/ ./configs/

# Set executable permissions for scripts
RUN chmod +x scripts/*.sh

# Default command
CMD ["./scripts/build.sh"]