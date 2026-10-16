#!/usr/bin/env bash
# Installs Umbra as the pre-login greeter inside the disposable 0.8 VM guest.
# Refuses to write anything unless the real-login VM guard passes.
#
#   sudo ./scripts/stage-vm-greeter.sh --confirm-real-login-vm
#
# Writes (guest only): /usr/share/nocturne-greeter (root-owned, read-only for
# the greeter), /usr/lib/qt6/qml/Nocturne/Presentation,
# /etc/greetd/nocturne-umbra.toml and a greetd.service drop-in that points the
# packaged unit (Restart=always) at that config. It does not enable greetd.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" != --confirm-real-login-vm ]]; then
    printf 'Refusing without --confirm-real-login-vm.\n' >&2
    exit 2
fi
"$project_root/scripts/real-login-vm-guard.py" --check --confirm-real-login-vm
if [[ $EUID -ne 0 ]]; then
    printf 'Run as root inside the VM guest.\n' >&2
    exit 2
fi

"$project_root/scripts/stage-isolated-greeter.sh" >/dev/null
"$project_root/scripts/build-presentation-probe.sh" >/dev/null

staged="$project_root/production-root/usr/share/nocturne-greeter"
work="$(mktemp -d)"
trap 'rm -r -- "$work"' EXIT
cp -a -- "$staged/." "$work/"
cp -- "$project_root/vm/SessionLaunchPolicy.qml" "$work/components/SessionLaunchPolicy.qml"
(
    cd "$work"
    find shell.qml components assets shaders -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

install_tree() {
    local source="$1" target="$2"
    rm -rf -- "$target"
    mkdir -p -- "$target"
    cp -a -- "$source/." "$target/"
    chown -R root:root -- "$target"
    find "$target" -type d -exec chmod 0755 {} +
    find "$target" -type f -exec chmod 0644 {} +
}
install_tree "$work" /usr/share/nocturne-greeter
(cd /usr/share/nocturne-greeter && sha256sum --quiet -c SHA256SUMS)
install_tree "$project_root/build/qml/Nocturne/Presentation" /usr/lib/qt6/qml/Nocturne/Presentation

# greetd hands the greeter its VT as stdio; systemd-cat keeps compositor and
# QML logs in the journal instead of printing them on the console after exit.
install -o root -g root -m 0644 /dev/stdin /etc/greetd/nocturne-umbra.toml <<'TOML'
# Nocturne 0.8 VM experiment. Installed by scripts/stage-vm-greeter.sh.
[terminal]
vt = 1

[default_session]
command = "systemd-cat --identifier=nocturne-greeter -- cage -s -- /usr/bin/quickshell --no-duplicate --path /usr/share/nocturne-greeter"
user = "greeter"
TOML

install -d -o root -g root -m 0755 /etc/systemd/system/greetd.service.d
install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/greetd.service.d/nocturne-umbra.conf <<'UNIT'
# Nocturne 0.8 VM experiment: packaged unit, Umbra config. Not enabled here.
[Service]
ExecStart=
ExecStart=/usr/bin/greetd --config /etc/greetd/nocturne-umbra.toml
UNIT
systemctl daemon-reload

printf 'Installed Umbra pre-login tree, presentation module, /etc/greetd/nocturne-umbra.toml and greetd drop-in.\n'
printf 'This script does not change the greetd boot target (currently: %s).\n' "$(systemctl is-enabled greetd 2>/dev/null || true)"
