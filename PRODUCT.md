# Product

<!-- impeccable:product-schema 1 -->

## Platform
Native Linux (Wayland), rendered with Qt Quick/QML and GLSL in Quickshell.

## Purpose and users
UMBRA is a greeter for Arch Linux x86_64 workstations using greetd
and the distribution's PAM configuration. It provides a calm transition from
idle to authentication and an installed Wayland session. Preview and isolated
fixtures remain available for development without authenticating real users.

## Confirmed constraints
Preserve the visual state controller, typed PAM challenges, cancellation,
root-owned session catalog, presentation-gated launch and low idle refresh.
Keep preview authentication and shortcuts outside the production entrypoint.
Do not change the workstation's display manager, PAM, boot, login services or
execute power actions during development. System integration and destructive
fault tests belong in an explicitly guarded disposable VM. Never log passwords
or authentication responses. Keep independent TTY recovery documented.

## Brand commitments
AMOLED black, restrained purple/lilac, cinematic orbital matter and a nearly
black celestial body. Original vector identity, installed typefaces, visible
keyboard focus and mouse affordances. Normal UI hides developer shortcuts.

## Scope
Version 1.0.0 includes real greetd/PAM authentication, local users and Wayland
sessions, persistent selection, power actions, complete menu keyboard controls,
explicit output selection and text login recovery when Qt preflight fails.
The Arch package, tests, CI and snapshot release tooling are part of the product.
The interface is currently English. X11 and other distributions are outside
the release target. The supported deployment is the owner's existing
workstation with one monitor. Additional GPUs, physical multi-monitor/hotplug
and mixed-monitor scaling are outside the 1.0 scope, not release blockers.
Virtual-output tests remain regression fixtures. Maintenance of Qt integration
and future interface improvements are separate from this functional baseline.
Acceptance evidence and its limits are recorded in docs/COMPATIBILITY.md.

## License
MIT for this repository's original code and assets. Dependencies and system
fonts retain their own licenses and are not bundled in the source archive.
