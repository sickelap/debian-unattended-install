.PHONY: all clean full-clean build install test start

all:
	@echo "make <clean|full-clean|build|install|test|start>"

build: _image install

clean:
	@echo "removing build artifacts"
	@rm -rf *.qcow2 efi-vars-*.fd debian-auto-*.iso .build

full-clean: clean
	@echo "removing downloaded installer artifacts"
	@rm -f debian-*-netinst.iso

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
	@if [ -n "$(SSH_PUBLIC_KEY_EFFECTIVE)" ]; then \
		printf '%s\n' "$(SSH_PUBLIC_KEY_EFFECTIVE)" > "$(AUTHORIZED_KEY_HOST_FILE)"; \
	else \
		: > "$(AUTHORIZED_KEY_HOST_FILE)"; \
		echo "WARNING: no SSH public key found (checked SSH_PUBLIC_KEY and $(SSH_PUBLIC_KEY_FILE)); proceeding without key-based SSH access."; \
	fi
	@printf '%s\n' \
		'set default=0' \
		'set timeout_style=hidden' \
		'set timeout=0' \
		'' \
		'menuentry '\''Unattended install (Btrfs snapshots)'\'' {' \
		'    linux /$(GRUB_INSTALL_DIR)/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg DEBIAN_FRONTEND=text console=tty0 console=$(SERIAL_CONSOLE),115200n8 ---' \
		'    initrd /$(GRUB_INSTALL_DIR)/initrd.gz' \
		'}' \
		'' \
		> "$(ISO_WORKDIR)/grub.cfg.auto"
	@rm -f "$(AUTO_ISO)"
	@xorriso -indev "$(ISO)" -outdev "$(AUTO_ISO)" \
		-boot_image any replay \
		-map "$(PRESEED)" /preseed.cfg \
		-map "$(AUTHORIZED_KEY_HOST_FILE)" "$(AUTHORIZED_KEY_ISO_PATH)" \
		-map "$(ISO_WORKDIR)/grub.cfg.auto" /boot/grub/grub.cfg >/dev/null
	@echo created $(AUTO_ISO)

_verify-iso: $(AUTO_ISO)
	@mkdir -p "$(ISO_WORKDIR)"
	@rm -f "$(ISO_WORKDIR)/verify-preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg" "$(ISO_WORKDIR)/verify-authorized_key.pub"
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /preseed.cfg "$(ISO_WORKDIR)/verify-preseed.cfg" >/dev/null
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract /boot/grub/grub.cfg "$(ISO_WORKDIR)/verify-grub.cfg" >/dev/null
	@xorriso -osirrox on -indev "$(AUTO_ISO)" -extract "$(AUTHORIZED_KEY_ISO_PATH)" "$(ISO_WORKDIR)/verify-authorized_key.pub" >/dev/null
	@rg -q "in-target sh -euxc" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "snapper --no-dbus -c root create-config /;" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "list-configs \\| grep -Eq" "$(ISO_WORKDIR)/verify-preseed.cfg"
	@rg -q "^set timeout_style=hidden$$" "$(ISO_WORKDIR)/verify-grub.cfg"
	@rg -q "^set timeout=0$$" "$(ISO_WORKDIR)/verify-grub.cfg"
	@test "$$(rg -c "^menuentry " "$(ISO_WORKDIR)/verify-grub.cfg")" -eq 1
	@rg -q "preseed/file=/cdrom/preseed.cfg" "$(ISO_WORKDIR)/verify-grub.cfg"
	@test -f "$(ISO_WORKDIR)/verify-authorized_key.pub"
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

start: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
start: _check _efi-vars
	@echo booting installed os from $(DISK) with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)
