# Changelog

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

Still open before broader 1.0 acceptance: physical multi-monitor/hotplug and
mixed HiDPI, broader Intel/AMD/NVIDIA coverage, physical BR ABNT2, and a full
matching Qt package upgrade/downgrade exercise. VM mismatch injection is
recorded separately from an actual Qt package transaction.

Existing installations must merge any `greetd.toml.pacnew` to use
`/usr/lib/nocturne-greeter/nocturne-greeter-start`. See
[upgrade and recovery](docs/UPGRADE_RECOVERY.md).

## 0.9.0

Real greetd/PAM integration, users and installed Wayland sessions, remembered
selection, presentation-gated launch, power actions and Arch packaging.
Historical acceptance: [0.9 report](docs/INSTALL_0.9.md).
