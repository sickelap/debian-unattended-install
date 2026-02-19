# Debian Unattended Install (QEMU + UEFI + Btrfs Snapshots)

This project builds an unattended Debian installer ISO and installs Debian in QEMU with UEFI boot.

Supported guest architectures:
- `amd64` (default on Linux)
- `arm64` (default on macOS, or use `ARCH=arm64`)

The unattended install config sets up:
- GPT partitioning with an EFI system partition
- Btrfs root filesystem
- Snapper configuration with timeline/cleanup timers

## Files
- `Makefile`: entrypoint that includes modular build logic from `mk/*.mk`
- `mk/common.mk`, `mk/arch.mk`, `mk/os.mk`, `mk/test.mk`, `mk/targets.mk`: split configuration and targets by concern
- `preseed.cfg`: Debian preseed answers + `late_command` for Snapper setup

## Prerequisites
Install these tools:
- QEMU (`qemu-system-x86_64` for `amd64`, `qemu-system-aarch64` for `arm64`)
- `qemu-img`
- `xorriso`
- `ripgrep` (`rg`)

You also need UEFI firmware files:
- `amd64`: OVMF (`OVMF_CODE.fd`, `OVMF_VARS.fd`)
- `arm64`: AAVMF/EDK2 (`edk2-aarch64-code.fd`, `edk2-aarch64-vars.fd`)

The `Makefile` auto-detects common firmware paths on macOS/Homebrew and Linux. If detection fails, set:
- `EFI_CODE=/path/to/...`
- `EFI_VARS_TEMPLATE=/path/to/...`

## Quick Start (Linux amd64)
1. Put Debian netinst ISO in repo root: `debian-13.3.0-amd64-netinst.iso`.
2. Build disk image and run unattended install (headless):

```bash
make build
```

3. Boot the installed VM:

```bash
make start
```

If the ISO is missing locally, `make build`/`make install`/`make test` will download it automatically.

## Run arm64 Instead

```bash
make build ARCH=arm64 ISO=debian-13.3.0-arm64-netinst.iso
make start ARCH=arm64
```

## Common Targets
- `make clean`: remove generated artifacts
- `make full-clean`: remove build artifacts and downloaded installer ISOs
- `make build`: create disk image and run unattended installer headless (exits on first reboot)
- `make install`: run unattended installer headless (exits on first reboot)
- `make test`: CI/local verification that unattended install completes; validates serial output marker and stores log in `.build/test`
- `make start`: boot installed OS from disk

The unattended ISO build target is internal (`_iso`) and is invoked automatically by `build`/`install`/`test`.

## Important Variables
Override at runtime as needed:

```bash
make build ARCH=amd64 ISO=debian-13.3.0-amd64-netinst.iso DISK=myvm.qcow2 DISK_SIZE=40G
```

Main variables:
- `ARCH` (`amd64` or `arm64`)
- `ISO` (default depends on `ARCH`)
- `ISO_MIRROR` (default `https://www.mirrorservice.org/sites/cdimage.debian.org/debian-cd/current`)
- `ISO_URL` (full download URL, auto-computed from mirror/arch/version)
- `AUTO_ISO` (default `debian-auto-$(ARCH).iso`)
- `DISK` (default `os-$(ARCH).qcow2`)
- `EFI_VARS` (default `efi-vars-$(ARCH).fd`)
- `DISK_SIZE` (default `20G`)
- `RAM_MB` (default `2048`)
- `CPUS` (default `4`)
- `ACCEL` (`kvm`/`tcg` on Linux, `hvf` for macOS `arm64`, `tcg` otherwise)
- `TEST_TIMEOUT` (default `45m`, used only on Linux in `make test`)
- `TEST_LOG` (default `.build/test/install-$(ARCH).log`)
- `TEST_TAIL_LINES` (default `80`, number of log lines shown initially when following test log)
- `TEST_SUCCESS_REGEX` (default reboot completion pattern checked by `make test`)
- `SSH_PUBLIC_KEY_FILE` (default: first existing key from `~/.ssh/id_ed25519.pub`, `id_ecdsa.pub`, `id_rsa.pub`)
- `SSH_PUBLIC_KEY` (optional inline override for the public key to inject)

## What the Unattended Install Does
From `preseed.cfg`:
- creates user `user` with password `debian`
- installs `openssh-server`, `btrfs-progs`, `snapper`
- creates a Btrfs root Snapper config (`root`)
- enables `snapper-timeline.timer` and `snapper-cleanup.timer`
- creates an initial snapshot (`Initial-install`)

## Notes
- `make build` recreates the disk image file each run.
- `make install`/`make test` reset EFI vars each run for deterministic installer boot behavior.
- `make test` shows a live `tail -f` style view while writing the full installer log to `TEST_LOG`.
- `make test` uses Linux `timeout` in CI; on macOS it runs without timeout to support local MacBook verification.
- The unattended ISO embeds `/authorized_key.pub` and `preseed.cfg` installs it as `/home/user/.ssh/authorized_keys` if non-empty.
- Default networking is QEMU user networking (`virtio-net`).
