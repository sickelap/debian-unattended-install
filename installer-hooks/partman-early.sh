#!/bin/sh
set -eu

mkdir -p /var/log/installer 2>/dev/null || true
log=/var/log/installer/auto-disk-select.log
: > "$log" 2>/dev/null || log=/tmp/auto-disk-select.log
: > "$log" 2>/dev/null || true

log_msg() {
  printf '%s\n' "$1" >> "$log" 2>/dev/null || true
}

log_msg "auto disk selection started"
candidates=""
for d in $(list-devices disk); do
  base="${d##*/}"
  rem_file="/sys/block/$base/removable"
  if [ -r "$rem_file" ] && [ "$(cat "$rem_file")" != 0 ]; then
    log_msg "skip removable $d"
    continue
  fi

  if readlink -f "/sys/block/$base" 2>/dev/null | grep -qi "/usb"; then
    log_msg "skip usb-attached $d"
    continue
  fi

  size_file="/sys/block/$base/size"
  size=0
  if [ -r "$size_file" ]; then
    size="$(cat "$size_file" 2>/dev/null || echo 0)"
  fi
  log_msg "candidate $d size=$size"
  candidates="$candidates $d:$size"
done

target=""
max_size=-1
for entry in $candidates; do
  dev="${entry%%:*}"
  size="${entry##*:}"
  if [ "$size" -gt "$max_size" ] 2>/dev/null; then
    target="$dev"
    max_size="$size"
  fi
done

if [ -z "$target" ]; then
  target="$(list-devices disk | head -n1)"
  log_msg "WARNING: no non-removable non-USB candidate; fallback to $target"
fi

log_msg "selected target=$target size=$max_size"
debconf-set partman-auto/disk "$target"
debconf-set grub-installer/bootdev "$target"
