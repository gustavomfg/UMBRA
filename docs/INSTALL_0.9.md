# Nocturne Greeter 0.9 — Users, sessions, package and host install

**Status:** ready for use on Arch Linux. Items 1–4 were implemented and
proven in the disposable VM (2026-10-17). As of 2026-10-18, the owner confirms
use on the real workstation; package `0.9.0-2` is installed and
`greetd.service` is active. The installation and recovery runbook remains
below for reference.

## What changed since 0.8

| Area | 0.9 |
| --- | --- |
| Users | `/etc/passwd` within `UID_MIN..UID_MAX` from `/etc/login.defs`, login shells only, GECOS display name. User menu in the chrome while idle. |
| Sessions | `nocturne-greeter-sessions` (root) parses `/usr/share/wayland-sessions/*.desktop` without a shell, drops field codes, rejects unquoted shell syntax, resolves `Exec`/`TryExec` to root-owned, non-writable executables and writes `/var/lib/nocturne-greeter/sessions.json`. The greeter only reads that catalog. A pacman hook refreshes it. |
| Launch | `Greetd.launch(argv, env)` uses the selected catalog entry; env is `XDG_SESSION_TYPE=wayland`, `XDG_SESSION_DESKTOP=<id>`, `XDG_CURRENT_DESKTOP=<DesktopNames>`. Still gated on the presented black frame. |
| Session output | The launch argv is prefixed with `/usr/bin/systemd-cat --identifier=nocturne-session --`, so launcher output (uwsm's unit summary, `start-hyprland`) goes to `journalctl -t nocturne-session` instead of flashing on VT1 before the compositor takes over. |
| Memory | Last user and session in `/var/lib/nocturne-greeter/state/last-selection.json` (owned by `greeter`, 0700 directory), saved before launch. |
| Power | Sleep, Restart, Shut down run `systemctl suspend/reboot/poweroff`; logind allows the active greeter session without extra polkit rules. |
| UX | Space only wakes (other printable keys still start typing). PAM's generic `Password:` is shown as "Enter your password". Multi-part PAM notices are joined (faillock shows reason and remaining time). Administrative notices when there are no users, no sessions or no presentation module. |
| Package | `packaging/arch/PKGBUILD`: install tree, presentation module built against the installed Qt, session generator, pacman hooks, tmpfiles, `/etc/nocturne-greeter/greetd.toml`, and a `greetd.service` drop-in. greetd is not enabled by the package. |

## Session catalog on this workstation

`./system/nocturne-greeter-sessions --check` on the host (2026-10-17):

| id | Name | argv |
| --- | --- | --- |
| `hyprland` | Hyprland | `/usr/bin/start-hyprland` |
| `hyprland-uwsm` | Hyprland (uwsm-managed) | `/usr/bin/uwsm start -e -D Hyprland hyprland.desktop` |
| `plasma` | Plasma (Wayland) | `/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland` |

## VM proof (items 1–4)

Package built with `makepkg` as an unprivileged guest user and installed by
`vm/install-package-in-guest.sh` (guard `--check` first). Guest packages as in
0.8 plus hyprland 0.56.2-4, uwsm 0.27.1-1, aquamarine 0.15.1-1.

| Case | Result |
| --- | --- |
| Package install | pacman hooks created the tmpfiles dirs and the catalog (3 sessions in the guest); drop-in selected `/etc/nocturne-greeter/greetd.toml` |
| User menu | 3 human users listed with GECOS names; hidden while awake |
| Session menu | catalog sessions listed; choice persisted across greeter restarts and reboots |
| Session env | inside the session: `wayland foot-test FootTest nocturne-test` |
| Hyprland | launched from Umbra (software rendering in the VM), Super+M returned to Umbra |
| Hyprland via uwsm | `wayland-wm@hyprland.desktop.service` and `graphical-session.target` active; exit returned to Umbra |
| Restart | `systemctl reboot` from the greeter session; next boot reached Umbra |
| Sleep | guest suspended (QMP `suspended`), resumed with the greeter alive |
| Shut down | clean power-off in ≈ 2 s. After a prior S3 cycle the guest kernel panicked in the final ACPI step after systemd finished; a QEMU/SeaBIOS guest quirk, not a greeter path |
| faillock | after 3 failures: "The account is locked due to 3 failed logins. (N minutes left to unlock)" |
| Regression | launch markers in order; canary absent from logs |

Host checks: QML 64/64, model and menus included; greetd adapter 17/17;
session generator 12/12; launch-gate end to end with and without the module;
guard 11/11; nine protocol fixture scenarios; qmllint.

## Known limits

- The owner now uses the greeter on the real workstation. This confirms
  use on that system; other GPU, multi-monitor and keyboard configurations
  still require their own validation.
- X11 sessions are not offered (`/usr/share/xsessions` is ignored).
- In the VM the shader costs ≈ 1.7 cores (llvmpipe); not measured on the GPU.
- After a Quickshell crash, launch is delayed ≈ 5 s (crash helper).
- The presentation module is compiled against the installed Qt. The
  `nocturne-greeter-check` hook warns after Qt/Quickshell upgrades if it no
  longer loads; rebuild the package then (`makepkg -sif`). Until rebuilt, the
  greeter shows a notice and refuses to start sessions; log in on a TTY.

## Item 5 runbook — install on this workstation

Do this when you can afford a few minutes without the desktop. Save your work
first: stopping the current display manager ends the graphical session.

### 0. Make sure you can get back

1. Press **Ctrl+Alt+F3**, log in with your user and password, run `sudo -v`,
   then return with **Ctrl+Alt+F1** (or F2). If the TTY login fails, stop
   here.
2. Write down the recovery commands (they are also in step 6).

### 1. Build and install the package (greetd stays disabled)

```sh
cd ~/Documentos/nocturne-greeter/packaging/arch
makepkg -sif         # builds, installs greetd/cage if missing, then nocturne-greeter
/usr/lib/nocturne-greeter/nocturne-greeter-check
cat /var/lib/nocturne-greeter/sessions.json
systemctl is-enabled greetd   # expect: disabled
```

### 2. One manual trial (no boot change)

From **Ctrl+Alt+F3** (logged in):

```sh
sudo systemctl stop plasmalogin    # ends the current desktop session
sudo systemctl start greetd        # Umbra appears on VT1
```

On Umbra: choose your user and session (Hyprland or Hyprland (uwsm-managed)),
type your password, Enter. Check the monitor, keyboard layout, mouse and that
the session starts. Log out and confirm Umbra returns.

### 3. If the screen stays black or Cage fails

On **Ctrl+Alt+F3**:

```sh
journalctl -b -t nocturne-greeter | tail -50
journalctl -b -u greetd | tail -20
journalctl -b -t nocturne-session | tail -20   # session launcher output
```

Your monitor is on the NVIDIA card. If wlroots picked the iGPU, pin it in
`/etc/nocturne-greeter/greetd.toml` (kept on upgrades) by adding
`WLR_DRM_DEVICES=/dev/dri/card1` after `env`:

```toml
command = "systemd-cat --identifier=nocturne-greeter -- env WLR_DRM_DEVICES=/dev/dri/card1 XDG_CACHE_HOME=/var/cache/nocturne-greeter cage -s -- /usr/bin/quickshell --no-duplicate --path /usr/share/nocturne-greeter"
```

Check the card first (`for c in /sys/class/drm/card*-*; do echo $c $(cat $c/status); done`);
card numbers can change between boots. Then `sudo systemctl restart greetd`.

### 4. Go back to the old login for now

```sh
sudo systemctl stop greetd
sudo systemctl start plasmalogin
```

### 5. Make it permanent

```sh
sudo systemctl disable plasmalogin
sudo systemctl enable greetd
reboot
```

### 6. Roll back at any time

From Ctrl+Alt+F3:

```sh
sudo systemctl disable greetd
sudo systemctl enable plasmalogin
sudo reboot
# optional: sudo pacman -R nocturne-greeter
```

Three wrong passwords lock the account for 10 minutes (distribution
`pam_faillock`); `sudo faillock --user <you> --reset` from a TTY clears it.
