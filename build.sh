#!/bin/sh
# Package the module zip: ./build.sh  ->  debian-chroot-<version>.zip
set -e
cd "$(dirname "$0")"
VER=$(sed -n 's/^version=//p' module.prop)
OUT="debian-chroot-$VER.zip"
rm -f "$OUT"
zip -r -X "$OUT" module.prop config.sh lib.sh deb.sh bootstrap.sh customize.sh action.sh uninstall.sh system META-INF >/dev/null
echo "$OUT"
