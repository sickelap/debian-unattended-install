# Debian Unattended Install

Build and run an unattended Debian installer in QEMU with UEFI, Btrfs root, and Snapper.

## Supported Guest Architectures
- `amd64` (default on Linux hosts)
- `arm64` (default on macOS hosts)

## Required Dependencies
Executables required by public target:

| Target | Required executables | Conditional executables |
| --- | --- | --- |
| `make clean` | none | none |
| `make full-clean` | none | none |
| `make build` | `qemu-img`, `xorriso`, `rg` | `curl` or `wget` (only when ISO is missing locally) |
| `make install` | `qemu-system-x86_64` or `qemu-system-aarch64`, `qemu-img`, `xorriso`, `rg` | `curl` or `wget` (only when ISO is missing locally) |
| `make start` | `qemu-system-x86_64` or `qemu-system-aarch64` | none |
| `make test` | `qemu-system-x86_64` or `qemu-system-aarch64`, `qemu-img`, `xorriso`, `rg` | Linux only: `timeout` |

Required firmware files:
- `amd64`: OVMF (`OVMF_CODE.fd`, `OVMF_VARS.fd`)
- `arm64`: AAVMF/EDK2 (`edk2-aarch64-code.fd`, `edk2-aarch64-vars.fd`)

Install suggestions (recommended superset for all targets):

```bash
# macOS (Homebrew)
brew install qemu xorriso ripgrep curl wget
```

```bash
# Debian/Ubuntu (example)
sudo apt update
sudo apt install -y qemu-system-x86 qemu-system-arm qemu-utils ovmf qemu-efi-aarch64 xorriso ripgrep curl wget
```

```bash
# Fedora (example)
sudo dnf install -y qemu-system-x86 qemu-system-aarch64 qemu-img edk2-ovmf edk2-aarch64 xorriso ripgrep curl wget
```

```bash
# Arch Linux (example)
sudo pacman -S --needed qemu-base edk2-ovmf xorriso ripgrep curl wget
```

Package names can vary by distro/release.

The Makefile auto-detects common firmware paths. If detection fails, set:
- `EFI_CODE=/path/to/firmware-code.fd`
- `EFI_VARS_TEMPLATE=/path/to/firmware-vars.fd`

## Cheatsheet
Common command sets by host/guest architecture.

### Linux host -> amd64 guest (default)
```bash
make build
make install
make start
```

### Linux host -> arm64 guest
```bash
make build ARCH=arm64 ISO=debian-13.3.0-arm64-netinst.iso
make install ARCH=arm64 ISO=debian-13.3.0-arm64-netinst.iso
make start ARCH=arm64
```

### macOS host -> arm64 guest (default)
```bash
make build
make install
make start
```

### macOS host -> amd64 guest
```bash
make build ARCH=amd64 ISO=debian-13.3.0-amd64-netinst.iso
make install ARCH=amd64 ISO=debian-13.3.0-amd64-netinst.iso
make start ARCH=amd64
```

### Test unattended install (any host)
```bash
make test
make test ARCH=amd64
make test ARCH=arm64 ISO=debian-13.3.0-arm64-netinst.iso
```

## Common Targets
- `make clean`: remove generated artifacts
- `make full-clean`: remove build artifacts and downloaded installer ISOs
- `make build`: create disk image and unattended installer ISO assets
- `make install`: run unattended installer in a QEMU window (exits on first reboot)
- `make test`: CI/local verification that unattended install completes and records log in `.build/test`
- `make start`: boot installed OS from disk

Prerequisite checks run automatically for `build`, `install`, `test`, and `start`.

## Defaults
### Build/Runtime Defaults
- `ARCH`: `amd64` on Linux, `arm64` on macOS
- `DEBIAN_VERSION`: `13.3.0`
- `ISO`: `debian-$(DEBIAN_VERSION)-$(ARCH)-netinst.iso`
- `AUTO_ISO_INSTALL`: `debian-auto-install-$(ARCH).iso`
- `AUTO_ISO_TEST`: `debian-auto-test-$(ARCH).iso`
- `DISK`: `os-$(ARCH).qcow2`
- `DISK_SIZE`: `20G`
- `RAM_MB`: `2048`
- `CPUS`: `4`
- `EFI_VARS`: `efi-vars-$(ARCH).fd`
- `TEST_TIMEOUT`: `45m` (Linux only)

