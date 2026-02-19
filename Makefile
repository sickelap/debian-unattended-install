QEMU ?= qemu-system-aarch64
QEMU_IMG ?= qemu-img
DISK ?= os.qcow2
DISK_SIZE ?= 20G

# Prefer stable Homebrew locations first, then any versioned Cellar fallback.
EFI_CODE ?= $(firstword $(wildcard /opt/homebrew/share/qemu/edk2-aarch64-code.fd /usr/local/share/qemu/edk2-aarch64-code.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-code.fd))
EFI_VARS_TEMPLATE ?= $(firstword $(wildcard /opt/homebrew/share/qemu/edk2-aarch64-vars.fd /opt/homebrew/share/qemu/edk2-arm-vars.fd /usr/local/share/qemu/edk2-aarch64-vars.fd /usr/local/share/qemu/edk2-arm-vars.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-vars.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-arm-vars.fd))
EFI_VARS ?= efi-vars.fd

ISO ?= debian-13.3.0-arm64-netinst.iso
# CDROM can be overridden for unattended ISOs, e.g. `make install CDROM=debian-auto.iso`.
CDROM ?= $(ISO)

RAM_MB ?= 2048
CPUS ?= 4
DISPLAY_ARGS ?= -display cocoa
MONITOR_ARGS ?= -monitor none
VIDEO_ARGS ?= -device ramfb
INPUT_ARGS ?= -device qemu-xhci -device usb-kbd -device usb-tablet
NETWORK_ARGS ?= -netdev user,id=net0 -device virtio-net,netdev=net0
EFI_ARGS = -drive if=pflash,format=raw,readonly=on,file="$(EFI_CODE)" -drive if=pflash,format=raw,file="$(EFI_VARS)"
QEMU_COMMON_ARGS = -machine virt,accel=hvf -cpu host -m $(RAM_MB) -smp $(CPUS) $(EFI_ARGS) $(VIDEO_ARGS) -drive if=virtio,file=$(DISK)

.PHONY: all build image iso check efi-vars reset-efi-vars install install-headless start

all:
	@echo "make <image|install|install-headless|start|build>"

build: image install

check:
	@test -n "$(EFI_CODE)" && test -f "$(EFI_CODE)" || (echo "EFI code image not found. Set EFI_CODE=/path/to/edk2-aarch64-code.fd"; exit 1)
	@test -n "$(EFI_VARS_TEMPLATE)" && test -f "$(EFI_VARS_TEMPLATE)" || (echo "EFI vars template not found. Set EFI_VARS_TEMPLATE=/path/to/edk2-*-vars.fd"; exit 1)
	@test -f "$(CDROM)" || (echo "CDROM/ISO not found: $(CDROM)"; exit 1)

image:
	@echo creating image $(DISK)
	@rm -f "$(DISK)"
	@$(QEMU_IMG) create -f qcow2 "$(DISK)" "$(DISK_SIZE)"

iso:
	@echo "No ISO build step configured. Use CDROM=<path-to-iso>."

efi-vars:
	@test -f "$(EFI_VARS)" || cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

reset-efi-vars:
	@cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

install: check reset-efi-vars
	@echo installing os from $(CDROM) in GUI window with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		-cdrom "$(CDROM)" \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)

install-headless: DISPLAY_ARGS=-display none -serial mon:stdio
install-headless: MONITOR_ARGS=
install-headless: VIDEO_ARGS=
install-headless: INPUT_ARGS=
install-headless: install

start: check efi-vars
	@echo booting installed os from $(DISK) with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)
