#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$project_root/scripts/run-isolated-greeter.sh"

run_scenario() {
    local auth_scenario="$1"
    local capture_scenario="$2"
    printf '\nTesting Quickshell Greetd API fixture: %s\n' "$auth_scenario"
    "$runner" --headless \
        --auth-backend greetd-fixture \
        --auth-scenario "$auth_scenario" \
        --scenario "$capture_scenario"
}

run_scenario password-success success
run_scenario password-failure failure
run_scenario password-failure retry
run_scenario multi-prompt success
run_scenario visible-prompt success
run_scenario informational-message success
run_scenario error-message success
run_scenario cancel-during-prompt cancel-during-prompt
run_scenario late-response-after-cancel late-response-after-cancel

printf '\nAll Quickshell API / local IPC fixture scenarios passed. The fixture used no PAM and rejected every session launch.\n'
