import QtQuick

// Administratively owned greeter policy. This default ships with no user and
// no launch command, so every session launch stays blocked. A VM or package
// build replaces this file in its root-owned staging tree; nothing here is
// read from the environment or from user-writable files.
QtObject {
    readonly property string userId: ""
    readonly property string displayName: "User"
    readonly property string hostname: "Local system"
    readonly property string sessionLabel: "Selected session"
    // Fixed argv for Greetd.launch(). Never built from user or session input.
    readonly property var command: []
    readonly property var environment: []
}
