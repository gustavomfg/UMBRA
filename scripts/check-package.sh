#!/usr/bin/env bash
# Inspect the actual package, then exercise its QML/plugin with a fixture.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
package="${1:?Usage: check-package.sh PACKAGE.pkg.tar.zst}"
work="$(mktemp -d)"
trap 'rm -r -- "$work"' EXIT
bsdtar -xf "$package" -C "$work"
share="$work/usr/share/nocturne-greeter"
module="$work/usr/lib/qt6/qml/Nocturne/Presentation"
for file in shell.qml components/GreetdAuthenticator.qml components/GreeterSystemStatus.qml components/SessionLaunchGate.qml shaders/pulse.frag.qsb; do
    test -s "$share/$file"
done
for helper in nocturne-greeter-start nocturne-greeter-check nocturne-recovery-session nocturne-greeter-sessions; do
    test -x "$work/usr/lib/nocturne-greeter/$helper"
done
test -s "$module/qt-version"
cmp "$project_root/LICENSE" "$work/usr/share/licenses/nocturne-greeter/LICENSE"
if find "$share" -type f | grep -Eq 'Preview|Mock|Harness|E2EDriver'; then
    echo 'FAIL: a development adapter was packaged' >&2; exit 1
fi
grep -q 'previewShortcutsEnabled: false' "$share/shell.qml"
grep -q 'nocturne-greeter-start' "$work/etc/nocturne-greeter/greetd.toml"
"$project_root/system/nocturne-greeter-check" --module-dir "$module"
NOCTURNE_TEST_INSTALL_ROOT="$work" "$project_root/scripts/test-launch-gate-e2e.sh"
NOCTURNE_TEST_INSTALL_ROOT="$work" "$project_root/scripts/test-launch-gate-e2e.sh" --no-probe
printf 'PASS: package contents, MIT license, recovery helpers and packaged presentation gate.\n'
