import QtQuick
import Quickshell.Io
import "greeter-model.js" as Model

// Pre-login users and sessions. Reads only the administratively owned files
// named by SessionLaunchPolicy, plus the greeter's own last-selection state.
Item {
    id: root
    visible: false

    property string passwdFile: "/etc/passwd"
    property string loginDefsFile: "/etc/login.defs"
    property string hostnameFile: "/etc/hostname"
    property string sessionsFile: ""
    property string stateFile: ""
    property string fallbackHostname: "Local system"

    property var users: []
    property var sessions: []
    property string hostname: fallbackHostname
    property int selectedUserIndex: -1
    property int selectedSessionIndex: -1
    property bool ready: false

    readonly property var selectedUser: selectedUserIndex >= 0 && selectedUserIndex < users.length ? users[selectedUserIndex] : null
    readonly property var selectedSession: selectedSessionIndex >= 0 && selectedSessionIndex < sessions.length ? sessions[selectedSessionIndex] : null
    readonly property string selectedUserId: selectedUser ? selectedUser.id : ""
    readonly property string selectedUserName: selectedUser ? selectedUser.displayName : "No user available"
    readonly property string selectedSessionId: selectedSession ? selectedSession.id : ""
    readonly property string selectedSessionName: selectedSession ? selectedSession.name : "No session available"
    readonly property var launchCommand: selectedSession ? selectedSession.command : []
    readonly property var launchEnvironment: Model.sessionEnvironment(selectedSession)

    function readText(view) {
        if (!view.path || view.path.length === 0)
            return "";
        try {
            // blockLoading makes text() read synchronously; a missing file is "".
            return view.text() || "";
        } catch (error) {
            return "";
        }
    }

    function load() {
        const range = Model.parseLoginDefs(readText(loginDefsView));
        users = Model.parsePasswd(readText(passwdView), range.uidMin, range.uidMax);
        sessions = Model.parseSessionCatalog(readText(sessionsView));
        hostname = Model.firstLine(readText(hostnameView)) || fallbackHostname;
        const state = stateFile.length > 0 ? Model.parseState(readText(stateView)) : { user: "", session: "" };
        selectedUserIndex = Model.indexOfId(users, state.user);
        selectedSessionIndex = Model.indexOfId(sessions, state.session);
        ready = true;
    }

    function selectUser(index) {
        if (index < 0 || index >= users.length || index === selectedUserIndex)
            return;
        selectedUserIndex = index;
        save();
    }

    function selectSession(index) {
        if (index < 0 || index >= sessions.length || index === selectedSessionIndex)
            return;
        selectedSessionIndex = index;
        save();
    }

    // Persist the selection; waits so a following Greetd.launch(quit=true)
    // cannot exit the process before the write lands.
    function save() {
        if (stateFile.length === 0)
            return false;
        stateView.setText(Model.serializeState(selectedUserId, selectedSessionId));
        return stateView.waitForJob();
    }

    FileView {
        id: passwdView
        path: root.passwdFile
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: loginDefsView
        path: root.loginDefsFile
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: hostnameView
        path: root.hostnameFile
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: sessionsView
        path: root.sessionsFile
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Component.onCompleted: load()
}
