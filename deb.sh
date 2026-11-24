#!/system/bin/sh
# deb.sh ["<command string>"]: mount the chroot if needed and enter it.
# With a command, run it in a login shell and stay in bash afterwards.
# Runs as root in the global mount namespace (the deb/claude wrappers take care of that).
MODDIR=${0%/*}
. "$MODDIR/config.sh"; . "$MODDIR/lib.sh"
D=$DEB_ROOT
if [ ! -x "$D/bin/bash" ]; then
  echo "No Debian root filesystem at $D."
  echo "Set one up with: su -c deb-bootstrap"
  exit 1
fi
mount_all "$D"
if [ -n "$1" ]; then CMD="$1; exec bash -l"; else CMD="exec bash -l"; fi
# env -i: start from a clean environment. Android's variables (BOOTCLASSPATH, ANDROID_*,
# LD_* and friends) mean nothing to Debian binaries and can break them.
exec chroot "$D" /usr/bin/env -i HOME=/root TERM="$DEB_TERM" LANG="$DEB_LANG" TZ="$(chroot_tz)" \
  PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -lic "$CMD"
