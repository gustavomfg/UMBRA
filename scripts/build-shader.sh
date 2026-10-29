#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
qsb_bin="$(command -v qsb || true)"

if [[ -z "$qsb_bin" && -x /usr/lib/qt6/bin/qsb ]]; then
    qsb_bin=/usr/lib/qt6/bin/qsb
fi

if [[ -z "$qsb_bin" ]]; then
    printf 'Qt Shader Baker (qsb) is required to rebuild the shader.\n' >&2
    exit 127
fi

"$qsb_bin" --qt6 "$project_root/shaders/pulse.frag" \
    -o "${NOCTURNE_SHADER_OUTPUT:-$project_root/shaders/pulse.frag.qsb}"
