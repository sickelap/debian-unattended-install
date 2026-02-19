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
TIMEOUT ?= timeout
TEST_TIMEOUT ?= 45m
TEST_LOG_DIR ?= .build/test
TEST_LOG ?= $(TEST_LOG_DIR)/install-$(ARCH).log
TEST_DISK ?= $(TEST_LOG_DIR)/os-$(ARCH).qcow2
TEST_EFI_VARS ?= $(TEST_LOG_DIR)/efi-vars-$(ARCH).fd
TEST_TAIL_LINES ?= 80
TEST_SUCCESS_REGEX ?= reboot: (Restarting system|Power down|System halted)

ifeq ($(HOST_OS),Darwin)
ifeq ($(ARCH),arm64)
ACCEL ?= hvf
else
ACCEL ?= tcg
endif
DISPLAY_ARGS ?= -display cocoa
else
ACCEL ?= tcg
DISPLAY_ARGS ?= -display gtk
ifneq ($(wildcard /dev/kvm),)
ifeq ($(HOST_ARCH),$(ARCH))
ACCEL := kvm
endif
endif
endif

ifeq ($(ACCEL),tcg)
CPU_MODEL ?= max
else
CPU_MODEL ?= host
endif

EFI_ARGS = -drive if=pflash,format=raw,readonly=on,file="$(EFI_CODE)" \
	   -drive if=pflash,format=raw,file="$(EFI_VARS)"
QEMU_COMMON_ARGS = -machine $(MACHINE_TYPE),accel=$(ACCEL) \
		   -cpu $(CPU_MODEL) \
		   -m $(RAM_MB) \
		   -smp $(CPUS) \
		   -drive if=virtio,file=$(DISK) \
		   $(EFI_ARGS) \
		   $(VIDEO_ARGS)

.PHONY: all clean build install test start

all:
	@echo "make <clean|build|install|test|start>"

build: _image install

clean:
	@echo "removing generated artifacts"
	@rm -rf *.qcow2 efi-vars-*.fd *.iso .build

_check:
	@test -n "$(EFI_CODE)" && test -f "$(EFI_CODE)" || (echo "EFI code image not found for ARCH=$(ARCH). Set EFI_CODE=/path/to/$(EFI_CODE_HINT)"; exit 1)
	@test -n "$(EFI_VARS_TEMPLATE)" && test -f "$(EFI_VARS_TEMPLATE)" || (echo "EFI vars template not found for ARCH=$(ARCH). Set EFI_VARS_TEMPLATE=/path/to/$(EFI_VARS_HINT)"; exit 1)
	@test -f "$(CDROM)" || (echo "CDROM/ISO not found: $(CDROM)"; exit 1)

_image:
	@echo creating image $(DISK)
	@rm -f "$(DISK)"
	@$(QEMU_IMG) create -f qcow2 "$(DISK)" "$(DISK_SIZE)"

_iso: $(AUTO_ISO)

$(ISO):
	@echo "ISO not found locally: $(ISO)"
	@echo "downloading from $(ISO_URL)"
	@mkdir -p "$(dir $(ISO))"
	@if command -v curl >/dev/null 2>&1; then \
		curl -fL --progress-bar -o "$(ISO)" "$(ISO_URL)"; \
	elif command -v wget >/dev/null 2>&1; then \
		wget -O "$(ISO)" "$(ISO_URL)"; \
	else \
		echo "Neither curl nor wget found; install one to download ISO."; \
		exit 1; \
	fi

