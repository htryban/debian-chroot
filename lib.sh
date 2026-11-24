# Shared helpers for deb.sh and bootstrap.sh. Expects config.sh to be sourced first.
mounted() { grep -q " $1 " /proc/mounts; }
mount_all() {
  D=$1
  mkdir -p "$D/proc" "$D/sys" "$D/dev" "$D/dev/pts"
  mounted "$D/proc"    || mount -t proc proc "$D/proc"
  mounted "$D/sys"     || mount -t sysfs sysfs "$D/sys"
  mounted "$D/dev"     || mount -o bind /dev "$D/dev"
  mounted "$D/dev/pts" || mount -o bind /dev/pts "$D/dev/pts"
  if [ "$BIND_SDCARD" = 1 ]; then
    mkdir -p "$D/sdcard"
    mounted "$D/sdcard" || mount -o bind /storage/emulated/0 "$D/sdcard"
  fi
}
umount_all() {
  D=$1
  for m in sdcard dev/pts dev sys proc; do
    mounted "$D/$m" && umount -l "$D/$m"
  done
  return 0
}
chroot_tz() {
  if [ "$DEB_TZ" = auto ]; then getprop persist.sys.timezone; else echo "$DEB_TZ"; fi
}
