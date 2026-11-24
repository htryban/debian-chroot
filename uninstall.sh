#!/system/bin/sh
# The Debian root filesystem is left in place. Unmount it so nothing stays bind-mounted.
MODDIR=${0%/*}
nsenter -t 1 -m -- sh -c ". $MODDIR/config.sh; . $MODDIR/lib.sh; umount_all \$DEB_ROOT"
