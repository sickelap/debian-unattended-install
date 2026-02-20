QEMU_IMG ?= qemu-img
QUIET ?= 1
DISK_SIZE ?= 20G
HOST_OS := $(shell uname -s)
HOST_ARCH_RAW := $(shell uname -m)
HOST_ARCH := $(HOST_ARCH_RAW)
ifeq ($(HOST_ARCH_RAW),x86_64)
HOST_ARCH := amd64
endif
ifeq ($(HOST_ARCH_RAW),aarch64)
HOST_ARCH := arm64
endif
ifeq ($(HOST_ARCH_RAW),arm64)
HOST_ARCH := arm64
endif

# ISO Source
DEBIAN_VERSION ?= 13.3.0
ISO_FILENAME ?= debian-$(DEBIAN_VERSION)-$(ARCH)-netinst.iso
ISO_MIRROR ?= https://www.mirrorservice.org/sites/cdimage.debian.org/debian-cd/current
ISO_URL ?= $(ISO_MIRROR)/$(ISO_ARCH_DIR)/iso-cd/$(ISO_FILENAME)
ISO ?= $(ISO_FILENAME)

# Installer Assets
PRESEED ?= preseed.cfg
INSTALLER_HOOKS_DIR ?= scripts
PARTMAN_EARLY_SCRIPT ?= $(INSTALLER_HOOKS_DIR)/partman-early.sh
PRESEED_LATE_SCRIPT ?= $(INSTALLER_HOOKS_DIR)/preseed-late.sh
INSTALLER_COMMON_SCRIPT ?= $(INSTALLER_HOOKS_DIR)/common.sh
PARTMAN_EARLY_ISO_PATH ?= /installer-hooks/partman-early.sh
PRESEED_LATE_ISO_PATH ?= /installer-hooks/preseed-late.sh
INSTALLER_COMMON_ISO_PATH ?= /installer-hooks/common.sh
ISO_WORKDIR ?= .build/autoiso-$(ARCH)
SCRIPTS_DIR ?= scripts
BUILD_AUTO_ISO_SCRIPT ?= $(SCRIPTS_DIR)/build_auto_iso.sh
VERIFY_AUTO_ISO_SCRIPT ?= $(SCRIPTS_DIR)/verify_auto_iso.sh
VERIFY_PRESEED_HOST_FILE ?= $(ISO_WORKDIR)/verify-preseed.cfg
VERIFY_GRUB_HOST_FILE ?= $(ISO_WORKDIR)/verify-grub.cfg
VERIFY_AUTHORIZED_KEY_HOST_FILE ?= $(ISO_WORKDIR)/verify-authorized_key.pub
VERIFY_PARTMAN_EARLY_HOST_FILE ?= $(ISO_WORKDIR)/verify-partman-early.sh
VERIFY_PRESEED_LATE_HOST_FILE ?= $(ISO_WORKDIR)/verify-preseed-late.sh
VERIFY_INSTALLER_COMMON_HOST_FILE ?= $(ISO_WORKDIR)/verify-installer-common.sh

# Boot/Installer
AUTO_ISO_INSTALL ?= debian-auto-install-$(ARCH).iso
AUTO_ISO_TEST ?= debian-auto-test-$(ARCH).iso
AUTO_ISO ?= $(AUTO_ISO_INSTALL)
# Default installer media is unattended ISO.
CDROM ?= $(AUTO_ISO)
GRUB_KERNEL_ARGS_COMMON ?= auto=true priority=critical preseed/file=/cdrom/preseed.cfg
GRUB_KERNEL_ARGS_INSTALL ?= $(GRUB_KERNEL_ARGS_COMMON) console=tty0
GRUB_KERNEL_ARGS_TEST ?= $(GRUB_KERNEL_ARGS_COMMON) DEBIAN_FRONTEND=text console=$(SERIAL_CONSOLE),115200n8
GRUB_KERNEL_ARGS ?= $(GRUB_KERNEL_ARGS_INSTALL)

# VM Runtime
DISK ?= os-$(ARCH).qcow2
EFI_VARS ?= efi-vars-$(ARCH).fd
RAM_MB ?= 2048
CPUS ?= 4
MONITOR_ARGS ?= -monitor none
INPUT_ARGS ?=
INTERACTIVE_INPUT_ARGS ?= -device qemu-xhci -device usb-kbd -device usb-tablet
NETWORK_ARGS ?= -netdev user,id=net0 -device virtio-net,netdev=net0

# SSH Injection
SSH_PUBLIC_KEY_GLOB ?= $(HOME)/.ssh/id_*.pub
SSH_PUBLIC_KEY_FILES ?= $(sort $(wildcard $(SSH_PUBLIC_KEY_GLOB)))
# Backward-compatible alias for legacy single-key workflows.
SSH_PUBLIC_KEY_FILE ?= $(firstword $(SSH_PUBLIC_KEY_FILES))
SSH_PUBLIC_KEY ?=
AUTHORIZED_KEY_ISO_PATH ?= /authorized_key.pub
AUTHORIZED_KEY_HOST_FILE ?= $(ISO_WORKDIR)/authorized_key.pub
