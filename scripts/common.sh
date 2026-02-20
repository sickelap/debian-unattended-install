#!/bin/sh

require_env() {
  var_name=$1
  eval "value=\${$var_name-}"
  if [ -z "$value" ]; then
    echo "missing required env var: $var_name" >&2
    exit 1
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

warn() {
  printf '%s\n' "WARNING: $*" >&2
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
