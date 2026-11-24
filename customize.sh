SKIPUNZIP=0
OLD=/data/adb/modules/debian-chroot/config.sh
LEGACY=/data/adb/modules/debshell   # earlier module that only had the deb/claude wrappers

if [ -f "$OLD" ]; then
  ui_print "- Keeping existing config.sh"
  NEW="$MODPATH/config.sh.new"
  mv -f "$MODPATH/config.sh" "$NEW"
  cp -f "$OLD" "$MODPATH/config.sh"
  # Add settings introduced since that config was written
  for key in $(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$NEW"); do
    grep -q "^$key=" "$MODPATH/config.sh" && continue
    ui_print "  Adding new setting $key"
    { echo; awk -v k="$key" '/^#/{c=c $0 "\n"; next} index($0, k "=")==1{printf "%s%s\n", c, $0} {c=""}' "$NEW"; } >> "$MODPATH/config.sh"
  done
  rm -f "$NEW"
fi

if [ -d "$LEGACY" ] || [ -d /data/adb/modules_update/debshell ]; then
  ui_print "- Replacing old module debshell (removed on reboot)"
  [ -d "$LEGACY" ] && touch "$LEGACY/remove"
  rm -rf /data/adb/modules_update/debshell
fi

. "$MODPATH/config.sh"
if [ -x "$DEB_ROOT/bin/bash" ]; then
  ui_print "- Debian root filesystem found at $DEB_ROOT"
else
  ui_print "! No Debian root filesystem at $DEB_ROOT yet."
  ui_print "! After rebooting, run in a terminal: su -c deb-bootstrap"
fi

for f in deb.sh bootstrap.sh action.sh system/bin/deb system/bin/claude system/bin/deb-bootstrap; do
  set_perm "$MODPATH/$f" 0 0 0755
done