$(AUTO_ISO): $(ISO) $(PRESEED)
	@echo creating unattended iso $(AUTO_ISO)
	@rm -rf "$(ISO_WORKDIR)"
	@mkdir -p "$(ISO_WORKDIR)"
	@xorriso -osirrox on -indev "$(ISO)" -extract /boot/grub/grub.cfg "$(ISO_WORKDIR)/grub.cfg.orig" >/dev/null
	@printf '%s\n' \
		'set default=0' \
		'set timeout=3' \
		'' \
		'menuentry '\''Unattended install (Btrfs snapshots)'\'' {' \
		'    set background_color=black' \
		'    linux /$(GRUB_INSTALL_DIR)/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg DEBIAN_FRONTEND=text console=tty0 console=$(SERIAL_CONSOLE),115200n8 ---' \
		'    initrd /$(GRUB_INSTALL_DIR)/initrd.gz' \
		'}' \
		'' \
		> "$(ISO_WORKDIR)/grub.cfg.auto"
	@cat "$(ISO_WORKDIR)/grub.cfg.orig" >> "$(ISO_WORKDIR)/grub.cfg.auto"
	@rm -f "$(AUTO_ISO)"
	@xorriso -indev "$(ISO)" -outdev "$(AUTO_ISO)" \
		-boot_image any replay \
		-map "$(PRESEED)" /preseed.cfg \
		-map "$(ISO_WORKDIR)/grub.cfg.auto" /boot/grub/grub.cfg >/dev/null
	@echo created $(AUTO_ISO)

_verify-iso: $(AUTO_ISO)
	@mkdir -p "$(ISO_WORKDIR)"
	@rm -f "$(ISO_WORKDIR)/verify-preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg"
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /preseed.cfg "$(ISO_WORKDIR)/verify-preseed.cfg" >/dev/null
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /boot/grub/grub.cfg "$(ISO_WORKDIR)/verify-grub.cfg" >/dev/null
	@rg -q "in-target sh -euxc" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "snapper --no-dbus -c root create-config /;" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "list-configs \\| grep -Eq" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "preseed/file=/cdrom/preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg"
	@echo "ISO verification passed: unattended boot + strict snapper late_command present."

_efi-vars:
	@test -f "$(EFI_VARS)" || cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

_reset-efi-vars:
	@cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

_install: _iso _check _reset-efi-vars
	@echo "installing os from $(CDROM)"
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		-cdrom "$(CDROM)" \
		-no-reboot \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)

install: DISPLAY_ARGS=-display none -serial mon:stdio
install: MONITOR_ARGS=
install: INPUT_ARGS=
install: _install

test:
	@mkdir -p "$(TEST_LOG_DIR)"
	@echo "running unattended install test (tailing $(TEST_LOG))"
	@bash -o pipefail -c '\
	mkdir -p "$(TEST_LOG_DIR)"; \
	: > "$(TEST_LOG)"; \
	tail -n "$(TEST_TAIL_LINES)" -f "$(TEST_LOG)" & \
	tail_pid=$$!; \
	trap "kill $$tail_pid >/dev/null 2>&1 || true" EXIT INT TERM; \
	if [ "$(HOST_OS)" = "Linux" ]; then \
		command -v "$(TIMEOUT)" >/dev/null 2>&1 || { echo "missing timeout command ($(TIMEOUT)) on Linux host"; exit 1; }; \
		"$(TIMEOUT)" "$(TEST_TIMEOUT)" \
			$(MAKE) --no-print-directory _image _install \
				DISK="$(TEST_DISK)" \
				EFI_VARS="$(TEST_EFI_VARS)" \
				DISPLAY_ARGS="-display none -serial mon:stdio" \
				MONITOR_ARGS= \
				INPUT_ARGS= >>"$(TEST_LOG)" 2>&1; \
	else \
		$(MAKE) --no-print-directory _image _install \
			DISK="$(TEST_DISK)" \
			EFI_VARS="$(TEST_EFI_VARS)" \
			DISPLAY_ARGS="-display none -serial mon:stdio" \
			MONITOR_ARGS= \
			INPUT_ARGS= >>"$(TEST_LOG)" 2>&1; \
	fi; \
	install_status=$$?; \
	if [ $$install_status -ne 0 ]; then \
		echo "install test failed: installer command exited with $$install_status (see $(TEST_LOG))"; \
		exit $$install_status; \
	fi; \
	rg -q -e "$(TEST_SUCCESS_REGEX)" "$(TEST_LOG)" || { echo "install test failed: success marker not found in $(TEST_LOG)"; exit 1; }; \
	echo "install test passed"'

start: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
start: _check _efi-vars
	@echo booting installed os from $(DISK) with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)
