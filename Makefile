QEMU ?= qemu-system-aarch64
QEMU_IMG ?= qemu-img
DISK ?= os.qcow2
DISK_SIZE ?= 20G

# Prefer stable Homebrew locations first, then any versioned Cellar fallback.
EFI_CODE ?= $(firstword $(wildcard /opt/homebrew/share/qemu/edk2-aarch64-code.fd /usr/local/share/qemu/edk2-aarch64-code.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-code.fd))
EFI_VARS_TEMPLATE ?= $(firstword $(wildcard /opt/homebrew/share/qemu/edk2-aarch64-vars.fd /opt/homebrew/share/qemu/edk2-arm-vars.fd /usr/local/share/qemu/edk2-aarch64-vars.fd /usr/local/share/qemu/edk2-arm-vars.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-vars.fd /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-arm-vars.fd))
EFI_VARS ?= efi-vars.fd

ISO ?= debian-13.3.0-arm64-netinst.iso
AUTO_ISO ?= debian-auto.iso
PRESEED ?= preseed.cfg
ISO_WORKDIR ?= .build/autoiso
# Default installer media is unattended ISO.
CDROM ?= $(AUTO_ISO)

RAM_MB ?= 2048
CPUS ?= 4
DISPLAY_ARGS ?= -display cocoa
MONITOR_ARGS ?= -monitor none
VIDEO_ARGS ?= -device ramfb
INPUT_ARGS ?=
INTERACTIVE_INPUT_ARGS ?= -device qemu-xhci -device usb-kbd -device usb-tablet
NETWORK_ARGS ?= -netdev user,id=net0 -device virtio-net,netdev=net0
EFI_ARGS = -drive if=pflash,format=raw,readonly=on,file="$(EFI_CODE)" -drive if=pflash,format=raw,file="$(EFI_VARS)"
QEMU_COMMON_ARGS = -machine virt,accel=hvf -cpu host -m $(RAM_MB) -smp $(CPUS) $(EFI_ARGS) $(VIDEO_ARGS) -drive if=virtio,file=$(DISK)

.PHONY: all build image iso verify-iso check efi-vars reset-efi-vars install install-interactive install-headless start

all:
	@echo "make <image|iso|verify-iso|install|install-interactive|install-headless|start|build>"

build: image install-headless

check:
	@test -n "$(EFI_CODE)" && test -f "$(EFI_CODE)" || (echo "EFI code image not found. Set EFI_CODE=/path/to/edk2-aarch64-code.fd"; exit 1)
	@test -n "$(EFI_VARS_TEMPLATE)" && test -f "$(EFI_VARS_TEMPLATE)" || (echo "EFI vars template not found. Set EFI_VARS_TEMPLATE=/path/to/edk2-*-vars.fd"; exit 1)
	@test -f "$(CDROM)" || (echo "CDROM/ISO not found: $(CDROM)"; exit 1)

image:
	@echo creating image $(DISK)
	@rm -f "$(DISK)"
	@$(QEMU_IMG) create -f qcow2 "$(DISK)" "$(DISK_SIZE)"

iso: $(AUTO_ISO)

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
		'    linux /install.a64/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg DEBIAN_FRONTEND=text console=tty0 console=ttyAMA0,115200n8 ---' \
		'    initrd /install.a64/initrd.gz' \
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

verify-iso: $(AUTO_ISO)
	@mkdir -p "$(ISO_WORKDIR)"
	@rm -f "$(ISO_WORKDIR)/verify-preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg"
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /preseed.cfg "$(ISO_WORKDIR)/verify-preseed.cfg" >/dev/null
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /boot/grub/grub.cfg "$(ISO_WORKDIR)/verify-grub.cfg" >/dev/null
	@rg -q "in-target sh -euxc" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "snapper --no-dbus -c root create-config /;" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "list-configs \\| grep -Eq" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "preseed/file=/cdrom/preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg"
	@echo "ISO verification passed: unattended boot + strict snapper late_command present."

efi-vars:
	@test -f "$(EFI_VARS)" || cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

reset-efi-vars:
	@cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

install: iso check reset-efi-vars
	@echo installing os from $(CDROM) in GUI window with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		-cdrom "$(CDROM)" \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)

install-interactive: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
install-interactive: install

install-headless: DISPLAY_ARGS=-display none -serial mon:stdio
install-headless: MONITOR_ARGS=
install-headless: INPUT_ARGS=
install-headless: install

start: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
start: check efi-vars
	@echo booting installed os from $(DISK) with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)
