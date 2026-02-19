TIMEOUT ?= timeout
TEST_TIMEOUT ?= 45m
TEST_LOG_DIR ?= .build/test
TEST_LOG ?= $(TEST_LOG_DIR)/install-$(ARCH).log
TEST_DISK ?= $(TEST_LOG_DIR)/os-$(ARCH).qcow2
TEST_EFI_VARS ?= $(TEST_LOG_DIR)/efi-vars-$(ARCH).fd
TEST_TAIL_LINES ?= 80
TEST_SUCCESS_REGEX ?= reboot: (Restarting system|Power down|System halted)

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
