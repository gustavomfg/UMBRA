# Changelog

## After 1.0.0 — package revision 1.0.0-2

- Remove the Nocturne symbol and wordmark from the greeter header.
- Keep network and audio indicators visible beside Power when services are
  unavailable, with explicit tooltips and no simulated volume/mute state.
- Observe NetworkManager's system service before login. User-session PipeWire
  is not loaded by the production greeter; its audio indicator explains that
  pre-login audio is unavailable. Preview continues to show live session audio.
- Cover unavailable/connected/disconnected/volume/mute states in QML and check
  indicator visibility in the actual production/package launch fixture.


## 1.0.0 — 2026-10-29

Functional baseline closed for the owner's existing Arch Linux x86_64 / Wayland
workstation with one monitor. Authentication, sessions, power, keyboard menu
controls, Qt preflight, text login recovery, MIT licensing, package generation
and CI are complete within that scope. No interface changes are included.

- Other GPUs, physical multi-monitor/hotplug configurations and mixed-monitor
  scaling are excluded from release acceptance at the owner's request.
- The support record distinguishes tested evidence from out-of-scope hardware;
  excluded cases were not relabeled as passing tests.
- Qt mismatch and damaged-plugin tests plus the real VM text-login recovery
  cycle are accepted coverage. Future Qt/Quickshell package transactions are
  maintenance checks rather than remaining 1.0 tasks.
- The existing BR ABNT2 host configuration was confirmed through read-only
  inventory; this is configuration evidence, not an additional physical test.
- Package and checkout instructions now target `1.0.0-1` / `v1.0.0`.

The functional code is unchanged from 0.9.1. The automated release suite and
package checks are rerun for this snapshot. Detailed evidence and scope:
[COMPATIBILITY.md](docs/COMPATIBILITY.md). Future interface work builds on this
baseline as a separate change.

## 0.9.1 — 2026-10-29

Stabilization release for Arch Linux x86_64 and Wayland. Hardware coverage is
explicit in [the compatibility matrix](docs/COMPATIBILITY.md); this release
does not claim certification for every GPU, monitor or keyboard combination.

- Complete keyboard navigation in user, session and power menus, with visible
  focus, accessible actions, selection, dismissal and focus restoration.
- Preferred connector through `NOCTURNE_OUTPUT`, deterministic fallback and
  output/scale diagnostics. Screen selection re-evaluates on output changes.
- Exact Qt build metadata and strict preflight using the actual Quickshell
  loader and exact presentation plugin directory.
- agreety text login if preflight fails; after PAM, a numbered selection from
  the root-owned Wayland session catalog. A separate TTY remains necessary
  for compositor/driver failures occurring after preflight.
- Headless Cage protocol and presentation fixtures, including an absent-module
  injection that cannot accidentally load a system-installed plugin.
- Private temporary test staging, disposable VM overlays and a corrected
  canary scanner with positive leak/error tests.
- MIT license, Arch CI, source snapshot/package generation, SHA-256 checksums,
  and runtime presentation tests against the extracted package.
- Shader compilation during package build, against the installed Qt tools.

Validation: 70 QML tests, 35 Python tests, 17 adapter checks, nine protocol
scenarios, presentation tests with/without the module, Qt mismatch and damaged
plugin fault tests, two virtual outputs, and model/menu tests at 150% scale.
Lint completed with advisory warnings. Auth captures at 1280×720 logical / 150%
and 3440×1440 / 100% were inspected.

The guarded QEMU/KVM guest passed package installation, real graphical
login/logout, forced Qt mismatch → agreety/PAM → selected Wayland session,
module restoration, reboot and another graphical login/logout. The release
package `0.9.1-1` also built locally from a clean committed snapshot and passed
content/license checks plus both packaged launch-gate scenarios.

The initial proposal for broader 1.0 acceptance included a hardware matrix
and a full Qt package transaction. The owner later excluded other GPUs and
multi-monitor testing; the 1.0 support scope and accepted recovery coverage
above supersede that proposed checklist. Recorded test results are unchanged.

Existing installations must merge any `greetd.toml.pacnew` to use
`/usr/lib/nocturne-greeter/nocturne-greeter-start`. See
[upgrade and recovery](docs/UPGRADE_RECOVERY.md).

## 0.9.0

Real greetd/PAM integration, users and installed Wayland sessions, remembered
selection, presentation-gated launch, power actions and Arch packaging.
Historical acceptance: [0.9 report](docs/INSTALL_0.9.md).
