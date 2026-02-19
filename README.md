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
- `Makefile`: build and run workflow (`iso`, `install`, `start`, etc.)
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

## Run arm64 Instead

```bash
make build ARCH=arm64 ISO=debian-13.3.0-arm64-netinst.iso
make start ARCH=arm64
```

## Common Targets
- `make iso`: create unattended installer ISO (`debian-auto-<arch>.iso`)
- `make verify-iso`: verify preseed + GRUB unattended boot entry were embedded
- `make image`: create/recreate VM disk image (`os-<arch>.qcow2`)
- `make install`: unattended install in GUI window
- `make install-interactive`: same as install, plus USB keyboard/tablet devices
- `make install-headless`: unattended install over serial console (`-serial mon:stdio`)
- `make start`: boot installed OS from disk
- `make reset-efi-vars`: reset UEFI NVRAM vars file (`efi-vars-<arch>.fd`)

## Important Variables
Override at runtime as needed:

```bash
make build ARCH=amd64 ISO=debian-13.3.0-amd64-netinst.iso DISK=myvm.qcow2 DISK_SIZE=40G
```

Main variables:
- `ARCH` (`amd64` or `arm64`)
- `ISO` (default depends on `ARCH`)
- `AUTO_ISO` (default `debian-auto-$(ARCH).iso`)
- `DISK` (default `os-$(ARCH).qcow2`)
- `EFI_VARS` (default `efi-vars-$(ARCH).fd`)
- `DISK_SIZE` (default `20G`)
- `RAM_MB` (default `2048`)
- `CPUS` (default `4`)
- `ACCEL` (`kvm`/`tcg` on Linux, `hvf` for macOS `arm64`, `tcg` otherwise)

## What the Unattended Install Does
From `preseed.cfg`:
- creates user `user` with password `debian`
- installs `openssh-server`, `btrfs-progs`, `snapper`
- creates a Btrfs root Snapper config (`root`)
- enables `snapper-timeline.timer` and `snapper-cleanup.timer`
- creates an initial snapshot (`Initial-install`)

## Notes
- `make image` removes and recreates the disk image file.
- `make install` resets EFI vars each run (`reset-efi-vars`) for deterministic installer boot behavior.
- Default networking is QEMU user networking (`virtio-net`).