### Guest Access Defaults
- installer user: `installer`
- console password: `installer`
- SSH password auth: disabled (`PasswordAuthentication no`)
- SSH root login: disabled (`PermitRootLogin no`)
- sudo: passwordless for `installer` (`NOPASSWD:ALL`)
- default key discovery on host: `~/.ssh/id_*.pub`
- guest authorized keys path: `/home/installer/.ssh/authorized_keys`

## Advanced Overrides
Use overrides at runtime:

```bash
make build ARCH=amd64 ISO=debian-13.3.0-amd64-netinst.iso DISK=myvm.qcow2 DISK_SIZE=40G RAM_MB=4096 CPUS=8
```

### ISO Source
- `DEBIAN_VERSION`
- `ISO`
- `ISO_FILENAME`
- `ISO_MIRROR`
- `ISO_URL`

### VM and QEMU
- `ARCH`
- `QEMU`
- `ACCEL`
- `CPU_MODEL`
- `DISK`
- `DISK_SIZE`
- `RAM_MB`
- `CPUS`
- `DISPLAY_ARGS`
- `VIDEO_ARGS`
- `NETWORK_ARGS`
- `MONITOR_ARGS`
- `INPUT_ARGS`

### Firmware
- `EFI_CODE`
- `EFI_VARS_TEMPLATE`
- `EFI_VARS`

### Boot/Installer
- `PRESEED`
- `INSTALLER_HOOKS_DIR`
- `PARTMAN_EARLY_SCRIPT`
- `PRESEED_LATE_SCRIPT`
- `PARTMAN_EARLY_ISO_PATH`
- `PRESEED_LATE_ISO_PATH`
- `AUTO_ISO`
- `AUTO_ISO_INSTALL`
- `AUTO_ISO_TEST`
- `GRUB_KERNEL_ARGS_COMMON`
- `GRUB_KERNEL_ARGS_INSTALL`
- `GRUB_KERNEL_ARGS_TEST`
- `GRUB_KERNEL_ARGS`

### SSH Key Injection
- `SSH_PUBLIC_KEY_GLOB`
- `SSH_PUBLIC_KEY_FILES`
- `SSH_PUBLIC_KEY_FILE` (legacy alias)
- `SSH_PUBLIC_KEY` (inline override; highest priority)

### Test Controls
- `TEST_TIMEOUT`
- `TEST_LOG`
- `TEST_TAIL_LINES`
- `TEST_SUCCESS_REGEX`
- `TIMEOUT`

## Installer Hooks
- Partitioning and post-install customization are executed from injected ISO scripts:
  - `/installer-hooks/partman-early.sh`
  - `/installer-hooks/preseed-late.sh`
  - `/installer-hooks/common.sh` (shared helper functions sourced by hook scripts)
- These scripts are sourced from repo files under `scripts/` and mapped into the unattended ISO during `make build`.
- Hook scripts are executed explicitly via `/bin/sh`, so execute permissions are not required.

### Developer Map
| Repo source | ISO path | Used by | Execution phase |
| --- | --- | --- | --- |
| `preseed.cfg` | `/preseed.cfg` | Debian installer | Installer boot/preseed |
| `scripts/partman-early.sh` | `/installer-hooks/partman-early.sh` | `partman/early_command` | Pre-partitioning |
| `scripts/preseed-late.sh` | `/installer-hooks/preseed-late.sh` | `preseed/late_command` | Post-install (late command) |
| `scripts/common.sh` | `/installer-hooks/common.sh` | sourced by hook scripts | Helper functions only |

## Notes
- Partitioning is destructive on the selected target disk.
- `make install` and `make test` reset EFI vars each run for deterministic installer boot.
- `make test` uses serial/headless mode and follows the install log.
- If installer ISO is missing, `build`/`install`/`test` will download it automatically.
