#!/usr/bin/env bash
# Build exclusively from a clean committed snapshot, as a regular user.
# Source archives are deterministic for a commit; binary packages depend on
# the Arch/Qt toolchain recorded by makepkg in .BUILDINFO.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if ((EUID == 0)); then echo 'Build releases as a regular user.' >&2; exit 2; fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo 'Commit or stash local changes before building a release snapshot.' >&2; exit 2
fi
output_dir="${1:-$project_root/dist}"
mkdir -p -- "$output_dir"
output_dir="$(realpath "$output_dir")"
version="$(sed -n 's/^pkgver=//p' packaging/arch/PKGBUILD)"
release="$(sed -n 's/^pkgrel=//p' packaging/arch/PKGBUILD)"
revision="$(git rev-parse --short=12 HEAD)"
name="nocturne-greeter-$version-$revision"
archive="$output_dir/$name.tar.gz"
git archive --format=tar --prefix="$name/" HEAD | gzip -n > "$archive"
work="$(mktemp -d)"
trap 'rm -r -- "$work"' EXIT
tar -xzf "$archive" -C "$work"
(
    cd "$work/$name/packaging/arch"
    PKGDEST="$output_dir" makepkg --force --noconfirm
)
package="$output_dir/nocturne-greeter-$version-$release-x86_64.pkg.tar.zst"
"$project_root/scripts/check-package.sh" "$package"
(
    cd "$output_dir"
    sha256sum "$name.tar.gz" "$(basename "$package")" > SHA256SUMS
)
printf 'Release artifacts: %s\nCommit: %s\n' "$output_dir" "$(git rev-parse HEAD)"
