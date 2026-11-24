pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "components"
import "components/theme"

ShellRoot {
    // Entry point for the isolated in-session prototype.
    id: shell

    Component.onCompleted: {
        const chosen = Quickshell.env("NOCTURNE_LANGUAGE") || "";
        Strings.language = chosen === "en" || chosen === "pt-BR" ? chosen : (Quickshell.env("LANG") || "").startsWith("pt") ? "pt-BR" : "en";
    }

    LiveSystemStatus {
        id: liveStatus
    }

    KeyboardStatus {
        id: keyboard
        active: preview.controller.authUiVisible
        layout: Quickshell.env("XKB_DEFAULT_LAYOUT") || ""
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
        powerUnavailableText: Strings.pt ? "Indisponível no preview" : "Unavailable in preview"
        windowTitle: "UMBRA · Preview"
        statusModel: liveStatus
        previewShortcutsEnabled: true
        capsLockOn: keyboard.capsLock || Quickshell.env("NOCTURNE_PREVIEW_CAPSLOCK") === "1"
        keyboardLayout: keyboard.layout
        reducedMotion: Quickshell.env("NOCTURNE_REDUCED_MOTION") === "1"
    }

    PreviewAuthenticator {
        id: previewBackend
        controller: preview.controller
        // Emulate pam_faildelay in captures (default 360 ms).
        responseDelay: Number(Quickshell.env("NOCTURNE_PREVIEW_DELAY")) || 360
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
            offset: Number(Quickshell.env("NOCTURNE_CAPTURE_OFFSET")) || 0
        }
    }
}
