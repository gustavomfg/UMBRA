import QtQuick

// Fixture policy for the launch-gate end-to-end test. The protocol fixture
// acknowledges this argv without executing it.
QtObject {
    readonly property string userId: "launch-fixture"
    readonly property string displayName: "Launch Fixture"
    readonly property string hostname: "Fixture host"
    readonly property string sessionLabel: "Fixture session"
    readonly property var command: ["/usr/bin/false", "nocturne-fixture-session"]
    readonly property var environment: ["XDG_SESSION_TYPE=wayland"]
}
