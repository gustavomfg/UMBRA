#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
qml_linter="$(command -v qmllint || true)"
if [[ -z "$qml_linter" && -x /usr/lib/qt6/bin/qmllint ]]; then
    qml_linter=/usr/lib/qt6/bin/qmllint
fi
if [[ -z "$qml_linter" ]]; then
    printf 'Qt qmllint is required.\n' >&2
    exit 127
fi

cd "$project_root"
QML_IMPORT_PATH=/usr/lib/qt6/qml "$qml_linter" -E --ignore-settings \
    shell.qml components/*.qml tests/*.qml

# The harness entrypoint imports ./components and ./mock from the temporary
# runtime layout, so lint it in that layout rather than its source directory.
lint_root="$(mktemp -d "${TMPDIR:-/tmp}/nocturne-qml-lint.XXXXXX")"
trap 'rm -r -- "$lint_root"' EXIT
NOCTURNE_STAGING_PARENT="$lint_root/staging" "$project_root/scripts/stage-isolated-greeter.sh" >/dev/null
cp -a -- "$lint_root/staging/nocturne-greeter/." "$lint_root/"
# The staged tree's own shell.qml is the pre-login entrypoint; lint it first.
QML_IMPORT_PATH=/usr/lib/qt6/qml "$qml_linter" -E --ignore-settings "$lint_root/shell.qml"
mkdir "$lint_root/mock"
cp -- "$project_root/harness/shell.qml" "$lint_root/shell.qml"
cp -- "$project_root/harness/mock/"*.qml "$lint_root/mock/"
QML_IMPORT_PATH=/usr/lib/qt6/qml "$qml_linter" -E --ignore-settings \
    "$lint_root/shell.qml" "$lint_root/components/"*.qml "$lint_root/mock/"*.qml
