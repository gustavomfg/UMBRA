#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

width=1280
height=720
outputs=1
duration=0
fault=none
without_bus=0
headless=0
scenario=none
metrics=0
auth_backend=mock
auth_scenario=password-failure
auth_scenario_explicit=0

while (($#)); do
    case "$1" in
        --width|--height|--outputs|--duration|--fault|--scenario|--auth-backend|--auth-scenario)
            if (($# < 2)); then
                printf 'Missing value for %s\n' "$1" >&2
                exit 2
            fi
            case "$1" in
                --width) width="$2" ;;
                --height) height="$2" ;;
                --outputs) outputs="$2" ;;
                --duration) duration="$2" ;;
                --fault) fault="$2" ;;
                --scenario) scenario="$2" ;;
                --auth-backend) auth_backend="$2" ;;
                --auth-scenario) auth_scenario="$2"; auth_scenario_explicit=1 ;;
            esac
            shift 2
            ;;
        --mock-success) auth_scenario=password-success; auth_scenario_explicit=1; shift ;;
        --headless) headless=1; shift ;;
        --metrics) metrics=1; shift ;;
        --no-session-bus) without_bus=1; shift ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

for value in "$width" "$height" "$outputs" "$duration"; do
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        printf 'Dimensions, output count and duration must be non-negative integers.\n' >&2
        exit 2
    fi
done
if ((width < 640 || width > 5120 || height < 480 || height > 2880 || outputs < 1 || outputs > 3 || duration > 300)); then
    printf 'Requested dimensions, output count or duration are outside the safe harness range.\n' >&2
    exit 2
fi
case "$fault" in
    none|qml|shader|compositor|quickshell) ;;
    *) printf 'Unknown fault fixture: %s\n' "$fault" >&2; exit 2 ;;
esac
case "$scenario" in
    none|idle|auth|auth-hold|failure|retry|success|cancel-during-prompt|late-response-after-cancel) ;;
    *) printf 'Unknown state capture scenario: %s\n' "$scenario" >&2; exit 2 ;;
esac
case "$auth_backend" in
    mock|greetd-fixture) ;;
    *) printf 'Unknown authentication backend: %s\n' "$auth_backend" >&2; exit 2 ;;
esac
case "$auth_scenario" in
    password-success|password-failure|multi-prompt|visible-prompt|informational-message|error-message|cancel-during-prompt|late-response-after-cancel) ;;
    *) printf 'Unknown authentication scenario: %s\n' "$auth_scenario" >&2; exit 2 ;;
esac
if ((auth_scenario_explicit == 0)); then
    if [[ "$scenario" == success ]]; then
        auth_scenario=password-success
    elif [[ "$scenario" == failure ]]; then
        auth_scenario=password-failure
    fi
fi
if [[ "$scenario" != none && "$duration" == 0 ]]; then
    duration=12
fi

compositor=kwin_wayland
if ((headless)); then
    compositor=cage
    if ((width != 1280 || height != 720)); then
        printf 'The Cage headless fixture uses 1280x720 outputs. Use KWin for custom dimensions.\n' >&2
        exit 2
    fi
fi
for program in "$compositor" quickshell setsid rg; do
    if ! command -v "$program" >/dev/null 2>&1; then
        printf 'Required program is missing: %s\n' "$program" >&2
        exit 127
    fi
done
if [[ "$auth_backend" == greetd-fixture ]] && ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required for the local greetd protocol fixture.\n' >&2
    exit 127
fi
if ((without_bus == 0)) && ! command -v dbus-daemon >/dev/null 2>&1; then
    printf 'dbus-daemon is required for an isolated session bus.\n' >&2
    exit 127
