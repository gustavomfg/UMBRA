import QtQuick

// Fixture policy for the launch-gate end-to-end test. @RUN@ is replaced with
// the temporary run directory; the protocol fixture acknowledges the session
// argv without executing it.
QtObject {
    readonly property string passwdFile: "@RUN@/fixture/passwd"
    readonly property string loginDefsFile: "@RUN@/fixture/login.defs"
    readonly property string hostnameFile: "@RUN@/fixture/hostname"
    readonly property string sessionsFile: "@RUN@/fixture/sessions.json"
    readonly property string stateFile: "@RUN@/fixture/state.json"
    readonly property string fallbackHostname: "Fixture host"
    readonly property bool powerActionsEnabled: false
    readonly property var powerCommands: ({})
}
