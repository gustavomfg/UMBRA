# Nocturne Greeter — Umbra 0.9

[Português (Brasil)](README.md) · English

A greeter for Wayland sessions, built with **Quickshell, QML and GLSL** and integrated with **greetd + PAM**. The interface combines an obsidian body, animated orbital matter and a minimal sign-in screen.

**Ready for use on Arch Linux.** Version `0.9.0-2` is installed and in use on the author's system, following validation of real login, sessions, power actions and boot in a disposable VM.

![Nocturne Greeter Umbra sign-in screen](docs/screenshots/nocturne-umbra-auth.png)

*Current interface, captured at 1920×1080 in preview mode with a demonstration identity.*

## Features

- Real authentication through greetd and the distribution's PAM configuration, with error and account lockout messages.
- Local user and installed Wayland session selection, remembering the last choice.
- A session catalog generated from `/usr/share/wayland-sessions`, including Hyprland, Hyprland via uwsm and Plasma Wayland when installed.
- Suspend, restart and shut down from the login screen.
- An animated transition into the session, released only after the compositor presents the black frame.
- Responsive layout, keyboard navigation, clock and orbital shader.
- An Arch Linux package with the presentation module, greetd configuration and pacman hooks.
- An in-session preview and an isolated Wayland harness for development.

## Installation on Arch Linux

Clone the repository and build the local package:

```sh
git clone --branch feat/real-login-vm https://github.com/gustavomfg/nocturne-greeter.git
cd nocturne-greeter/packaging/arch
makepkg -sif
```

`makepkg` installs the dependencies declared in the [PKGBUILD](packaging/arch/PKGBUILD), including greetd, Cage, Quickshell, Qt 6 and fonts. Building requires the `base-devel` group. The `Nocturne.Presentation` module is compiled against the installed Qt version.

The package installs the interface in `/usr/share/nocturne-greeter` and configures the greetd service to use `/etc/nocturne-greeter/greetd.toml`. **Installation does not automatically enable or start greetd.**

