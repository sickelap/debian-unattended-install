QEMU_IMG ?= qemu-img
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

DISK ?= os-$(ARCH).qcow2
EFI_VARS ?= efi-vars-$(ARCH).fd
AUTO_ISO ?= debian-auto-$(ARCH).iso
DEBIAN_VERSION ?= 13.3.0
ISO_FILENAME ?= debian-$(DEBIAN_VERSION)-$(ARCH)-netinst.iso
ISO_MIRROR ?= https://www.mirrorservice.org/sites/cdimage.debian.org/debian-cd/current
ISO_URL ?= $(ISO_MIRROR)/$(ISO_ARCH_DIR)/iso-cd/$(ISO_FILENAME)
ISO ?= $(ISO_FILENAME)
PRESEED ?= preseed.cfg
ISO_WORKDIR ?= .build/autoiso-$(ARCH)
# Default installer media is unattended ISO.
CDROM ?= $(AUTO_ISO)

RAM_MB ?= 2048
CPUS ?= 4
MONITOR_ARGS ?= -monitor none
INPUT_ARGS ?=
INTERACTIVE_INPUT_ARGS ?= -device qemu-xhci -device usb-kbd -device usb-tablet
NETWORK_ARGS ?= -netdev user,id=net0 -device virtio-net,netdev=net0

SSH_PUBLIC_KEY_FILE ?= $(firstword $(wildcard \
	$(HOME)/.ssh/id_ed25519.pub \
	$(HOME)/.ssh/id_ecdsa.pub \
	$(HOME)/.ssh/id_rsa.pub \
))
SSH_PUBLIC_KEY ?=
SSH_PUBLIC_KEY_EFFECTIVE := $(strip $(if $(SSH_PUBLIC_KEY),$(SSH_PUBLIC_KEY),$(if $(SSH_PUBLIC_KEY_FILE),$(file <$(SSH_PUBLIC_KEY_FILE)),)))
AUTHORIZED_KEY_ISO_PATH ?= /authorized_key.pub
AUTHORIZED_KEY_HOST_FILE ?= $(ISO_WORKDIR)/authorized_key.pub
