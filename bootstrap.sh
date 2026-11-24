#!/system/bin/sh
# Download a Debian root filesystem and prepare it for use on Android. Run as root (deb-bootstrap).
MODDIR=${0%/*}
. "$MODDIR/config.sh"; . "$MODDIR/lib.sh"
D=${1:-$DEB_ROOT}
say() { echo "- $*"; }
die() { echo "! $*"; [ -n "$MOUNTED" ] && umount_all "$D"; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root (su -c deb-bootstrap)"
[ -e "$D/bin" ] && die "$D already contains a root filesystem; remove it or pass another directory"
BB=""
for b in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox; do
  [ -x "$b" ] && { BB=$b; break; }
done
[ -n "$BB" ] || die "no root manager busybox found (needed for xz and tar)"
case "$(uname -m)" in
  aarch64) ARCH=arm64 ;; x86_64) ARCH=amd64 ;; armv7*|armv8l) ARCH=armhf ;;
  *) die "unsupported CPU: $(uname -m)" ;;
esac

# 1. Root filesystem: the LXC project's official Debian image (built with distrobuilder)
BASE=https://images.linuxcontainers.org/images/debian/$DEB_RELEASE/$ARCH/default
say "Looking up the newest Debian $DEB_RELEASE $ARCH image"
BUILD=$(curl -fsSL "$BASE/" | grep -oE '[0-9]{8}_[0-9]{2}:[0-9]{2}' | sort -u | tail -1)
[ -n "$BUILD" ] || die "could not list $BASE"
TAR=$D.rootfs.tar.xz
say "Downloading build $BUILD (about 90 MB)"
curl -fL --progress-bar -o "$TAR" "$BASE/$BUILD/rootfs.tar.xz" || die "download failed"
SUM=$(curl -fsSL "$BASE/$BUILD/SHA256SUMS" | awk '$2=="rootfs.tar.xz"{print $1}')
[ -n "$SUM" ] && [ "$(sha256sum "$TAR" | cut -d' ' -f1)" = "$SUM" ] || { rm -f "$TAR"; die "checksum mismatch"; }
say "Checksum OK, unpacking to $D"
mkdir -p "$D"
"$BB" xz -dc "$TAR" | "$BB" tar -x -C "$D" || die "unpack failed"
rm -f "$TAR"

# 2. Android-specific fixes
say "Writing resolv.conf ($DEB_DNS), hosts and apt settings"
# No systemd-resolved or Android resolver inside the chroot: use a fixed nameserver.
rm -f "$D/etc/resolv.conf"; echo "nameserver $DEB_DNS" > "$D/etc/resolv.conf"
printf '127.0.0.1 localhost\n::1 localhost\n' > "$D/etc/hosts"
# Android only lets members of the inet group (AID 3003) open network sockets. apt normally
# drops to the _apt user for downloads, which isn't in that group, so keep it as root.
echo 'APT::Sandbox::User "root";' > "$D/etc/apt/apt.conf.d/01android"
# "android <cmd>" runs a command in Android's own root filesystem, from inside the chroot.
cat > "$D/usr/local/bin/android" <<'EOT'
#!/bin/sh
exec nsenter -t 1 -m -r -w -- /system/bin/sh -c "export PATH=/system/bin:/system/xbin:/vendor/bin; $*"
EOT
chmod 755 "$D/usr/local/bin/android"
grep -q '.local/bin' "$D/root/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$D/root/.bashrc"

# 3. Packages and Claude Code
mount_all "$D"; MOUNTED=1
run() { chroot "$D" /usr/bin/env -i HOME=/root TERM=dumb LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive \
  PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /bin/bash -lc "$1"; }
say "Installing packages: $DEB_PACKAGES"
run "apt-get update -q && apt-get install -y -q $DEB_PACKAGES" || die "apt failed"
if [ "$INSTALL_CLAUDE" = 1 ]; then
  say "Installing Claude Code (native installer)"
  run "curl -fsSL https://claude.ai/install.sh | bash" || die "Claude Code install failed"
fi
umount_all "$D"
say "Done. Open a shell with: deb   (or start Claude Code with: claude)"
