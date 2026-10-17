import QtQuick

// Administratively owned greeter policy, installed root-owned with the
// greeter. Users come from /etc/passwd within the login.defs UID range;
// sessions come only from the catalog that nocturne-greeter-sessions (root)
// builds from /usr/share/wayland-sessions. Launch argv is never built from
// user input, session labels or desktop files at runtime.
QtObject {
    readonly property string passwdFile: "/etc/passwd"
    readonly property string loginDefsFile: "/etc/login.defs"
    readonly property string hostnameFile: "/etc/hostname"
    readonly property string sessionsFile: "/var/lib/nocturne-greeter/sessions.json"
    // Writable only by the greeter account (systemd-tmpfiles).
    readonly property string stateFile: "/var/lib/nocturne-greeter/state/last-selection.json"
    readonly property string fallbackHostname: "Local system"
    // logind allows the active seat session to suspend, reboot and power off.
    readonly property bool powerActionsEnabled: true
    readonly property var powerCommands: ({
            "suspend": ["/usr/bin/systemctl", "suspend"],
            "reboot": ["/usr/bin/systemctl", "reboot"],
            "poweroff": ["/usr/bin/systemctl", "poweroff"]
        })
}
