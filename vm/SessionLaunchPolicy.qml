import QtQuick

// VM-only policy for the disposable 0.8 guest. scripts/stage-vm-greeter.sh
// installs it in place of the empty default. One fixed test session: a real
// user Wayland compositor (cage -s keeps VT switching for the recovery
// console) with a terminal; no session selection and no
// command built from user, label or desktop-file input.
QtObject {
    readonly property string userId: "nocturne-test"
    readonly property string displayName: "Nocturne Test"
    readonly property string hostname: "nocturne-vm"
    readonly property string sessionLabel: "Cage · foot (test)"
    readonly property var command: ["/usr/bin/cage", "-s", "--", "/usr/bin/foot", "-e", "/usr/bin/sh"]
    readonly property var environment: ["XDG_SESSION_TYPE=wayland"]
}
