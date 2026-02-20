#!/bin/sh
set -eux

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/common.sh"

setup_base_target_state() {
  # ---- Base Target Setup ----
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
}

install_ssh_key() {
  # ---- Authorized Keys ----
  copy_authorized_key_if_present \
    "$AUTHORIZED_KEY_SOURCE_PATH" \
    "$AUTHORIZED_KEYS_TARGET_PATH" || warn "continuing without SSH authorized_keys"
}

write_sudoers() {
  # ---- Sudoers Drop-in ----
  run_in_target '
    exec >> /root/preseed-late.log 2>&1
    install -d -m 0755 /etc/sudoers.d
    cat > /etc/sudoers.d/90-installer-nopasswd <<EOF
installer ALL=(ALL:ALL) NOPASSWD:ALL
EOF
    chmod 440 /etc/sudoers.d/90-installer-nopasswd
    chown root:root /etc/sudoers.d/90-installer-nopasswd
    visudo -cf /etc/sudoers.d/90-installer-nopasswd
  '
}

write_sshd_dropin() {
  # ---- SSH Daemon Drop-in ----
  run_in_target '
    exec >> /root/preseed-late.log 2>&1
    install -d -m 0755 /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/90-installer-keyonly.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF
    chmod 644 /etc/ssh/sshd_config.d/90-installer-keyonly.conf
    chown root:root /etc/ssh/sshd_config.d/90-installer-keyonly.conf
  '
}

final_checks() {
  # ---- Final Validation ----
  run_in_target '
    exec >> /root/preseed-late.log 2>&1
    if [ -f /home/installer/.ssh/authorized_keys ]; then
      chmod 600 /home/installer/.ssh/authorized_keys
      chown installer:installer /home/installer/.ssh/authorized_keys
    fi

    sshd -t || true
  '
}

# ---- Execution Order ----
setup_base_target_state
install_ssh_key
write_sudoers
write_sshd_dropin
final_checks