fi
host_socket='(headless)'
if ((headless == 0)); then
    if [[ -z "${XDG_RUNTIME_DIR:-}" || -z "${WAYLAND_DISPLAY:-}" ]]; then
        printf 'Run the interactive harness inside a Wayland desktop, or use --headless.\n' >&2
        exit 2
    fi
    if [[ "$WAYLAND_DISPLAY" == /* ]]; then
        host_socket="$WAYLAND_DISPLAY"
    else
        host_socket="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    fi
    if [[ ! -S "$host_socket" ]]; then
        printf 'Host Wayland socket is unavailable.\n' >&2
        exit 2
    fi
fi


umask 077
runtime_root="$(mktemp -d "${TMPDIR:-/tmp}/nocturne-isolated.XXXXXX")"
log_parent="$project_root/logs/isolated-greeter"
mkdir -p "$log_parent"
log_dir="$(mktemp -d "$log_parent/run.XXXXXX")"
compositor_pid=''
quickshell_pid=''
bus_pid=''
greetd_fixture_pid=''

stop_group() {
    local group_pid="$1"
    if [[ -n "$group_pid" ]] && kill -0 "$group_pid" 2>/dev/null; then
        kill -TERM -- "-$group_pid" 2>/dev/null || true
        wait "$group_pid" 2>/dev/null || true
    fi
}
check_runtime_warnings() {
    if rg -q 'Failed to find shader|shader preparation failed|Failed to load configuration|Harness state mismatch|Harness capture failed' "$log_dir/quickshell.log"; then
        printf 'QML or shader startup failure detected in %s/quickshell.log\n' "$log_dir" >&2
        return 1
    fi
}
check_fixture_launch_blocked() {
    if [[ "$auth_backend" != greetd-fixture ]]; then
        return 0
    fi
    stop_group "$greetd_fixture_pid"
    greetd_fixture_pid=''
    if [[ ! -f "$greetd_fixture_status" ]]; then
        printf 'Protocol fixture status is missing; inspect %s/greetd-fixture.log\n' "$log_dir" >&2
        return 1
    fi
    if rg -q --fixed-strings '123456' "$log_dir/quickshell.log"; then
        printf 'An authentication response canary appeared in %s/quickshell.log\n' "$log_dir" >&2
        return 1
    fi
    python3 - "$greetd_fixture_status" "$scenario" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as status_file:
    status = json.load(status_file)
if sys.argv[2] == "retry" and status.get("create_session", 0) < 2:
    raise SystemExit("The Greetd API did not begin the retry attempt.")
if status.get("start_session", 0) != 0:
    raise SystemExit("The 0.7 adapter attempted start_session.")
print("Fixture requests: create_session={create_session}, cancel_session={cancel_session}, start_session={start_session}".format(**status))
PY
}
cleanup() {
    trap - EXIT
    stop_group "$quickshell_pid"
    stop_group "$greetd_fixture_pid"
    stop_group "$compositor_pid"
    stop_group "$bus_pid"
    if [[ "$runtime_root" == "${TMPDIR:-/tmp}"/nocturne-isolated.* && -d "$runtime_root" ]]; then
        rm -r -- "$runtime_root"
    fi
    printf 'Logs retained at %s\n' "$log_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

NOCTURNE_STAGING_PARENT="$runtime_root/staging" "$project_root/scripts/stage-isolated-greeter.sh" >/dev/null

mkdir -m 700 "$runtime_root/runtime" "$runtime_root/home" "$runtime_root/config" "$runtime_root/cache" "$runtime_root/data" "$runtime_root/state" "$runtime_root/stage"

if ((without_bus == 0)); then
    private_bus_socket="$runtime_root/runtime/bus"
    setsid dbus-daemon --session --nofork --nopidfile \
        --address="unix:path=$private_bus_socket" \
        >"$log_dir/dbus.log" 2>&1 &
    bus_pid=$!
    for ((attempt = 0; attempt < 50; attempt++)); do
        if [[ -S "$private_bus_socket" ]]; then
            break
        fi
        if ! kill -0 "$bus_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    if [[ ! -S "$private_bus_socket" ]]; then
        printf 'Private session bus did not create its socket; inspect %s/dbus.log\n' "$log_dir" >&2
        exit 1
    fi
fi

if [[ "$auth_backend" == greetd-fixture ]]; then
    greetd_fixture_socket="$runtime_root/runtime/greetd.sock"
    greetd_fixture_status="$runtime_root/runtime/greetd-fixture-status.json"
    setsid env -i PATH=/usr/bin:/bin \
        python3 "$project_root/harness/protocol/greetd-fixture.py" \
        --socket "$greetd_fixture_socket" --status-file "$greetd_fixture_status" \
        --scenario "$auth_scenario" \
        >"$log_dir/greetd-fixture.log" 2>&1 &
    greetd_fixture_pid=$!
    for ((attempt = 0; attempt < 50; attempt++)); do
        if [[ -S "$greetd_fixture_socket" ]]; then
            break
        fi
        if ! kill -0 "$greetd_fixture_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    if [[ ! -S "$greetd_fixture_socket" ]]; then
        printf 'Local greetd protocol fixture did not create its socket; inspect %s/greetd-fixture.log\n' "$log_dir" >&2
        exit 1
    fi
fi

cp -a -- "$runtime_root/staging/nocturne-greeter/." "$runtime_root/stage/"
(
    cd "$runtime_root/stage"
    sha256sum -c SHA256SUMS >/dev/null
)
mkdir -m 700 "$runtime_root/stage/mock"
cp -- "$project_root/harness/shell.qml" "$runtime_root/stage/shell.qml"
cp -- "$project_root/harness/mock/MockAuthenticator.qml" "$project_root/harness/mock/MockIdentity.qml" "$project_root/harness/mock/HarnessScenario.qml" "$project_root/harness/mock/HarnessMetrics.qml" "$runtime_root/stage/mock/"

if [[ "$fault" == qml ]]; then
    printf 'This is intentionally invalid QML\n' > "$runtime_root/stage/shell.qml"
elif [[ "$fault" == shader ]]; then
    rm -- "$runtime_root/stage/shaders/pulse.frag.qsb"
fi

locale_name="${LANG:-C.UTF-8}"
base_env=(
    "HOME=$runtime_root/home"
    USER=nocturne-harness
    LOGNAME=nocturne-harness
    PATH=/usr/bin:/bin
    "LANG=$locale_name"
    "XDG_RUNTIME_DIR=$runtime_root/runtime"
    "XDG_CONFIG_HOME=$runtime_root/config"
    "XDG_CACHE_HOME=$runtime_root/cache"
    "XDG_DATA_HOME=$runtime_root/data"
    "XDG_STATE_HOME=$runtime_root/state"
    XDG_DATA_DIRS=/usr/local/share:/usr/share
    XDG_CONFIG_DIRS=/etc/xdg
    XDG_SESSION_TYPE=wayland
    QT_QPA_PLATFORM=wayland
    QSG_RENDER_LOOP=threaded
    QSG_INFO=1
    QS_DISABLE_FILE_WATCHER=1
    QS_DISABLE_CRASH_HANDLER=1
)
if ((without_bus == 0)); then
    base_env+=("DBUS_SESSION_BUS_ADDRESS=unix:path=$private_bus_socket")
fi

nested_socket_name=wayland-umbra
if ((headless)); then nested_socket_name=wayland-0; fi
nested_socket="$runtime_root/runtime/$nested_socket_name"
printf 'Host socket: %s\nNested socket: %s\n' "$host_socket" "$nested_socket"
printf 'Isolated runtime: %s\nLogs: %s\n' "$runtime_root" "$log_dir"
printf 'Authentication backend: %s; scenario: %s; fault fixture: %s; state capture: %s; session bus passed: %s\n' "$auth_backend" "$auth_scenario" "$fault" "$scenario" "$((1 - without_bus))"
if [[ "$auth_backend" == greetd-fixture ]]; then
    printf 'GREETD_SOCK points to a local protocol fixture. It does not run greetd, PAM, or a session command.\n'
else
    printf 'This harness never calls PAM, greetd, PLM, or a real session launcher.\n'
fi

start_ms="$(date +%s%3N)"
if ((headless)); then
    setsid env -i "${base_env[@]}" WLR_BACKENDS=headless WLR_RENDERER=pixman \
        "WLR_HEADLESS_OUTPUTS=$outputs" WLR_LIBINPUT_NO_DEVICES=1 \
        cage -- /usr/bin/sleep infinity >"$log_dir/compositor.log" 2>&1 &
else
    setsid env -i "${base_env[@]}" kwin_wayland \
        --wayland-display "$host_socket" \
        --socket "$nested_socket_name" \
        --width "$width" --height "$height" --output-count "$outputs" \
        --no-lockscreen --no-global-shortcuts --no-kactivities \
        >"$log_dir/compositor.log" 2>&1 &
fi
compositor_pid=$!

for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -S "$nested_socket" ]]; then
        break
    fi
    if ! kill -0 "$compositor_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
if [[ ! -S "$nested_socket" ]]; then
    printf 'Nested compositor did not create its socket; inspect %s/compositor.log\n' "$log_dir" >&2
    exit 1
fi
socket_ms="$(date +%s%3N)"
printf 'Nested Wayland socket ready after %s ms.\n' "$((socket_ms - start_ms))"

quickshell_command=quickshell
if [[ "$fault" == quickshell ]]; then
    quickshell_command="$runtime_root/no-such-quickshell"
fi
auth_env=(
    "NOCTURNE_AUTH_BACKEND=$auth_backend"
    "NOCTURNE_AUTH_SCENARIO=$auth_scenario"
    "NOCTURNE_HARNESS_SCENARIO=$scenario"
    "NOCTURNE_HARNESS_METRICS=$metrics"
    "NOCTURNE_HARNESS_CAPTURE_DIR=$log_dir"
)
if [[ "$auth_backend" == greetd-fixture ]]; then
    auth_env+=("GREETD_SOCK=$greetd_fixture_socket")
fi
setsid env -i "${base_env[@]}" "WAYLAND_DISPLAY=$nested_socket_name" "${auth_env[@]}" \
    "$quickshell_command" \
    --no-color --path "$runtime_root/stage" \
    >"$log_dir/quickshell.log" 2>&1 &
quickshell_pid=$!

sleep 1
if ! kill -0 "$quickshell_pid" 2>/dev/null; then
    printf 'Quickshell exited during startup; inspect %s/quickshell.log\n' "$log_dir" >&2
    exit 1
fi
if ! kill -0 "$compositor_pid" 2>/dev/null; then
    printf 'Nested compositor exited during startup; inspect %s/compositor.log\n' "$log_dir" >&2
    exit 1
fi
ready_ms="$(date +%s%3N)"
printf 'Both processes still running after %s ms. Compositor: %s; headless: %s.\n' "$((ready_ms - start_ms))" "$compositor" "$headless"
printf 'Close with Ctrl+C in this terminal.\n'

deadline=$((SECONDS + duration))
compositor_fault_at=$((SECONDS + 2))
compositor_fault_sent=0
while kill -0 "$quickshell_pid" 2>/dev/null; do
    if [[ "$fault" == compositor && "$compositor_fault_sent" == 0 ]] && ((SECONDS >= compositor_fault_at)); then
        compositor_fault_sent=1
        printf 'Injecting a controlled stop of the isolated compositor process.\n'
        kill -TERM -- "-$compositor_pid" 2>/dev/null || true
    fi
    if ! kill -0 "$compositor_pid" 2>/dev/null; then
        printf 'Nested compositor exited while Quickshell was running.\n' >&2
        exit 1
    fi
    if ((duration > 0 && SECONDS >= deadline)); then
        if [[ "$scenario" != none && "$scenario" != auth-hold ]]; then
            printf 'Timed out waiting for the harness state capture.\n' >&2
            exit 1
        fi
        check_runtime_warnings
        exit 0
    fi
    sleep 0.25
done

if ! kill -0 "$compositor_pid" 2>/dev/null; then
    printf 'Nested compositor exited; inspect %s/compositor.log and %s/quickshell.log\n' "$log_dir" "$log_dir" >&2
    exit 1
fi
if wait "$quickshell_pid"; then
    printf 'Quickshell exited normally.\n'
    check_runtime_warnings
    check_fixture_launch_blocked
else
    printf 'Quickshell exited with an error; inspect %s/quickshell.log\n' "$log_dir" >&2
    exit 1
fi
