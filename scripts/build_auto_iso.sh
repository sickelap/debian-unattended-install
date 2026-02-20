#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/common.sh"

require_env ISO
require_env AUTO_ISO
require_env PRESEED
require_env PARTMAN_EARLY_SCRIPT
require_env PARTMAN_EARLY_ISO_PATH
require_env PRESEED_LATE_SCRIPT
require_env PRESEED_LATE_ISO_PATH
require_env INSTALLER_COMMON_SCRIPT
require_env INSTALLER_COMMON_ISO_PATH
require_env ISO_WORKDIR
require_env GRUB_INSTALL_DIR
require_env GRUB_KERNEL_ARGS
require_env AUTHORIZED_KEY_HOST_FILE
require_env AUTHORIZED_KEY_ISO_PATH
require_env SSH_PUBLIC_KEY_GLOB

rm -rf "$ISO_WORKDIR"
mkdir -p "$ISO_WORKDIR"

if [ -n "${SSH_PUBLIC_KEY-}" ]; then
  printf '%s\n' "$SSH_PUBLIC_KEY" > "$AUTHORIZED_KEY_HOST_FILE"
elif [ -n "${SSH_PUBLIC_KEY_FILES-}" ]; then
  : > "$AUTHORIZED_KEY_HOST_FILE"
  for key_file in $SSH_PUBLIC_KEY_FILES; do
    cat "$key_file" >> "$AUTHORIZED_KEY_HOST_FILE"
  done
else
  : > "$AUTHORIZED_KEY_HOST_FILE"
  echo "WARNING: no SSH public keys found (checked SSH_PUBLIC_KEY and $SSH_PUBLIC_KEY_GLOB); proceeding without key-based SSH access."
fi

cat > "$ISO_WORKDIR/grub.cfg.auto" <<EOF
set default=0
set timeout_style=hidden
set timeout=0

menuentry 'Unattended install (Btrfs snapshots)' {
    linux /$GRUB_INSTALL_DIR/vmlinuz $GRUB_KERNEL_ARGS ---
    initrd /$GRUB_INSTALL_DIR/initrd.gz
}

EOF

rm -f "$AUTO_ISO"
xorriso -indev "$ISO" -outdev "$AUTO_ISO" \
  -boot_image any replay \
  -map "$PRESEED" /preseed.cfg \
  -map "$PARTMAN_EARLY_SCRIPT" "$PARTMAN_EARLY_ISO_PATH" \
  -map "$PRESEED_LATE_SCRIPT" "$PRESEED_LATE_ISO_PATH" \
  -map "$INSTALLER_COMMON_SCRIPT" "$INSTALLER_COMMON_ISO_PATH" \
  -map "$AUTHORIZED_KEY_HOST_FILE" "$AUTHORIZED_KEY_ISO_PATH" \
  -map "$ISO_WORKDIR/grub.cfg.auto" /boot/grub/grub.cfg >/dev/null
