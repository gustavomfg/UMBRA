#!/usr/bin/env bash
# Exercise nocturne-greeter-update against a fake Qt, a fake preflight and a
# fake build script, all inside a temporary directory. It never touches the
# installed module, greetd, PAM or the running session.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
update="$project_root/system/nocturne-greeter-update"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export FAKE="$work/fake"
mkdir -p "$FAKE" "$work/src/scripts" "$work/src/presentation" "$work/qml/Nocturne"

# Fake preflight: passes only when the module was "built" for the current Qt.
cat > "$FAKE/check" <<'CHK'
#!/bin/bash
module=""
while (($#)); do case "$1" in --module-dir) module="$2"; shift 2 ;; *) shift ;; esac; done
current="$(cat "$FAKE/current-qt")"
if [[ "$(cat "$module/qt-version" 2>/dev/null)" != "$current" ]]; then
    echo "module was built for Qt $(cat "$module/qt-version" 2>/dev/null); installed Qt is $current" >&2; exit 1
fi
[[ ! -e "$module/broken" ]] || { echo 'module failed to load' >&2; exit 1; }
echo 'OK'
CHK
# Fake build: writes a module for the current Qt, unless told to fail or to break.
cat > "$work/src/scripts/build-presentation-probe.sh" <<'BLD'
#!/bin/bash
set -e
echo run >> "$FAKE/build-calls"
[[ ! -e "$FAKE/fail-build" ]] || { echo 'moc: command not found' >&2; exit 1; }
out="$NOCTURNE_BUILD_DIR/qml/Nocturne/Presentation"
mkdir -p "$out"
printf 'fake-lib' > "$out/libnocturnepresentation.so"
printf 'module Nocturne.Presentation\n' > "$out/qmldir"
cp "$FAKE/current-qt" "$out/qt-version"
[[ ! -e "$FAKE/make-broken" ]] || touch "$out/broken"
BLD
chmod +x "$FAKE/check" "$work/src/scripts/build-presentation-probe.sh"

module="$work/qml/Nocturne/Presentation"
install_module() {
    rm -rf "$module"; mkdir -p "$module"
    printf 'old-lib' > "$module/libnocturnepresentation.so"
    printf 'module Nocturne.Presentation\n' > "$module/qmldir"
    printf '%s\n' "$1" > "$module/qt-version"
}
run_update() {
    "$update" --module-dir "$module" --src-dir "$work/src" --check-cmd "$FAKE/check" --build-user none "$@"
}
calls() { [[ -f "$FAKE/build-calls" ]] && wc -l < "$FAKE/build-calls" || echo 0; }
reset() { rm -f "$FAKE/build-calls" "$FAKE/fail-build" "$FAKE/make-broken"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

echo 6.12.1 > "$FAKE/current-qt"

# 1. Module already matches: nothing is rebuilt.
reset; install_module 6.12.1
run_update >"$work/out.log" 2>&1 || fail 'a current module made the helper fail'
[[ "$(calls)" == 0 ]] || fail 'a current module was rebuilt'
grep -q 'nothing to rebuild' "$work/out.log" || fail 'missing the "nothing to rebuild" message'

# 2. Qt moved on: the module is rebuilt, verified and swapped in.
reset; install_module 6.12.0
run_update >"$work/out.log" 2>&1 || fail 'the rebuild after a Qt update failed'
[[ "$(calls)" == 1 ]] || fail 'the stale module was not rebuilt exactly once'
[[ "$(cat "$module/qt-version")" == 6.12.1 ]] || fail 'the rebuilt module still reports the old Qt'
[[ "$(stat -c %a "$module/libnocturnepresentation.so")" == 644 ]] || fail 'the installed library is not mode 644'
[[ "$(cat "$module/libnocturnepresentation.so")" == fake-lib ]] || fail 'the library was not replaced'
ls -A "$work/qml/Nocturne" | grep -q '^\.nocturne-presentation' && fail 'staging or backup directories were left behind'
"$FAKE/check" --module-dir "$module" >/dev/null || fail 'the installed module does not pass the preflight'

# 3. The build fails: the installed module is untouched; --hook still exits 0.
reset; install_module 6.12.0; touch "$FAKE/fail-build"
if run_update >"$work/out.log" 2>&1; then fail 'a failed build reported success'; fi
grep -q 'moc: command not found' "$work/out.log" || fail 'the build error was not shown'
[[ "$(cat "$module/qt-version")" == 6.12.0 && "$(cat "$module/libnocturnepresentation.so")" == old-lib ]] || fail 'a failed build changed the installed module'
run_update --hook >"$work/out.log" 2>&1 || fail '--hook must never fail the pacman transaction'

# 4. The rebuilt copy does not pass the preflight: it is never installed.
reset; install_module 6.12.0; touch "$FAKE/make-broken"
if run_update >"$work/out.log" 2>&1; then fail 'a broken rebuild was accepted'; fi
[[ "$(cat "$module/libnocturnepresentation.so")" == old-lib ]] || fail 'a broken rebuild replaced the installed module'

# 5. --force rebuilds even when the preflight already passes.
reset; install_module 6.12.1
run_update --force >"$work/out.log" 2>&1 || fail 'a forced rebuild failed'
[[ "$(calls)" == 1 ]] || fail '--force did not rebuild'
[[ "$(cat "$module/libnocturnepresentation.so")" == fake-lib ]] || fail '--force did not install the new library'

# 6. Missing sources: refuse cleanly, leave the module alone.
reset; install_module 6.12.0
if "$update" --module-dir "$module" --src-dir "$work/nowhere" --check-cmd "$FAKE/check" --build-user none >"$work/out.log" 2>&1; then
    fail 'missing sources reported success'
fi
grep -q 'build sources are missing' "$work/out.log" || fail 'missing sources were not reported'
[[ "$(cat "$module/qt-version")" == 6.12.0 ]] || fail 'missing sources changed the module'

# 7. No scratch directories are left in /var/tmp.
if compgen -G '/var/tmp/nocturne-greeter-update.*' >/dev/null; then fail 'a scratch directory was left behind'; fi
printf 'PASS: stale module rebuilt and swapped; current module untouched; failed or broken builds rolled back; --hook never fails; --force and missing sources handled.\n'
