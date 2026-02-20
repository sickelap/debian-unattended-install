#!/bin/sh

# Shared paths used by installer hooks.
AUTHORIZED_KEY_SOURCE_PATH=/cdrom/authorized_key.pub
AUTHORIZED_KEYS_TARGET_PATH=/target/home/installer/.ssh/authorized_keys
SUDOERS_DROPIN_PATH=/etc/sudoers.d/90-installer-nopasswd
SSHD_DROPIN_PATH=/etc/ssh/sshd_config.d/90-installer-keyonly.conf

info() {
  printf '%s\n' "INFO: $*" >&2
}

warn() {
  printf '%s\n' "WARNING: $*" >&2
}

die() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

require_env() {
  var_name=$1
  eval "value=\${$var_name-}"
  if [ -z "$value" ]; then
    die "missing required env var: $var_name"
  fi
}

# Initialize an installer-side log file and print the chosen path.
init_installer_log() {
  log_name="$1"
  mkdir -p /var/log/installer 2>/dev/null || true
  log_file="/var/log/installer/$log_name"
  : > "$log_file" 2>/dev/null || log_file="/tmp/$log_name"
  : > "$log_file" 2>/dev/null || true
  printf '%s\n' "$log_file"
}

log_line() {
  log_file="$1"
  shift
  printf '%s\n' "$*" >> "$log_file" 2>/dev/null || true
}

run_in_target() {
  in-target sh -euxc "$1"
}

copy_authorized_key_if_present() {
  source_path="$1"
  target_path="$2"
  if [ -s "$source_path" ]; then
    cp "$source_path" "$target_path"
    return 0
  fi

  warn "$source_path missing or empty; skipping SSH key install"
  return 1
}
