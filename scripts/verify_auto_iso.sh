#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/common.sh"

assert_file_contains() {
  file_path=$1
  pattern=$2
  rg -q "$pattern" "$file_path"
}

# ---- Asset Extraction ----
extract_assets() {
  require_env AUTO_ISO
  require_env ISO_WORKDIR
  require_env AUTHORIZED_KEY_ISO_PATH
  require_env PARTMAN_EARLY_ISO_PATH
  require_env PRESEED_LATE_ISO_PATH
  require_env INSTALLER_COMMON_ISO_PATH
  require_env VERIFY_PRESEED_HOST_FILE
  require_env VERIFY_GRUB_HOST_FILE
  require_env VERIFY_AUTHORIZED_KEY_HOST_FILE
  require_env VERIFY_PARTMAN_EARLY_HOST_FILE
  require_env VERIFY_PRESEED_LATE_HOST_FILE
  require_env VERIFY_INSTALLER_COMMON_HOST_FILE

  mkdir -p "$ISO_WORKDIR"
  rm -f \
    "$VERIFY_PRESEED_HOST_FILE" \
    "$VERIFY_GRUB_HOST_FILE" \
    "$VERIFY_AUTHORIZED_KEY_HOST_FILE" \
    "$VERIFY_PARTMAN_EARLY_HOST_FILE" \
    "$VERIFY_PRESEED_LATE_HOST_FILE" \
    "$VERIFY_INSTALLER_COMMON_HOST_FILE"

  xorriso -osirrox on -indev "$AUTO_ISO" -extract /preseed.cfg "$VERIFY_PRESEED_HOST_FILE" >/dev/null 2>&1
  xorriso -osirrox on -indev "$AUTO_ISO" -extract /boot/grub/grub.cfg "$VERIFY_GRUB_HOST_FILE" >/dev/null 2>&1
  xorriso -osirrox on -indev "$AUTO_ISO" -extract "$AUTHORIZED_KEY_ISO_PATH" "$VERIFY_AUTHORIZED_KEY_HOST_FILE" >/dev/null 2>&1
  xorriso -osirrox on -indev "$AUTO_ISO" -extract "$PARTMAN_EARLY_ISO_PATH" "$VERIFY_PARTMAN_EARLY_HOST_FILE" >/dev/null 2>&1
  xorriso -osirrox on -indev "$AUTO_ISO" -extract "$PRESEED_LATE_ISO_PATH" "$VERIFY_PRESEED_LATE_HOST_FILE" >/dev/null 2>&1
  xorriso -osirrox on -indev "$AUTO_ISO" -extract "$INSTALLER_COMMON_ISO_PATH" "$VERIFY_INSTALLER_COMMON_HOST_FILE" >/dev/null 2>&1
}

# ---- Content Verification ----
verify_preseed() {
  require_env VERIFY_PRESEED_HOST_FILE
  assert_file_contains "$VERIFY_PRESEED_HOST_FILE" "partman/early_command string"
  assert_file_contains "$VERIFY_PRESEED_HOST_FILE" "/cdrom/installer-hooks/partman-early.sh"
  assert_file_contains "$VERIFY_PRESEED_HOST_FILE" "preseed/late_command string"
  assert_file_contains "$VERIFY_PRESEED_HOST_FILE" "/cdrom/installer-hooks/preseed-late.sh"
}

verify_grub() {
  require_env VERIFY_GRUB_HOST_FILE
  assert_file_contains "$VERIFY_GRUB_HOST_FILE" '^set timeout_style=hidden$'
  assert_file_contains "$VERIFY_GRUB_HOST_FILE" '^set timeout=0$'
  test "$(rg -c "^menuentry " "$VERIFY_GRUB_HOST_FILE")" -eq 1
  assert_file_contains "$VERIFY_GRUB_HOST_FILE" "preseed/file=/cdrom/preseed.cfg"
}

verify_hooks() {
  require_env VERIFY_PARTMAN_EARLY_HOST_FILE
  require_env VERIFY_PRESEED_LATE_HOST_FILE
  require_env VERIFY_INSTALLER_COMMON_HOST_FILE
  assert_file_contains "$VERIFY_PARTMAN_EARLY_HOST_FILE" "debconf-set partman-auto/disk"
  assert_file_contains "$VERIFY_PARTMAN_EARLY_HOST_FILE" "debconf-set grub-installer/bootdev"
  assert_file_contains "$VERIFY_PRESEED_LATE_HOST_FILE" "snapper --no-dbus -c root create-config /"
  assert_file_contains "$VERIFY_PRESEED_LATE_HOST_FILE" "list-configs \\| grep -Eq"
  assert_file_contains "$VERIFY_INSTALLER_COMMON_HOST_FILE" "run_in_target"
  assert_file_contains "$VERIFY_INSTALLER_COMMON_HOST_FILE" "copy_authorized_key_if_present"
  test -s "$VERIFY_PARTMAN_EARLY_HOST_FILE"
  test -s "$VERIFY_PRESEED_LATE_HOST_FILE"
  test -s "$VERIFY_INSTALLER_COMMON_HOST_FILE"
}

verify_ssh() {
  require_env VERIFY_AUTHORIZED_KEY_HOST_FILE
  test -f "$VERIFY_AUTHORIZED_KEY_HOST_FILE"
}

action=${1-}
case "$action" in
  extract)
    extract_assets
    ;;
  check-preseed)
    verify_preseed
    ;;
  check-grub)
    verify_grub
    ;;
  check-hooks)
    verify_hooks
    ;;
  check-ssh)
    verify_ssh
    ;;
  *)
    echo "usage: $0 <extract|check-preseed|check-grub|check-hooks|check-ssh>" >&2
    exit 2
    ;;
esac