Before switching login managers, save your work and open a TTY with `Ctrl+Alt+F3`. The [installation, activation and recovery runbook](docs/INSTALL_0.9.md#item-5-runbook--install-on-this-workstation) explains how to test the greeter and make it the default login screen. Its example uses `plasmalogin`; replace that with your current login manager's service when necessary.

### Maintenance and diagnostics

After Qt or Quickshell updates, the package hook checks whether the presentation module still loads. If it becomes incompatible, rebuild and reinstall:

```sh
cd packaging/arch   # from the repository root
makepkg -sif
```

To check the installation and view logs:

```sh
/usr/lib/nocturne-greeter/nocturne-greeter-check
journalctl -b -u greetd
journalctl -b -t nocturne-greeter
journalctl -b -t nocturne-session
```

A pacman hook updates the session catalog. To regenerate it manually after editing a session file:

```sh
sudo /usr/lib/nocturne-greeter/nocturne-greeter-sessions
```

## Usage

- Click the background or press a key to open the sign-in screen. `Space` only wakes the interface; other printable keys also start typing.
- Choose a user from the menu available while idle and a session from the bottom bar menu.
- Type your password and press `Enter` or click the arrow to sign in.
- `Esc` closes an open menu or returns to idle and clears the password.
- The power menu offers suspend, restart and shut down.

The interface is in English; dates follow the Qt locale. Fonts are **Noto Sans Light**, **Adwaita Sans** and, in debug mode, **Adwaita Mono**.

## Preview

To explore the interface without leaving your current session, run from the repository root:

```sh
./scripts/run-preview.sh
```

The preview opens fullscreen on the primary monitor. `Ctrl+Q` or `Alt+F4` exits. To open it in a window:

```sh
NOCTURNE_WINDOWED=1 NOCTURNE_WIDTH=1280 NOCTURNE_HEIGHT=720 ./scripts/run-preview.sh
```

In preview mode, `Enter` simulates a failure and `Ctrl+Enter` simulates the success animation. Power controls are disabled, and network, audio and battery indicators are read-only. Use test text in the password field: this mode does not authenticate or launch sessions.

`NOCTURNE_DEBUG=1` reveals development controls; `NOCTURNE_USER_NAME` changes the displayed name. Tiling compositors may override the requested window size.

## Development and verification

Run these commands from the repository root:

```sh
./scripts/build-shader.sh
./scripts/build-presentation-probe.sh
./scripts/test-greeter.sh
./scripts/lint-qml.sh
./scripts/test-greetd-adapter.sh
./scripts/test-greetd-protocol.sh
./scripts/test-launch-gate-e2e.sh
./scripts/test-launch-gate-e2e.sh --no-probe
./scripts/test-real-login-vm-guard.sh
python3 -I -m unittest discover -s tests -p 'test_sessions_catalog.py'
```

Tests cover interface states, keyboard input and focus, user and session catalogs, greetd protocol integration and blocking session launch when the presentation module is unavailable. Protocol and launch tests use nested KWin Wayland and a socket fixture, without authenticating real users.

### Isolated harness

```sh
./scripts/run-isolated-greeter.sh
./scripts/run-isolated-greeter.sh --mock-success
./scripts/run-isolated-greeter.sh --no-session-bus --duration 10
```

The harness opens a nested KWin Wayland instance with its own runtime, socket and D-Bus, using a mock backend. `Ctrl+C` in the terminal exits; logs are saved in `logs/isolated-greeter/`.

### Screenshots

```sh
./scripts/capture-preview.sh
```

Generates interface state images in `docs/screenshots/final/` at 1280×720, 1920×1080, 2560×1440 and 3440×1440. Each state uses a separate preview process. Images are rendered on Qt canvases; this does not change the monitor resolution or replace testing on four physical monitors.

## Architecture

| Path | Role |
| --- | --- |
| `greeter/shell.qml` | Production entry point for greetd |
| `shell.qml` | In-session preview entry point |
| `components/GreeterWindow.qml` | Responsive composition, focus and visual integration |
| `components/GreeterController.qml` | Idle, authentication, success and failure states |
| `components/GreetdAuthenticator.qml`, `AuthenticatorBridge.qml` | Authentication, PAM prompts and cancellation |
| `components/GreeterCatalog.qml`, `greeter-model.js` | Users, sessions and last selection |
| `components/SessionLaunchPolicy.qml`, `SessionLaunchGate.qml` | Administrative policy and session launch gating |
| `presentation/` | C++ module that confirms black frame presentation through `wp_presentation` |
| `shaders/`, `assets/` | Orbital shader, brand mark and icons |
| `system/`, `packaging/arch/` | Session catalog, configuration, hooks and package |
| `harness/`, `tests/`, `vm/` | Mocks, tests and disposable VM tools |

The greeter reads a root-written catalog at `/var/lib/nocturne-greeter/sessions.json`; session commands do not come from the authentication field. Launch happens exactly once, after black frame presentation is confirmed. If the presentation module is missing or confirmation fails, launch remains blocked.

## Compatibility and documentation

The current target is **Arch Linux x86_64 with Wayland sessions**. Use on the author's system complements VM testing; compatibility with other distributions, GPUs and multi-monitor configurations requires specific validation. X11 sessions from `/usr/share/xsessions` are not offered.

- [Installation, maintenance and version 0.9 results](docs/INSTALL_0.9.md)
- [Real login and boot validation in a VM — 0.8](docs/REAL_LOGIN_VM_0.8.md)
- [greetd protocol integration — 0.7](docs/GREETD_PROTOCOL_0.7.md)
- [Isolated Wayland harness — 0.6](docs/ISOLATED_GREETER_HARNESS_0.6.md)
- [Authentication and session launch architecture — 0.5](docs/REAL_LOGIN_ARCHITECTURE_0.5.md)
- [Visual system](DESIGN.md), [visual review](docs/ART_DIRECTION_REVIEW.md) and [references](docs/REFERENCE_NOTES.md) (in Portuguese)

Numbered reports preserve the context of each development stage. To recover previous versions, use Git history; local snapshots in `backups/` are not distributed.
