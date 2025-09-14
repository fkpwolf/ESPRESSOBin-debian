# ESPRESSOBin Debian Image Builder Makefile

.PHONY: all clean build-docker run-build help test-deps

DOCKER_IMAGE := espressobin-builder
DOCKER_TAG := latest
OUTPUT_DIR := ./output

all: build

help:
	@echo "ESPRESSOBin Debian Image Builder"
	@echo "================================"
	@echo "Available targets:"
	@echo "  build        - Build the complete ESPRESSOBin Debian image"
	@echo "  build-docker - Build the Docker container for building"
	@echo "  run-build    - Run the build process in Docker container"
	@echo "  test-deps    - Test build dependencies in container"
	@echo "  clean        - Clean build artifacts"
	@echo "  shell        - Open a shell in the build container"
	@echo "  help         - Show this help message"

build-docker:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

build: build-docker
	@echo "Starting build process..."
	mkdir -p $(OUTPUT_DIR)
	docker run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

run-build: build-docker
	@echo "Running build in container..."
	mkdir -p $(OUTPUT_DIR)
	docker run --rm --privileged -it \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		/bin/bash

shell: build-docker
	@echo "Opening shell in build container..."
	mkdir -p $(OUTPUT_DIR)
	docker run --rm --privileged -it \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		/bin/bash

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUTPUT_DIR)
	docker rmi -f $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true

# Individual build steps (for development)
uboot: build-docker
	docker run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		./scripts/build-uboot.sh

kernel: build-docker
	docker run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		./scripts/build-kernel.sh

rootfs: build-docker
	docker run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/build/output \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		./scripts/build-rootfs.sh

test-deps: build-docker
	@echo "Testing build dependencies..."
	docker run --rm \
		-v $(PWD)/scripts:/build/scripts \
		-v $(PWD)/configs:/build/configs \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		./scripts/test-dependencies.sh