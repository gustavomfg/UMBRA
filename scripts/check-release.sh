#!/usr/bin/env bash
# Local/CI checks only. No installation, service changes or real login.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
./scripts/build-presentation-probe.sh
NOCTURNE_SHADER_OUTPUT="$project_root/build/pulse.frag.qsb" ./scripts/build-shader.sh
python3 -I -m unittest discover -s tests -p 'test_*.py'
./scripts/test-greeter.sh
./scripts/lint-qml.sh
./scripts/test-greetd-adapter.sh
./scripts/test-greetd-protocol.sh
./scripts/test-launch-gate-e2e.sh
./scripts/test-launch-gate-e2e.sh --no-probe
./scripts/test-upgrade-recovery.sh
./scripts/run-isolated-greeter.sh --headless --outputs 2 --scenario auth
./scripts/compatibility-report.py > build/compatibility.json
