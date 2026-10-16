#!/usr/bin/env bash
# End-to-end launch gate check: greeter/shell.qml (pre-login entrypoint) in a
# headless KWin, real Quickshell Greetd API, local IPC fixture, and the real
# Nocturne.Presentation probe. The fixture acknowledges start_session but has
# no code that executes a command. Expected order in the greeter log:
#   success-finished → black-commit-armed → black-commit-presented → launch-requested
# and Quickshell exits after the launch acknowledgement.
#   --no-probe   run without the presentation module; launch must stay blocked.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
with_probe=1
if [[ "${1:-}" == --no-probe ]]; then
    with_probe=0
fi

if ((with_probe)) && [[ ! -f "$project_root/build/qml/Nocturne/Presentation/libnocturnepresentation.so" ]]; then
    "$project_root/scripts/build-presentation-probe.sh" >/dev/null
fi

umask 077
# Short path: Wayland socket paths are limited to 108 bytes.
run_root="$(mktemp -d /tmp/ncg-e2e.XXXXXX)"
fixture_pid=''
cleanup() {
    if [[ -n "$fixture_pid" ]] && kill -0 "$fixture_pid" 2>/dev/null; then
        kill -TERM "$fixture_pid" 2>/dev/null || true
        wait "$fixture_pid" 2>/dev/null || true
    fi
    rm -r -- "$run_root"
}
trap cleanup EXIT

mkdir -m 700 "$run_root/runtime" "$run_root/stage" "$run_root/stage/components"
cp -- "$project_root/components/"*.qml "$run_root/stage/components/"
cp -- "$project_root/tests/launch-e2e/SessionLaunchPolicy.qml" "$run_root/stage/components/SessionLaunchPolicy.qml"
cp -- "$project_root/tests/launch-e2e/E2EDriver.qml" "$run_root/stage/E2EDriver.qml"
cp -a -- "$project_root/assets" "$project_root/shaders" "$run_root/stage/"
# Inject the driver as the last child of ShellRoot.
python3 - "$project_root/greeter/shell.qml" "$run_root/stage/shell.qml" <<'PY'
import sys
source = open(sys.argv[1], encoding="utf-8").read().rstrip()
assert source.endswith("}")
driver = "\n    E2EDriver {\n        controller: greeter.controller\n        authPanel: greeter.authPanel\n    }\n}\n"
open(sys.argv[2], "w", encoding="utf-8").write(source[:-1] + driver)
PY

status_file="$run_root/runtime/fixture-status.json"
greetd_sock="$run_root/runtime/greetd.sock"
python3 "$project_root/harness/protocol/greetd-fixture.py" \
    --socket "$greetd_sock" --status-file "$status_file" --scenario launch-acknowledged \
    >"$run_root/fixture.log" 2>&1 &
fixture_pid=$!
for ((attempt = 0; attempt < 50; attempt++)); do
    [[ -S "$greetd_sock" ]] && break
    sleep 0.1
done

import_path=/usr/lib/qt6/qml
if ((with_probe)); then
    import_path="$project_root/build/qml:$import_path"
fi

set +e
env -i PATH=/usr/bin HOME="$run_root/runtime" XDG_RUNTIME_DIR="$run_root/runtime" \
    QML_IMPORT_PATH="$import_path" GREETD_SOCK="$greetd_sock" \
    timeout 30 kwin_wayland --virtual --no-lockscreen --socket ncg-0 --width 1280 --height 720 \
    --exit-with-session "/usr/bin/quickshell --no-duplicate -p $run_root/stage" \
    >"$run_root/greeter.log" 2>&1
kwin_status=$?
set -e

kill -TERM "$fixture_pid" 2>/dev/null || true
wait "$fixture_pid" 2>/dev/null || true
fixture_pid=''

grep -E 'nocturne-launch|e2e:' "$run_root/greeter.log" | sed 's/\x1b\[[0-9;]*m//g' || true
if grep -q 'fixture-response' "$run_root/greeter.log"; then
    printf 'FAIL: the authentication response appeared in the greeter log\n' >&2
    exit 1
fi

python3 - "$status_file" "$run_root/greeter.log" "$with_probe" "$kwin_status" <<'PY'
import json, re, sys

status = json.load(open(sys.argv[1], encoding="utf-8"))
log = re.sub(r"\x1b\[[0-9;]*m", "", open(sys.argv[2], encoding="utf-8", errors="replace").read())
with_probe = sys.argv[3] == "1"
markers = re.findall(r"nocturne-launch: ([a-z-]+)", log)
print("Fixture: create_session={create_session} start_session={start_session}".format(**status))
print("KWin/Quickshell exit status: " + sys.argv[4])

if with_probe:
    expected = ["success-finished", "black-commit-armed", "black-commit-presented", "launch-requested"]
    if markers[:4] != expected:
        raise SystemExit("FAIL: unexpected marker order: %r" % markers)
    if status.get("start_session") != 1:
        raise SystemExit("FAIL: expected exactly one start_session")
    if status.get("start_session_cmd") != ["/usr/bin/false", "nocturne-fixture-session"]:
        raise SystemExit("FAIL: start_session argv was not the fixed policy argv")
    if sys.argv[4] == "124":
        raise SystemExit("FAIL: Quickshell did not exit after the launch acknowledgement")
    print("PASS: black frame presented before the single allowlisted launch request; Quickshell exited.")
else:
    if status.get("start_session", 0) != 0 or "launch-requested" in markers:
        raise SystemExit("FAIL: launch was requested without presentation feedback")
    if "launch-blocked" not in markers:
        raise SystemExit("FAIL: gate did not report a blocked launch: %r" % markers)
    print("PASS: without presentation feedback the launch stayed blocked.")
PY
