# Qt upgrades and recovery

The presentation plugin uses Qt's QPA native interface. It must be rebuilt
against the exact installed Qt version. The package records that version in
`/usr/lib/qt6/qml/Nocturne/Presentation/qt-version`.

Before opening Cage, `nocturne-greeter-start` checks the version and loads the
exact plugin directory in a short-lived, offscreen Quickshell process. The
normal check exits nonzero on failure; `--hook` reports the same warning but
returns success because the pacman transaction has already completed.

If preflight fails, the launcher runs **agreety on the VT**, using greetd/PAM.
After authentication, the recovery helper offers numbered Wayland sessions
from the root-owned catalog. It passes argv directly to `systemd-cat`, sets
the Wayland desktop environment variables, and starts the chosen session.
It does not accept commands, read passwords, or bypass the graphical launch
gate. This fallback covers failed preflight; a compositor or GPU failure
after preflight still requires the independent TTY recovery procedure.

## Existing installations

The package preserves `/etc/nocturne-greeter/greetd.toml`. If pacman creates a
`.pacnew`, merge it so `[default_session]` uses:

```toml
command = "/usr/lib/nocturne-greeter/nocturne-greeter-start"
user = "greeter"
```

Preserve your VT and any required graphics settings. For example, a machine
requiring an explicit DRM device can use an `env WLR_DRM_DEVICES=...` prefix
before the launcher. Prefer a stable device path under `/dev/dri/by-path`.
Do not start or restart greetd from an active desktop while testing this.

## Upgrade/rebuild

1. Keep the previous package file and the documented TTY recovery commands.
2. After updating Qt or Quickshell, rebuild with `makepkg -sif`.
3. Run `/usr/lib/nocturne-greeter/nocturne-greeter-check` and check its exit
   status. Successful offscreen loading does not prove DRM or frame delivery.
4. From a disposable VM or a maintenance TTY, verify login/logout, then reboot.
5. If needed, restore a matching Qt/plugin package set or rebuild against the
   current Qt. Restoring only an old plugin on a new Qt is not a valid rollback.

## Repeatable fault test (no host service changes)

```sh
./scripts/build-presentation-probe.sh
./scripts/test-upgrade-recovery.sh
```

This tests exact-version mismatch, an unloadable `.so`, restoration of the
known-good plugin, and both launcher branches with stub processes. Seven
Python recovery tests cover catalog ownership, malformed data, numeric
selection, session environment, and launcher routing. It never runs PAM.

## VM acceptance procedure

The metadata mismatch, agreety/PAM recovery, restoration and reboot cycle
passed on 2026-10-29; see [COMPATIBILITY.md](COMPATIBILITY.md). Repeat for
future Qt changes. A full matching Qt package upgrade/downgrade remains open.

Use a disposable snapshot and keep the guest agent or a second guest TTY
open. Install the new package, merge its config, verify graphical login and
logout, then make a **guest-only backup** of `qt-version`. Replace its content
with `0.0.0`, restart guest greetd, and verify visible agreety login plus a
Wayland session. Restore the metadata, check the module, restart greetd and
verify the graphical login returns. Reboot and repeat login/logout. Finally
restore the previous matching package set or snapshot and verify rollback.
Record package versions, outcomes and the snapshot identifier in
[COMPATIBILITY.md](COMPATIBILITY.md). Do not perform fault injection on the
workstation's installed module.
