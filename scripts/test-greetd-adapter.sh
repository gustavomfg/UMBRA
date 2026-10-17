#!/usr/bin/env bash
# Runs GreetdAuthenticator's launch-policy checks inside Quickshell, whose
# Greetd module cannot be loaded by qmltestrunner. Uses a fake Greetd API only.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
run_root="$(mktemp -d "${TMPDIR:-/tmp}/nocturne-greetd-adapter.XXXXXX")"
trap 'rm -r -- "$run_root"' EXIT

mkdir "$run_root/components"
cp -- "$project_root/components/"*.qml "$project_root/components/"*.js "$run_root/components/"
cp -- "$project_root/tests/greetd-adapter/shell.qml" "$run_root/shell.qml"

output="$(env -u GREETD_SOCK QT_QPA_PLATFORM=offscreen timeout 20 quickshell --no-duplicate -p "$run_root" 2>&1)" && status=0 || status=$?
printf '%s\n' "$output" | grep -E 'PASS|FAIL|greetd-adapter:|ERROR|error' || true
if [[ $status -ne 0 ]] || ! grep -q 'greetd-adapter: [0-9]* passed, 0 failed' <<< "$output"; then
    printf 'GreetdAuthenticator launch-policy checks failed (exit %s).\n' "$status" >&2
    exit 1
fi
