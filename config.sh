# Debian Chroot config
DEB_ROOT=/data/local/debian   # where the Debian root filesystem lives
DEB_TERM=xterm-256color       # TERM inside the chroot
DEB_LANG=C.UTF-8              # locale inside the chroot (C.UTF-8 ships with Debian)
DEB_TZ=auto                   # auto = phone's time zone (persist.sys.timezone); or e.g. "UTC"
BIND_SDCARD=1                 # 1 = mount internal storage at /sdcard inside the chroot
# deb-bootstrap only:
DEB_RELEASE=trixie            # Debian release to download
DEB_DNS=1.1.1.1               # nameserver written to /etc/resolv.conf
DEB_PACKAGES="curl ca-certificates git ripgrep procps nano less tzdata locales"
INSTALL_CLAUDE=1              # 1 = install Claude Code with its native installer
