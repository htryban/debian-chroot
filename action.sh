#!/system/bin/sh
# Action button: show the chroot's status.
MODDIR=${0%/*}
. "$MODDIR/config.sh"; . "$MODDIR/lib.sh"
D=$DEB_ROOT
if [ ! -x "$D/bin/bash" ]; then
  echo "- No root filesystem at $D"
  echo "  Set one up from a terminal: su -c deb-bootstrap"
  exit 0
fi
echo "- Root filesystem: $D ($(du -shx "$D" 2>/dev/null | cut -f1 || echo '?'))"
echo "- Release: $(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' "$D/etc/os-release")"
for m in proc sys dev dev/pts sdcard; do
  nsenter -t 1 -m -- grep -q " $D/$m " /proc/mounts && s=mounted || s="not mounted"
  echo "  /$m: $s"
done
C=$(ls "$D/root/.local/share/claude/versions" 2>/dev/null | sort -V | tail -1)
echo "- Claude Code: ${C:-not installed}"
echo "- Time zone in chroot: $(chroot_tz)"
