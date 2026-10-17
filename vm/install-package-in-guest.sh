#!/usr/bin/env bash
# Inside the disposable VM guest only: build the nocturne-greeter package as an
# unprivileged user and install it with pacman. Refuses unless the real-login
# VM guard passes. Also removes the earlier hand-installed 0.8 files.
#
#   sudo ./vm/install-package-in-guest.sh --confirm-real-login-vm BUILD_USER
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" != --confirm-real-login-vm || -z "${2:-}" ]]; then
    printf 'Usage: %s --confirm-real-login-vm BUILD_USER\n' "$0" >&2
    exit 2
fi
build_user="$2"
"$project_root/scripts/real-login-vm-guard.py" --check --confirm-real-login-vm
if [[ $EUID -ne 0 ]]; then
    printf 'Run as root inside the VM guest.\n' >&2
    exit 2
fi

# 0.8 hand-installed files (not owned by any package).
if ! pacman -Qo /usr/share/nocturne-greeter >/dev/null 2>&1; then
    rm -rf -- /usr/share/nocturne-greeter /usr/lib/qt6/qml/Nocturne
fi
rm -f -- /etc/greetd/nocturne-umbra.toml /etc/systemd/system/greetd.service.d/nocturne-umbra.conf
rmdir --ignore-fail-on-non-empty /etc/systemd/system/greetd.service.d 2>/dev/null || true

work="$(runuser -u "$build_user" -- mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
tar -C "$project_root" --exclude=./build --exclude=./packaging/arch/pkg --exclude=./packaging/arch/src \
    --exclude='./packaging/arch/*.pkg.tar.*' -cf - . | runuser -u "$build_user" -- tar -C "$work" -xf -
runuser -u "$build_user" -- bash -c "cd '$work/packaging/arch' && makepkg -f --noconfirm" >/dev/null
pacman -U --noconfirm "$work"/packaging/arch/nocturne-greeter-*.pkg.tar.zst
systemctl daemon-reload
