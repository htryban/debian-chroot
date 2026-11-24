# Debian Chroot

A small Magisk / KernelSU / KernelSU-Next module that gives a rooted Android phone a full Debian userland and lets you run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in it from any terminal app. Type `deb` for a Debian shell, or `claude` to start Claude Code straight away.

## Why

Claude Code needs a normal Linux userland: glibc, bash, git, curl and a package manager. Android has none of that, and Termux-style environments differ enough to cause trouble. A Debian chroot on the phone gives you the real thing, while still running on the phone itself with root, so Claude can inspect and change the device it is running on.

Getting there takes a handful of Android-specific fixes (networking for apt, DNS, mount namespaces, a clean environment, PATH, time zone). This module and its bootstrap script do them for you, and the [setup notes](#running-claude-code-cleanly) explain each one.

## What it does

- **`deb [command...]`**: mounts the chroot if needed (`/proc`, `/sys`, `/dev`, `/dev/pts` and internal storage at `/sdcard`) and opens a Debian login shell. With a command, it runs it first and leaves you in the shell when it exits. Arguments are passed through with their quoting intact.
- **`claude [args...]`**: shorthand for `deb claude ...`.
- **`deb-bootstrap [dir]`**: sets up a new Debian root filesystem (see [Setup](#setup)).
- **`android "<cmd>"`** (inside the chroot, written by `deb-bootstrap`): runs a command in Android's own root filesystem, for example `android "cmd package list packages"`.
- **Action button**: shows where the root filesystem is, which Debian release it is, what is mounted, the installed Claude Code version and the chroot's time zone.

All three commands ask for root through `su` when run from a normal terminal, so grant your terminal app root in your root manager.

## Requirements

- Root via Magisk, KernelSU or KernelSU-Next (the root manager's busybox is used to unpack the image)
- A terminal app, for example ReTerminal or Termux, with root granted
- About 2 GB free in `/data` for Debian, packages and Claude Code
- An arm64 phone (x86_64 and armhf images are picked automatically but untested)

## Setup

1. Install the zip from [Releases](../../releases) in your root manager and reboot.
2. In your terminal app, run:

   ```sh
   su -c deb-bootstrap
   ```

   This:
   - downloads the newest official Debian image (`trixie` by default) for your CPU from the [LXC image server](https://images.linuxcontainers.org) and checks its SHA-256
   - unpacks it to `/data/local/debian`
   - applies the Android fixes listed under [Running Claude Code cleanly](#running-claude-code-cleanly)
   - installs `DEB_PACKAGES` and Claude Code

   It stops if the target directory already has a root filesystem.
3. Run `claude` and sign in. Next time, `claude` takes you straight back in.

Already have a Debian root filesystem? Point `DEB_ROOT` at it and skip step 2. Apply the fixes below by hand if it doesn't have them yet.

## Running Claude Code cleanly

These steps are what make Claude Code behave inside the chroot. `deb-bootstrap` and the `deb` launcher handle the first seven; the last three are up to you.

1. **Use init's mount namespace.** The launchers run everything through `nsenter -t 1 -m`. Root shells from `su` often get a private mount namespace, so mounts made there are invisible to other sessions and vanish when the shell exits. Mounting from init's namespace means every session shares one set of chroot mounts, and the in-chroot `android` helper can reach the real Android filesystem.
2. **Start from a clean environment.** The chroot is entered with `env -i` and only `HOME`, `TERM`, `LANG`, `TZ` and `PATH` set. Android's own variables (`BOOTCLASSPATH`, `ANDROID_*`, `LD_*` and so on) mean nothing to Debian programs and can break them.
3. **Fix DNS.** There is no resolver service inside the chroot, so `/etc/resolv.conf` is replaced with a fixed nameserver (`DEB_DNS`, default `1.1.1.1`) and `/etc/hosts` gets `localhost`.
4. **Let apt download as root.** Android only allows members of the `inet` group (AID 3003) to open network sockets. apt normally drops to its `_apt` user for downloads, which isn't in that group, so downloads fail. `APT::Sandbox::User "root";` in `/etc/apt/apt.conf.d/01android` keeps them as root.
5. **Install Claude Code with the native installer and put it on PATH.** `curl -fsSL https://claude.ai/install.sh | bash` installs to `~/.local/bin`, which is added to `PATH` in the launcher and in `~/.bashrc`. No Node.js needed.
6. **Set time zone and locale.** `TZ` follows the phone's time zone (`persist.sys.timezone`), so `date`, logs and Claude's timestamps match the phone instead of UTC. `LANG=C.UTF-8` keeps Claude Code's interface drawing correctly.
7. **Add the `android` helper.** `/usr/local/bin/android` uses `nsenter -t 1 -m -r -w` to run a command in Android's root filesystem, so Claude can call `pm`, `dumpsys`, `logcat`, `settings` and so on from inside Debian.
8. **Start in a project directory with a `CLAUDE.md`.** Make a folder for the work (for example `~/phone`) and put `cd ~/phone` at the end of `/root/.bashrc` so `claude` always starts there. Add a `CLAUDE.md` that tells Claude where it is and what to be careful with, for example:

   ```markdown
   You are running as root in a Debian chroot on the Android phone you are modifying.
   Run Android commands via `android "<cmd>"` (e.g. android cmd package list packages).
   Reboots, network changes, or stopping the terminal app end this session; warn first and save notes to ~/phone/NOTES.md.
   Never touch partitions, /dev/block, or boot images without explicit approval.
   ```

   Keeping a `NOTES.md` there gives the next session the history of what was changed.
9. **Keep the terminal alive.** Claude runs inside the terminal app, so anything that kills the app ends the session: rebooting, force-stopping it, or Android reclaiming it in the background. Turning off battery optimization for the terminal app helps.
10. **Optional: follow along from another device.** Set `"remoteControlAtStartup": true` in `/root/.claude/settings.json` to start Remote Control with every session.

## Configuration

`/data/adb/modules/debian-chroot/config.sh`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `DEB_ROOT` | `/data/local/debian` | Location of the Debian root filesystem |
| `DEB_TERM` | `xterm-256color` | `TERM` inside the chroot |
| `DEB_LANG` | `C.UTF-8` | Locale inside the chroot |
| `DEB_TZ` | `auto` | `auto` follows the phone's time zone; or a zone such as `UTC` |
| `BIND_SDCARD` | `1` | Mount internal storage at `/sdcard` inside the chroot |
| `DEB_RELEASE` | `trixie` | Debian release `deb-bootstrap` downloads |
| `DEB_DNS` | `1.1.1.1` | Nameserver `deb-bootstrap` writes to `/etc/resolv.conf` |
| `DEB_PACKAGES` | `curl ca-certificates git ripgrep procps nano less tzdata locales` | Packages `deb-bootstrap` installs |
| `INSTALL_CLAUDE` | `1` | Install Claude Code during `deb-bootstrap` |

Changes apply the next time you run `deb` or `claude`.

## Limitations

- **This is a chroot, not a container.** Everything runs as root with full access to the phone. That is the point, but it means Claude can break things, so keep the `CLAUDE.md` guard rails.
- **No init system.** systemd and services don't run, so start anything long-running by hand.
- **Unmount before deleting the root filesystem.** While mounted, the chroot's `/sdcard` and `/dev` are your real storage and devices, and `rm -rf` would delete through them. Reboot first, or check that `grep /data/local/debian /proc/mounts` prints nothing.
- **Mounts stay until reboot** once `deb` has run. Uninstalling the module unmounts them but leaves the root filesystem in place.

## Install

Download the zip from [Releases](../../releases) and install it from your root manager, then reboot once so `deb`, `claude` and `deb-bootstrap` appear.

Replacing the earlier `debshell` module: install this zip over it. The installer marks `debshell` for removal on the next reboot. Note that `debshell` used `/data/local/deb.sh`; this module carries its own launcher, so that file is no longer used.

## Build

```sh
./build.sh
```

## License

MIT
