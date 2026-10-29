pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "components"

// Pre-login entrypoint run by greetd (as the `greeter` service identity) from
// a root-owned install tree. No preview shortcuts, capture, debug overlay,
// mock backend or user-session audio services are loaded here.
ShellRoot {
    id: root

    property var presentationProbe: null

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        try {
            presentationProbe = Qt.createQmlObject("import Nocturne.Presentation; PresentationProbe {}", root, "PresentationProbe");
        } catch (error) {
            // Without the probe the launch gate stays blocked.
            console.warn("nocturne-launch: presentation probe unavailable");
        }
    }

    Connections {
        target: catalog
        function onReadyChanged() {
            if (!catalog.ready)
                return;
            console.info("nocturne-greeter: " + catalog.users.length + " user(s), " + catalog.sessions.length + " session(s)");
            if (catalog.sessions.length === 0)
                console.warn("nocturne-greeter: no sessions in " + policy.sessionsFile + "; run nocturne-greeter-sessions as root");
            if (catalog.users.length === 0)
                console.warn("nocturne-greeter: no login users found");
        }
    }

    SessionLaunchPolicy {
        id: policy
    }

    GreeterCatalog {
        id: catalog
        passwdFile: policy.passwdFile
        loginDefsFile: policy.loginDefsFile
        hostnameFile: policy.hostnameFile
        sessionsFile: policy.sessionsFile
        stateFile: policy.stateFile
        fallbackHostname: policy.fallbackHostname
        sessionCommandPrefix: policy.sessionCommandPrefix
    }

    GreeterSystemStatus {
        id: systemStatus
        desktopSession: catalog.selectedSessionName
    }

    GreetdAuthenticator {
        id: greetd
        launchCommand: catalog.launchCommand
        launchEnvironment: catalog.launchEnvironment
    }

    GreeterWindow {
        id: greeter
        username: catalog.selectedUserName
        loginUser: catalog.selectedUserId
        hostname: catalog.hostname
        statusModel: systemStatus
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
        previewShortcutsEnabled: false
        sessionContextText: "Session"
        powerUnavailableText: "Unavailable"
        audioUnavailableText: "Audio unavailable before sign-in"
        windowTitle: "UMBRA"
        sessionOptions: catalog.sessions
        selectedSessionIndex: catalog.selectedSessionIndex
        userOptions: catalog.users
        selectedUserIndex: catalog.selectedUserIndex
        powerActionsEnabled: policy.powerActionsEnabled
        onSessionChosen: index => catalog.selectSession(index)
        onUserChosen: index => catalog.selectUser(index)
        onPowerActionRequested: action => root.runPowerAction(action)
        noticeText: catalog.users.length === 0 ? "No login users were found." : catalog.sessions.length === 0 ? "No sessions are available. An administrator must run nocturne-greeter-sessions." : root.presentationProbe === null || !root.presentationProbe.available ? "Sign-in is unavailable: the presentation module did not load. Rebuild nocturne-greeter." : ""
    }

    AuthenticatorBridge {
        id: boundary
        controller: greeter.controller
        backend: greetd
        selectedUser: catalog.selectedUserId
        selectedSession: catalog.selectedSessionId
    }

    SessionLaunchGate {
        controller: greeter.controller
        boundary: boundary
        window: greeter.presentationWindow
        blackHeld: greeter.blackHeld
        probe: root.presentationProbe
        onTransition: marker => {
            console.info("nocturne-launch: " + marker);
            // Remember the choice before Greetd.launch(quit=true) can exit.
            if (marker === "success-finished")
                catalog.save();
        }
        onBlocked: reason => {
            console.warn("nocturne-launch: blocked: " + reason);
            restartTimer.restart();
        }
    }

    function runPowerAction(action) {
        const command = policy.powerCommands[action];
        if (!policy.powerActionsEnabled || !command || powerProcess.running)
            return;
        console.info("nocturne-greeter: power " + action);
        powerProcess.command = command;
        powerProcess.running = true;
    }

    Process {
        id: powerProcess
    }

    // The Greetd singleton cannot be reused safely after a cancellation or a
    // blocked launch. Exit so greetd starts a fresh greeter process.
    Connections {
        target: greeter.controller
        function onPhaseChanged() {
            if (greetd.cancellationPoisoned && greeter.controller.isIdle)
                restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 400
        repeat: false
        onTriggered: {
            console.info("nocturne-launch: greeter-restart");
            boundary.cancelAttempt();
            Qt.quit();
        }
    }
}
