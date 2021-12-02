#!/bin/sh

if [ ! -d "$TARGET_DIR" ]; then
  echo "TARGET_DIR not a directory."
  exit 1
elif [ "$(whoami)" != "root" ]; then
  echo "Not fakeroot environment."
  exit 1
fi

#
# Overlay permissions
#
chmod 644 $TARGET_DIR/etc/network/interfaces
chmod 644 $TARGET_DIR/etc/iptables/*
chmod 754 $TARGET_DIR/etc/init.d/*
chmod 700 $TARGET_DIR/root/.local
chmod 700 $TARGET_DIR/root/.local/bin
chmod 700 $TARGET_DIR/root/.local/bin/setup-done

#
# Experiment: Build time user creation without user-table.
#
echo 'admin:x:1001:10:Admin,,,:/home/admin:/bin/sh' >>$TARGET_DIR/etc/passwd
echo 'admin:x:1001:' >>$TARGET_DIR/etc/group
echo 'admin:$1$BrC9QjJd$vMXUGMxslaWmVDuI3eOsJ.:1:0:99999:7:::' >>$TARGET_DIR/etc/shadow
mkdir -p $TARGET_DIR/home/admin
cp $TARGET_DIR/etc/skel/* $TARGET_DIR/home/admin/
chown -R 1001:1001 $TARGET_DIR/home/admin
