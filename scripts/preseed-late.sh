#!/bin/sh
set -eux

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/common.sh"

# Run base post-install setup inside the target system.
run_in_target '
  exec > /root/preseed-late.log 2>&1
  command -v snapper
  command -v btrfs
  command -v systemctl
  test "$(findmnt -n -o FSTYPE /)" = "btrfs"
  snapper --no-dbus -c root create-config /
  systemctl enable snapper-timeline.timer
  systemctl enable snapper-cleanup.timer
  usermod -aG sudo installer
  mkdir -p /home/installer/.ssh
  chmod 700 /home/installer/.ssh
  chown installer:installer /home/installer/.ssh
  snapper --no-dbus -c root create --description Initial-install
  snapper --no-dbus list-configs | grep -Eq "^root[[:space:]]"
'

copy_authorized_key_if_present /cdrom/authorized_key.pub /target/home/installer/.ssh/authorized_keys || true

# Create configuration files and apply ownership, modes, and validations in the target system.
run_in_target '
  exec >> /root/preseed-late.log 2>&1
  install -d -m 0755 /etc/sudoers.d /etc/ssh/sshd_config.d

  cat > /etc/sudoers.d/90-installer-nopasswd <<EOF
installer ALL=(ALL:ALL) NOPASSWD:ALL
EOF
  chmod 440 /etc/sudoers.d/90-installer-nopasswd
  chown root:root /etc/sudoers.d/90-installer-nopasswd
  visudo -cf /etc/sudoers.d/90-installer-nopasswd

  cat > /etc/ssh/sshd_config.d/90-installer-keyonly.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF
  chmod 644 /etc/ssh/sshd_config.d/90-installer-keyonly.conf
  chown root:root /etc/ssh/sshd_config.d/90-installer-keyonly.conf

  if [ -f /home/installer/.ssh/authorized_keys ]; then
    chmod 600 /home/installer/.ssh/authorized_keys
    chown installer:installer /home/installer/.ssh/authorized_keys
  fi

  sshd -t || true
'
