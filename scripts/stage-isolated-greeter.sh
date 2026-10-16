#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
staging_parent="$project_root/production-root/usr/share"
staging_tree="$staging_parent/nocturne-greeter"

if [[ -L "$staging_tree" ]]; then
    printf 'Refusing a symlinked staging tree: %s\n' "$staging_tree" >&2
    exit 1
fi

mkdir -p "$staging_parent"
build_tree="$(mktemp -d "$staging_parent/.nocturne-build.XXXXXX")"
cleanup() {
    if [[ -d "$build_tree" ]]; then
        rm -r -- "$build_tree"
    fi
}
trap cleanup EXIT

mkdir -p "$build_tree/components" "$build_tree/assets" "$build_tree/shaders"

common_components=(
    AuthPanel.qml
    AuthenticatorBridge.qml
    ClockDisplay.qml
    CosmicScene.qml
    GreetdAuthenticator.qml
    GreeterController.qml
    GreeterWindow.qml
    IconButton.qml
    SessionLaunchGate.qml
    SessionLaunchPolicy.qml
    SystemChrome.qml
)
for component in "${common_components[@]}"; do
    if [[ -L "$project_root/components/$component" ]]; then
        printf 'Refusing a symlinked component: %s\n' "$component" >&2
        exit 1
    fi
    cp -- "$project_root/components/$component" "$build_tree/components/$component"
done

if [[ -n "$(find "$project_root/assets" -type l -print -quit)" ]]; then
    printf 'Refusing symlinks in assets.\n' >&2
    exit 1
fi
cp -a -- "$project_root/assets/." "$build_tree/assets/"
if [[ -L "$project_root/shaders/pulse.frag.qsb" ]]; then
    printf 'Refusing a symlinked QSB.\n' >&2
    exit 1
fi
cp -- "$project_root/shaders/pulse.frag.qsb" "$build_tree/shaders/pulse.frag.qsb"
# Pre-login entrypoint. The default SessionLaunchPolicy has no user or command,
# so this tree blocks every launch until an owned policy replaces it.
cp -- "$project_root/greeter/shell.qml" "$build_tree/shell.qml"

(
    cd "$build_tree"
    find shell.qml components assets shaders -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

if [[ -e "$staging_tree" ]]; then
    rm -r -- "$staging_tree"
fi
mv -- "$build_tree" "$staging_tree"
trap - EXIT

printf 'Staged shared visual files at %s\n' "$staging_tree"
printf 'No mock backend, preview authenticator, capture hook, service or PAM file was staged.\n'
