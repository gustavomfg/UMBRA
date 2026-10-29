# Compatibility and acceptance matrix

## Closed 1.0 support scope

Version **1.0.0** closes the functional baseline for the owner's existing
**Arch Linux x86_64 / Wayland workstation with one monitor**, using greetd,
Cage and the distribution's PAM configuration. Existing workstation use is
recorded in [the 0.9 report](INSTALL_0.9.md); the release checks and disposable
VM exercise the code, package and recovery paths.

On 2026-10-29 the owner explicitly excluded testing other GPUs and physical
multi-monitor setups from completion. Those configurations, physical hotplug
and mixed-monitor scaling are outside this release's support scope. They are
not an unfinished checklist and no additional hardware testing is required
for this baseline. X11, other distributions and laptop-specific hardware
certification are also outside the target.

The completed virtual-output and HiDPI checks remain regression evidence;
they are not a claim of physical hardware certification. No test result was
changed from untested to passed when narrowing the scope.

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
| Screen preference and disconnect/reconnect | Selector tests: preferred connector, origin, name fallback, empty outputs | Passed for selector behavior; physical hotplug outside scope |
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

## Accepted coverage and maintenance

The VM suite injects a Qt version mismatch, verifies text login recovery,
and restores the matching module. It does **not** simulate a complete pacman
Qt upgrade/downgrade. This is an explicit limit of the evidence, not a 1.0
release gate. Rebuild and check the greeter after future Qt/Quickshell
updates using [UPGRADE_RECOVERY.md](UPGRADE_RECOVERY.md).

Keyboard evidence includes real US-layout input in the guest and the existing
workstation's configured `br-abnt2` console keymap / `br` X11 layout (read-only
`localectl status`, 2026-10-29). The latter confirms configuration, not a new
physical login test. The baseline relies on the existing workstation use and
the typed-input/PAM regression tests; a separate keyboard hardware matrix is
not part of this release.

Suspend/reboot/power-off results remain recorded in the historical VM report.
No additional laptop or power-inhibitor certification is claimed.

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

For maintenance checks on the supported workstation, record the package and
Qt versions and verify login/logout and independent TTY recovery. The owner
has excluded other GPUs and multi-monitor acceptance runs; do not recreate
those as release blockers. [UPGRADE_RECOVERY.md](UPGRADE_RECOVERY.md) contains
the maintenance and recovery procedure.
