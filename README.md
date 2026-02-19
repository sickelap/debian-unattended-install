# Debian Unattended Install (QEMU + UEFI + Btrfs Snapshots)

This project builds an unattended Debian installer ISO and installs Debian in QEMU with UEFI boot.

It is tuned for `arm64` netinst media and sets up:
- GPT partitioning with an EFI system partition
- Btrfs root filesystem
- Snapper configuration with timeline/cleanup timers

## Files
- `Makefile`: build and run workflow (`iso`, `install`, `start`, etc.)
- `preseed.cfg`: Debian preseed answers + `late_command` for Snapper setup

## Prerequisites
Install these tools:
- `qemu-system-aarch64`
- `qemu-img`
- `xorriso`
- `ripgrep` (`rg`)

You also need AArch64 UEFI firmware files (EDK2). The `Makefile` auto-detects common paths on macOS/Homebrew and Linux. If detection fails, set:
- `EFI_CODE=/path/to/edk2-aarch64-code.fd`
- `EFI_VARS_TEMPLATE=/path/to/edk2-aarch64-vars.fd`

## Quick Start
1. Put a Debian ARM64 netinst ISO in the repo root (default expected name is `debian-13.3.0-arm64-netinst.iso`).
2. Build disk image and run unattended install (headless):

```bash
make build
```

3. Boot the installed VM with GUI input devices:

```bash
make start
```

## Common Targets
- `make iso`: create unattended installer ISO (`debian-auto.iso`)
- `make verify-iso`: verify preseed + GRUB unattended boot entry were embedded
- `make image`: create/recreate VM disk image (`os.qcow2`)
- `make install`: unattended install in GUI window
- `make install-interactive`: same as install, plus USB keyboard/tablet devices
- `make install-headless`: unattended install over serial console (`-serial mon:stdio`)
- `make start`: boot installed OS from disk
- `make reset-efi-vars`: reset UEFI NVRAM vars file

## Important Variables
Override at runtime as needed:

```bash
make build ISO=debian-13.3.0-arm64-netinst.iso DISK=myvm.qcow2 DISK_SIZE=40G
```

Main variables:
- `ISO` (default `debian-13.3.0-arm64-netinst.iso`)
- `AUTO_ISO` (default `debian-auto.iso`)
- `DISK` (default `os.qcow2`)
- `DISK_SIZE` (default `20G`)
- `RAM_MB` (default `2048`)
- `CPUS` (default `4`)
- `ACCEL` (`hvf` on macOS, `kvm`/`tcg` on Linux depending on host)

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
