pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "components"

ShellRoot {
    // Entry point for the isolated in-session prototype.
    id: shell

    LiveSystemStatus {
        id: liveStatus
    }

    GreeterWindow {
        id: preview
        windowedPreview: Quickshell.env("NOCTURNE_WINDOWED") === "1"
        requestedWidth: Number(Quickshell.env("NOCTURNE_WIDTH")) || 1280
        requestedHeight: Number(Quickshell.env("NOCTURNE_HEIGHT")) || 720
        captureDir: Quickshell.env("NOCTURNE_CAPTURE_DIR") || ""
        debugMode: Quickshell.env("NOCTURNE_DEBUG") === "1"
        username: Quickshell.env("NOCTURNE_USER_NAME") || Quickshell.env("USER") || "user"
        hostname: Quickshell.env("HOSTNAME") || Quickshell.env("HOST") || "Local system"
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
        sessionContextText: "Current session · preview"
        powerUnavailableText: "Unavailable in preview"
        windowTitle: "UMBRA · Preview"
        statusModel: liveStatus
        previewShortcutsEnabled: true
    }

    PreviewAuthenticator {
        id: previewBackend
        controller: preview.controller
    }

    AuthenticatorBridge {
        id: boundary
        controller: preview.controller
        backend: previewBackend
        selectedUser: preview.loginUser
        selectedSession: "preview-session"
    }

    Loader {
        active: preview.captureDir.length > 0
        sourceComponent: PreviewCapture {
            targetItem: preview.captureTarget
            controller: preview.controller
            authPanel: preview.authPanel
            chrome: preview.chrome
            outputDirectory: preview.captureDir
            selectedState: Quickshell.env("NOCTURNE_CAPTURE_STATE") || "idle"
        }
    }
}
