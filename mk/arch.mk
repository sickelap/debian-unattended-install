ifeq ($(HOST_OS),Darwin)
ARCH ?= arm64
else
ARCH ?= amd64
endif

SUPPORTED_ARCHES := amd64 arm64
ifeq ($(filter $(ARCH),$(SUPPORTED_ARCHES)),)
$(error Unsupported ARCH '$(ARCH)'. Use ARCH=amd64 or ARCH=arm64)
endif

ifeq ($(ARCH),amd64)
QEMU ?= qemu-system-x86_64
MACHINE_TYPE ?= q35
GRUB_INSTALL_DIR ?= install.amd
SERIAL_CONSOLE ?= ttyS0
ISO_ARCH_DIR ?= amd64
VIDEO_ARGS ?=
EFI_CODE_HINT ?= OVMF_CODE.fd
EFI_VARS_HINT ?= OVMF_VARS.fd
EFI_CODE ?= $(firstword $(wildcard \
	/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
	/usr/local/share/qemu/edk2-x86_64-code.fd \
	/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-x86_64-code.fd \
	/usr/share/OVMF/OVMF_CODE_4M.fd \
	/usr/share/OVMF/OVMF_CODE.fd \
	/usr/share/edk2/ovmf/OVMF_CODE.fd \
	/usr/share/edk2/x64/OVMF_CODE.fd \
	/usr/share/qemu/OVMF_CODE.fd \
))
EFI_VARS_TEMPLATE ?= $(firstword $(wildcard \
	/opt/homebrew/share/qemu/edk2-x86_64-vars.fd \
	/usr/local/share/qemu/edk2-x86_64-vars.fd \
	/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-x86_64-vars.fd \
	/usr/share/OVMF/OVMF_VARS_4M.fd \
	/usr/share/OVMF/OVMF_VARS.fd \
	/usr/share/edk2/ovmf/OVMF_VARS.fd \
	/usr/share/edk2/x64/OVMF_VARS.fd \
	/usr/share/qemu/OVMF_VARS.fd \
))
else
QEMU ?= qemu-system-aarch64
MACHINE_TYPE ?= virt
GRUB_INSTALL_DIR ?= install.a64
SERIAL_CONSOLE ?= ttyAMA0
ISO_ARCH_DIR ?= arm64
VIDEO_ARGS ?= -device ramfb
EFI_CODE_HINT ?= edk2-aarch64-code.fd
EFI_VARS_HINT ?= edk2-aarch64-vars.fd
EFI_CODE ?= $(firstword $(wildcard \
	/opt/homebrew/share/qemu/edk2-aarch64-code.fd \
	/usr/local/share/qemu/edk2-aarch64-code.fd \
	/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-code.fd \
	/usr/share/qemu/edk2-aarch64-code.fd \
	/usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
	/usr/share/AAVMF/AAVMF_CODE.fd \
	/usr/share/edk2/aarch64/QEMU_EFI.fd \
))
EFI_VARS_TEMPLATE ?= $(firstword $(wildcard \
	/opt/homebrew/share/qemu/edk2-aarch64-vars.fd \
	/opt/homebrew/share/qemu/edk2-arm-vars.fd \
	/usr/local/share/qemu/edk2-aarch64-vars.fd \
	/usr/local/share/qemu/edk2-arm-vars.fd \
	/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-vars.fd \
	/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-arm-vars.fd \
	/usr/share/qemu/edk2-aarch64-vars.fd \
	/usr/share/qemu/edk2-arm-vars.fd \
	/usr/share/AAVMF/AAVMF_VARS.fd \
	/usr/share/edk2/aarch64/vars-template-pflash.raw \
))
endif
