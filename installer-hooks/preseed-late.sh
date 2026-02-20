#!/bin/sh
set -eu

in-target sh -euxc '
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

if [ -s /cdrom/authorized_key.pub ]; then
  cp /cdrom/authorized_key.pub /target/home/installer/.ssh/authorized_keys
  in-target chmod 600 /home/installer/.ssh/authorized_keys
  in-target chown installer:installer /home/installer/.ssh/authorized_keys
else
  echo "WARNING: /cdrom/authorized_key.pub missing or empty; skipping SSH key install"
fi

mkdir -p /target/etc/sudoers.d
printf '%s\n' 'installer ALL=(ALL:ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/90-installer-nopasswd
chmod 440 /target/etc/sudoers.d/90-installer-nopasswd
in-target chown root:root /etc/sudoers.d/90-installer-nopasswd
in-target visudo -cf /etc/sudoers.d/90-installer-nopasswd

mkdir -p /target/etc/ssh/sshd_config.d
printf '%s\n' \
  'PermitRootLogin no' \
  'PasswordAuthentication no' \
  'KbdInteractiveAuthentication no' \
  'ChallengeResponseAuthentication no' \
  'PubkeyAuthentication yes' \
  > /target/etc/ssh/sshd_config.d/90-installer-keyonly.conf
chmod 644 /target/etc/ssh/sshd_config.d/90-installer-keyonly.conf
in-target chown root:root /etc/ssh/sshd_config.d/90-installer-keyonly.conf
in-target sshd -t || true
