#!/bin/sh
#
# Config for this setup script. What is done or needed is completly
# in your hand. Most is self explaining, ...
#
#  USER_PUBKEY is your public ssh key line, or "" for password auth.
#  HOST_MOTD   Message of the day (/etc/motd). Quite useless.
#
#  readonly USER_PUBKEY="ssh-rsa <long-hex-string-from-your>"
#
readonly USER_NAME="user"
readonly USER_PASS="theuserpasswordofyourchoice"
readonly USER_GROUPS="sudo,wheel,staff,dialout"
readonly USER_PUBKEY=""
readonly HOST_NAME="thenameofthepi0"
readonly HOST_MOTD=""
readonly SOURCE=$(dirname $(realpath $0))

#
# Add the user with the config above.
#
register_main_user() {
  [ -z "$USER_NAME" ] && return 0
  cd "$SOURCE" || return 1
  adduser -D -h /home/$USER_NAME $USER_NAME
  [ -d ./home/$USER_NAME ] && cp -rf ./home/$USER_NAME/* /home/$USER_NAME/ && rm -rf "./home/$USER_NAME"
  mkdir -p /home/$USER_NAME/.ssh
  touch /home/$USER_NAME/.ssh/authorized_keys
  chown -R $USER_NAME:$USER_NAME /home/$USER_NAME
  chmod 700 /home/$USER_NAME/.ssh
  chmod 600 /home/$USER_NAME/.ssh/authorized_keys
  [ ! -z "$USER_PASS" ] && echo -e "$USER_PASS\n$USER_PASS\n" | passwd -a sha256 $USER_NAME >/dev/null 2>&1
  [ ! -z "$USER_GROUPS" ] && echo "$USER_GROUPS" | sed -e 's/[,; ]\+/\n/g' | xargs -r -n1 -P1 -I'{}' addgroup "$USER_NAME" "{}"
  [ ! -z "$USER_PUBKEY" ] && echo "$USER_PUBKEY" > /home/$USER_NAME/.ssh/authorized_keys
  return 0
}

#
# Copy and sanitize most basic data in /etc.
#
copy_etc_config() {
  [ -d "$SOURCE/etc" ] || return 0
  cd "$SOURCE" && [ "$(pwd)" != "/etc" ] || return 1
  chown -R root:root $SOURCE/etc
  chmod 755 ./etc/init.d/* >/dev/null 2>&1
  chmod 600 ./etc/wpa_supplicant.conf >/dev/null 2>&1
  cp -avrf ./etc/* /etc/
  rm -rf "$SOURCE/etc"
  chmod 600 /etc/shadow /etc/shadow-
  chmod 644 /etc/sudo.conf
  chmod 640 /etc/sudoers
  chmod 600 /etc/ssh/*_key
  chmod 644 /etc/ssh/*.pub /etc/ssh/*_config
  [ ! -z "$HOST_NAME" ] && echo "$HOST_NAME" >/etc/hostname
  [ ! -z "$HOST_MOTD" ] && echo "$HOST_MOTD" >/etc/motd
  return 0
}

#
# Copy other data you have in your setup directory/archive.
# Exclude /tmp and /var/log, which may be linked to /tmp.
#
copy_other() {
  local ec=0
  cd "$SOURCE" || return 1
  rm -rf "./tmp" >/dev/null 2>&1
  rm -rf "./var/log" >/dev/null 2>&1
  chown -R root:root ./* >/dev/null 2>&1
  cp -avr ./* / || ec=1
  rm -rf ./*
  return $ec
}

#
# Invoke your setup functions.
#
register_main_user
copy_etc_config
copy_other
return 0
