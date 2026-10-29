#!/usr/bin/env bash
# Simulate upgrade failures only in temporary module copies; never change the
# installed module, greetd, PAM, or the host's active graphical session.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
check="$project_root/system/nocturne-greeter-check"
module="$project_root/build/qml/Nocturne/Presentation"
work="$(mktemp -d)"
trap 'rm -r -- "$work"' EXIT
"$check" --module-dir "$module"
mkdir -p "$work/Nocturne"
cp -a "$module" "$work/Nocturne/Presentation"
copy="$work/Nocturne/Presentation"
printf '0.0.0\n' > "$copy/qt-version"
if "$check" --module-dir "$copy" >"$work/check.log" 2>&1; then
    echo 'FAIL: a mismatched Qt version passed the preflight' >&2; exit 1
fi
grep -q 'installed Qt is' "$work/check.log"
"$check" --hook --module-dir "$copy" >"$work/hook.log" 2>&1
grep -q 'installed Qt is' "$work/hook.log"
cp "$module/qt-version" "$copy/qt-version"
printf 'invalid shared library\n' > "$copy/libnocturnepresentation.so"
if "$check" --module-dir "$copy" >"$work/check.log" 2>&1; then
    echo 'FAIL: an unloadable plugin passed the preflight' >&2; exit 1
fi
# Restore the exact known-good module, simulating rollback/rebuild.
cp "$module/libnocturnepresentation.so" "$copy/libnocturnepresentation.so"
"$check" --module-dir "$copy"
python3 -I -m unittest discover -s "$project_root/tests" -p test_recovery.py
printf 'PASS: Qt mismatch and unloadable plugin refused; hook warned; restored module loaded; launcher recovery passed.\n'
