import QtQuick
import Quickshell
import "components"
import "mock"

ShellRoot {
    id: root

    Component.onCompleted: Quickshell.watchFiles = false

    MockIdentity {
        id: fixture
    }

    MockAuthenticator {
        id: mockBackend
        scenario: Quickshell.env("NOCTURNE_AUTH_SCENARIO") || "password-failure"
    }

    GreetdAuthenticator {
        id: greetdBackend
    }

    readonly property var selectedBackend: Quickshell.env("NOCTURNE_AUTH_BACKEND") === "greetd-fixture"
                                          ? greetdBackend : mockBackend

    GreeterWindow {
        id: greeter
        username: fixture.displayName
        loginUser: fixture.userId
        hostname: fixture.hostname
        statusModel: fixture
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
        previewShortcutsEnabled: false
        sessionContextText: "Selected session · mock"
        powerUnavailableText: "Unavailable in isolated harness"
        windowTitle: "UMBRA · Isolated"
    }

    AuthenticatorBridge {
        id: boundary
        controller: greeter.controller
        backend: root.selectedBackend
        selectedUser: fixture.userId
        selectedSession: fixture.sessionId
    }

    HarnessScenario {
        controller: greeter.controller
        authPanel: greeter.authPanel
        boundary: boundary
        backend: root.selectedBackend
        targetItem: greeter.captureTarget
        fastBackend: Quickshell.env("NOCTURNE_AUTH_BACKEND") === "greetd-fixture"
        selectedState: Quickshell.env("NOCTURNE_HARNESS_SCENARIO") || "none"
        captureDirectory: Quickshell.env("NOCTURNE_HARNESS_CAPTURE_DIR") || ""
    }

    HarnessMetrics {
        greeter: greeter
        metricsEnabled: Quickshell.env("NOCTURNE_HARNESS_METRICS") === "1"
    }
}
