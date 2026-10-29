# Compatibility and acceptance matrix

Target: **Arch Linux x86_64, greetd, Cage and Wayland sessions**. A passing
mock, virtual output or VM test does not certify a physical GPU, monitor or
keyboard. Other distributions and X11 sessions are outside this release.

## Validation on 2026-10-29

| Case | Evidence | Result |
| --- | --- | --- |
| QML states, focus, typed PAM challenges, launch gate | Offscreen Qt 6.12.0 | 70 passed |
| Menu keyboard navigation | Arrows, Home/End, Enter/Space, Escape/Tab; normal and 150% Qt scale | 20 model/menu tests passed at each scale |
| Catalog, recovery, VM guard and canary scanner | Python unittest; includes positive leak/error cases for scanner | 35 passed |
| Quickshell greetd adapter | Fake API launch policy checks | 17 passed |
| Real Quickshell protocol client | Nine scenarios in headless Cage, local IPC fixture | Passed; no PAM or real session launch |
| Presentation barrier | Headless Cage, exact freshly built module | Exactly one launch after `black-commit-presented` |
| Missing module | Forced absent import even if a system module is installed | Zero launch requests |
| Two outputs | Cage headless, two virtual 1280×720 outputs | Auth capture passed; selected `HEADLESS-2`, outputs=2 |
| Screen preference and disconnect/reconnect | Selector tests: preferred connector, origin, name fallback, empty outputs | Passed; physical hotplug pending |
| Visual layout | Qt captures: 1280×720 logical at 150%, 3440×1440 at 100% | Inspected; no clipping in auth composition |
| Package upgrade | Disposable QEMU/KVM guest; package built as ordinary user, installed with guarded helper | Passed |
| Real graphical login/logout | Guest greetd/PAM → Foot test Wayland session → greeter | Passed, black-frame markers in order |
| Qt mismatch and text fallback | Guest-only metadata changed to `0.0.0` | agreety appeared, PAM login passed, numbered session choice launched Foot |
| Recovery rollback and boot | Restored matching metadata, restarted greetd, rebooted guest | Graphical login and logout passed after reboot |
| Secret canary | Corrected scanner, current guest boot journal plus existing state/log roots | 0 matching journal lines, 0 matching text files |
| Freshly rebuilt module damage/restore | Temporary `.so` corrupted and restored | Strict preflight refused damage, accepted restoration |

Guest: Arch kernel 7.2.10-arch1-1, Qt 6.12.0-3, Quickshell 0.3.2-1,
greetd/agreety 0.10.3-2, software rendering on the QEMU display. The guest
used `--snapshot`: writes went to a temporary overlay, preserving the
original qcow2 disk. The upgrade first exercised the new runtime under the
previous package version, before the release metadata bump. Final package
validation is recorded in the release notes.

The VM suite does **not** simulate a full pacman Qt upgrade/downgrade. It
injects the same detected version mismatch and tests recovery, then restores
the matching module. A full matching-package rollback is still a release
acceptance task.

## Physical hardware cases still open

| Case | Acceptance criterion | Status |
| --- | --- | --- |
| Intel, AMD and NVIDIA pre-login rendering | Boot, shader, keyboard, login/logout, VT recovery | Owner's existing workstation use documented in 0.9; broader matrix pending |
| Multiple physical monitors / hotplug | Chosen connector has UI and focus; unplug/replug recovers; launch gate follows actual window | Pending |
| HiDPI / mixed physical scales | Readable text, correct targets and focus; no clipped menus | Virtual scale checked; physical validation pending |
| US / BR ABNT2 keyboards | Matching pre-login layout, accented characters and symbols, login with a disposable account | US guest input checked; physical ABNT2 pending |
| Laptop suspend/resume and power policy | Recovery after suspend and clear outcome under inhibitors | Historical VM results in 0.9; physical matrix pending |

## Monitor and keyboard configuration

The greeter uses **one output**. Set `NOCTURNE_OUTPUT` to a connector name
advertised by the greeter's compositor. If absent or disconnected, it picks
an output at (0,0), then the first connector in name order. Cage can expose
different connector names than the desktop compositor. The journal records
`nocturne-display: <connector> outputs=<count> scale=<ratio>` without serials.

For example, edit the preserved greetd config during a maintenance window:

```toml
command = "env NOCTURNE_OUTPUT=DP-1 XKB_DEFAULT_LAYOUT=br /usr/lib/nocturne-greeter/nocturne-greeter-start"
```

`XKB_DEFAULT_LAYOUT`, `XKB_DEFAULT_VARIANT` and `XKB_DEFAULT_OPTIONS` configure
Cage's graphical keyboard. They do **not** configure the Linux console used
by agreety; configure the console keymap separately through the distribution.
Qt supplies logical coordinates and device scaling; do not manually multiply
widget sizes by the monitor's device pixel ratio.

## Repeatable checks

```sh
./scripts/compatibility-report.py > compatibility.json
./scripts/test-greeter.sh
QT_SCALE_FACTOR=1.5 ./scripts/test-greeter.sh
./scripts/test-greetd-protocol.sh
./scripts/test-launch-gate-e2e.sh
./scripts/test-launch-gate-e2e.sh --no-probe
./scripts/test-upgrade-recovery.sh
./scripts/run-isolated-greeter.sh --headless --outputs 2 --scenario auth
```

The report only reads package versions, DRM identifiers, connector modes and
explicit layout/output variables. It omits usernames, hostnames and monitor
serials. Review it before sharing. The interactive harness still uses nested
KWin; `--headless` uses Cage and does not need an existing desktop. Its virtual
outputs are 1280×720; custom fixture dimensions require KWin.

For each physical run, record date, package versions, GPU/driver, connector,
scale, keyboard map, boot/login/logout, failure and rollback results. Use a
maintenance TTY and disposable credentials. [UPGRADE_RECOVERY.md](UPGRADE_RECOVERY.md)
contains the recovery procedure. Do not mark an untested row as passing when
publishing the release.
