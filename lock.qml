pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "components"
import "components/theme"

// UMBRA lock screen: ext-session-lock-v1 through Quickshell, the greeter's
// planet shader, PAM for the password and an MPRIS card for the player.
//
// Run:  quickshell --path <repo>/lock.qml
// If it ever hangs the screen stays locked (that is the protocol's point):
// switch to a TTY (Ctrl+Alt+F3), log in and run `pkill quickshell`.
ShellRoot {
    id: root

    property string pendingPassword: ""
    property bool busy: false
    property bool failed: false
    // Bumped on every rejected password so surfaces can replay the wave.
    property int failureCount: 0

    Component.onCompleted: {
        const chosen = Quickshell.env("NOCTURNE_LANGUAGE") || "";
        Strings.language = chosen === "en" || chosen === "pt-BR" ? chosen : (Quickshell.env("LANG") || "").startsWith("pt") ? "pt-BR" : "en";
    }

    SystemStats {
        id: systemStats
        active: lock.locked
    }

    function submit(password) {
        if (busy || password.length === 0)
            return;
        failed = false;
        pendingPassword = password;
        busy = true;
        if (!pam.start()) {
            busy = false;
            pendingPassword = "";
            fail();
        }
    }

    function fail() {
        failed = true;
        failureCount += 1;
    }

    PamContext {
        id: pam
        // Same stack hyprlock uses ("login"); the user is the current one.
        onResponseRequiredChanged: {
            if (responseRequired && root.pendingPassword.length > 0) {
                const answer = root.pendingPassword;
                root.pendingPassword = "";
                respond(answer);
            }
        }
        onCompleted: result => {
            root.busy = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                lock.locked = false;
                quitTimer.start();
            } else {
                root.fail();
            }
        }
    }

    // Let the unlock request reach the compositor before the process exits.
    Timer {
        id: quitTimer
        interval: 250
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            color: Theme.black
            LockSurface {
                anchors.fill: parent
                busy: root.busy
                failed: root.failed
                failureCount: root.failureCount
                stats: systemStats
                onSubmitted: password => root.submit(password)
            }
        }
    }
}
