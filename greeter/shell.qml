pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "components"

// Pre-login entrypoint run by greetd (as the `greeter` service identity) from
// a root-owned staging tree. No preview shortcuts, capture, debug overlay,
// mock backend or live user services are loaded here.
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

    SessionLaunchPolicy {
        id: policy
    }

    // Pre-login has no user services: only the fixed session label is shown.
    QtObject {
        id: staticStatus
        readonly property string desktopSession: policy.sessionLabel
        readonly property bool networkAvailable: false
        readonly property bool online: false
        readonly property bool audioAvailable: false
        readonly property bool audioMuted: false
        readonly property int volumePercent: 0
        readonly property bool batteryAvailable: false
        readonly property int batteryPercent: 0
    }

    GreetdAuthenticator {
        id: greetd
        launchCommand: policy.command
        launchEnvironment: policy.environment
    }

    GreeterWindow {
        id: greeter
        username: policy.displayName
        loginUser: policy.userId
        hostname: policy.hostname
        statusModel: staticStatus
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
        previewShortcutsEnabled: false
        sessionContextText: policy.sessionLabel
        powerUnavailableText: "Unavailable"
        windowTitle: "Nocturne Umbra"
    }

    AuthenticatorBridge {
        id: boundary
        controller: greeter.controller
        backend: greetd
        selectedUser: policy.userId
        selectedSession: policy.sessionLabel
    }

    SessionLaunchGate {
        controller: greeter.controller
        boundary: boundary
        window: greeter.presentationWindow
        blackHeld: greeter.blackHeld
        probe: root.presentationProbe
        onTransition: marker => console.info("nocturne-launch: " + marker)
        onBlocked: reason => {
            console.warn("nocturne-launch: blocked: " + reason);
            restartTimer.restart();
        }
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
