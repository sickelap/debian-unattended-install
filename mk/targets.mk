.PHONY: all clean full-clean _precheck _precheck-tools _precheck-firmware _precheck-iso-download-tool build install test start _verify-iso _verify-iso-extract _verify-iso-preseed _verify-iso-grub _verify-iso-hooks _verify-iso-ssh

all: _precheck
	@echo "make <clean|full-clean|build|install|test|start>"

build: _precheck _image _iso _verify-iso
	@echo "build finished."

clean:
	@echo "removing build artifacts"
	@rm -rf *.qcow2 efi-vars-*.fd debian-auto-*.iso debian-auto-install-*.iso debian-auto-test-*.iso .build
	@echo "clean finished."

full-clean: clean
	@echo "removing downloaded installer artifacts"
	@rm -f debian-*-netinst.iso

_precheck: _precheck-tools _precheck-firmware _precheck-iso-download-tool
	@echo "precheck passed: prerequisites available."

_precheck-tools:
	@command -v "$(QEMU_IMG)" >/dev/null 2>&1 || (echo "Missing required command: $(QEMU_IMG)."; exit 1)
	@command -v xorriso >/dev/null 2>&1 || (echo "Missing required command: xorriso."; exit 1)
	@command -v rg >/dev/null 2>&1 || (echo "Missing required command: rg."; exit 1)

_precheck-firmware:
	@test -n "$(EFI_CODE)" && test -f "$(EFI_CODE)" || (echo "EFI code image not found for ARCH=$(ARCH). Set EFI_CODE=/path/to/$(EFI_CODE_HINT)"; exit 1)
	@test -n "$(EFI_VARS_TEMPLATE)" && test -f "$(EFI_VARS_TEMPLATE)" || (echo "EFI vars template not found for ARCH=$(ARCH). Set EFI_VARS_TEMPLATE=/path/to/$(EFI_VARS_HINT)"; exit 1)

_precheck-iso-download-tool:
	@if [ ! -f "$(ISO)" ]; then \
		if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then \
			echo "ISO $(ISO) is missing and neither curl nor wget is available to download it."; \
			exit 1; \
		fi; \
	fi

_check:
	@command -v "$(QEMU)" >/dev/null 2>&1 || (echo "Missing required command: $(QEMU)."; exit 1)
	@test -n "$(EFI_CODE)" && test -f "$(EFI_CODE)" || (echo "EFI code image not found for ARCH=$(ARCH). Set EFI_CODE=/path/to/$(EFI_CODE_HINT)"; exit 1)
	@test -n "$(EFI_VARS_TEMPLATE)" && test -f "$(EFI_VARS_TEMPLATE)" || (echo "EFI vars template not found for ARCH=$(ARCH). Set EFI_VARS_TEMPLATE=/path/to/$(EFI_VARS_HINT)"; exit 1)
	@test -f "$(CDROM)" || (echo "CDROM/ISO not found: $(CDROM)"; exit 1)

_image:
	@echo creating image $(DISK)
	@rm -f "$(DISK)"
	@if [ "$(QUIET)" = "1" ]; then \
		$(QEMU_IMG) create -f qcow2 "$(DISK)" "$(DISK_SIZE)" >/dev/null 2>&1; \
	else \
		$(QEMU_IMG) create -f qcow2 "$(DISK)" "$(DISK_SIZE)"; \
	fi
	@echo "image creation finished."

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

$(AUTO_ISO): $(ISO) $(PRESEED) $(PARTMAN_EARLY_SCRIPT) $(PRESEED_LATE_SCRIPT) $(INSTALLER_COMMON_SCRIPT) $(BUILD_AUTO_ISO_SCRIPT)
	@echo "==> creating unattended iso $(AUTO_ISO)"
	@ISO="$(ISO)" \
	AUTO_ISO="$(AUTO_ISO)" \
	PRESEED="$(PRESEED)" \
	PARTMAN_EARLY_SCRIPT="$(PARTMAN_EARLY_SCRIPT)" \
	PARTMAN_EARLY_ISO_PATH="$(PARTMAN_EARLY_ISO_PATH)" \
	PRESEED_LATE_SCRIPT="$(PRESEED_LATE_SCRIPT)" \
	PRESEED_LATE_ISO_PATH="$(PRESEED_LATE_ISO_PATH)" \
	INSTALLER_COMMON_SCRIPT="$(INSTALLER_COMMON_SCRIPT)" \
	INSTALLER_COMMON_ISO_PATH="$(INSTALLER_COMMON_ISO_PATH)" \
	ISO_WORKDIR="$(ISO_WORKDIR)" \
	GRUB_INSTALL_DIR="$(GRUB_INSTALL_DIR)" \
	GRUB_KERNEL_ARGS="$(GRUB_KERNEL_ARGS)" \
	SSH_PUBLIC_KEY="$(SSH_PUBLIC_KEY)" \
	SSH_PUBLIC_KEY_FILES="$(SSH_PUBLIC_KEY_FILES)" \
	SSH_PUBLIC_KEY_GLOB="$(SSH_PUBLIC_KEY_GLOB)" \
		AUTHORIZED_KEY_HOST_FILE="$(AUTHORIZED_KEY_HOST_FILE)" \
		AUTHORIZED_KEY_ISO_PATH="$(AUTHORIZED_KEY_ISO_PATH)" \
		QUIET="$(QUIET)" \
		/bin/sh "$(BUILD_AUTO_ISO_SCRIPT)"
	@echo "created $(AUTO_ISO)"

_verify-iso: _verify-iso-extract _verify-iso-preseed _verify-iso-grub _verify-iso-hooks _verify-iso-ssh
	@echo "ISO verification passed: unattended boot + injected installer hook scripts present."

_verify-iso-extract: $(AUTO_ISO) $(VERIFY_AUTO_ISO_SCRIPT)
	@echo "==> verifying iso assets"
	@AUTO_ISO="$(AUTO_ISO)" \
	ISO_WORKDIR="$(ISO_WORKDIR)" \
	AUTHORIZED_KEY_ISO_PATH="$(AUTHORIZED_KEY_ISO_PATH)" \
	PARTMAN_EARLY_ISO_PATH="$(PARTMAN_EARLY_ISO_PATH)" \
	PRESEED_LATE_ISO_PATH="$(PRESEED_LATE_ISO_PATH)" \
	INSTALLER_COMMON_ISO_PATH="$(INSTALLER_COMMON_ISO_PATH)" \
	VERIFY_PRESEED_HOST_FILE="$(VERIFY_PRESEED_HOST_FILE)" \
	VERIFY_GRUB_HOST_FILE="$(VERIFY_GRUB_HOST_FILE)" \
	VERIFY_AUTHORIZED_KEY_HOST_FILE="$(VERIFY_AUTHORIZED_KEY_HOST_FILE)" \
	VERIFY_PARTMAN_EARLY_HOST_FILE="$(VERIFY_PARTMAN_EARLY_HOST_FILE)" \
		VERIFY_PRESEED_LATE_HOST_FILE="$(VERIFY_PRESEED_LATE_HOST_FILE)" \
		VERIFY_INSTALLER_COMMON_HOST_FILE="$(VERIFY_INSTALLER_COMMON_HOST_FILE)" \
		QUIET="$(QUIET)" \
		/bin/sh "$(VERIFY_AUTO_ISO_SCRIPT)" extract

_verify-iso-preseed: _verify-iso-extract $(VERIFY_AUTO_ISO_SCRIPT)
	@AUTO_ISO="$(AUTO_ISO)" \
	VERIFY_PRESEED_HOST_FILE="$(VERIFY_PRESEED_HOST_FILE)" \
	/bin/sh "$(VERIFY_AUTO_ISO_SCRIPT)" check-preseed

_verify-iso-grub: _verify-iso-extract $(VERIFY_AUTO_ISO_SCRIPT)
	@AUTO_ISO="$(AUTO_ISO)" \
	VERIFY_GRUB_HOST_FILE="$(VERIFY_GRUB_HOST_FILE)" \
	/bin/sh "$(VERIFY_AUTO_ISO_SCRIPT)" check-grub

_verify-iso-hooks: _verify-iso-extract $(VERIFY_AUTO_ISO_SCRIPT)
	@AUTO_ISO="$(AUTO_ISO)" \
	VERIFY_PARTMAN_EARLY_HOST_FILE="$(VERIFY_PARTMAN_EARLY_HOST_FILE)" \
	VERIFY_PRESEED_LATE_HOST_FILE="$(VERIFY_PRESEED_LATE_HOST_FILE)" \
	VERIFY_INSTALLER_COMMON_HOST_FILE="$(VERIFY_INSTALLER_COMMON_HOST_FILE)" \
	/bin/sh "$(VERIFY_AUTO_ISO_SCRIPT)" check-hooks

_verify-iso-ssh: _verify-iso-extract $(VERIFY_AUTO_ISO_SCRIPT)
	@AUTO_ISO="$(AUTO_ISO)" \
	VERIFY_AUTHORIZED_KEY_HOST_FILE="$(VERIFY_AUTHORIZED_KEY_HOST_FILE)" \
	/bin/sh "$(VERIFY_AUTO_ISO_SCRIPT)" check-ssh

_efi-vars:
	@test -f "$(EFI_VARS)" || cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

_reset-efi-vars:
	@cp "$(EFI_VARS_TEMPLATE)" "$(EFI_VARS)"

_install: build _check _reset-efi-vars
	@echo "installing os from $(CDROM)"
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		-cdrom "$(CDROM)" \
		-no-reboot \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)

install: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
install: AUTO_ISO=$(AUTO_ISO_INSTALL)
install: CDROM=$(AUTO_ISO)
install: GRUB_KERNEL_ARGS=$(GRUB_KERNEL_ARGS_INSTALL)
install: _precheck _install
	@echo "install finished."

start: INPUT_ARGS=$(INTERACTIVE_INPUT_ARGS)
start: _check _efi-vars
	@echo booting installed os from $(DISK) with EFI
	@$(QEMU) \
		$(QEMU_COMMON_ARGS) \
		$(DISPLAY_ARGS) \
		$(MONITOR_ARGS) \
		$(INPUT_ARGS) \
		$(NETWORK_ARGS)
