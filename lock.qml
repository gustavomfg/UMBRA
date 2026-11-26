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
    // Screenshot taken by lock/umbra-lock just before locking (0600, in
    // XDG_RUNTIME_DIR, removed by the launcher when the lock exits).
    readonly property string backgroundPath: Quickshell.env("UMBRA_LOCK_BACKGROUND") || ""
    // Whole output layout, to crop a multi-output screenshot per screen.
    readonly property rect layoutRect: {
        const list = Quickshell.screens;
        if (list.length === 0)
            return Qt.rect(0, 0, 0, 0);
        let x0 = list[0].x, y0 = list[0].y, x1 = x0 + list[0].width, y1 = y0 + list[0].height;
        for (let i = 1; i < list.length; ++i) {
            x0 = Math.min(x0, list[i].x);
            y0 = Math.min(y0, list[i].y);
            x1 = Math.max(x1, list[i].x + list[i].width);
            y1 = Math.max(y1, list[i].y + list[i].height);
        }
        return Qt.rect(x0, y0, x1 - x0, y1 - y0);
    }

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
            id: lockSurface
            color: Theme.black
            LockSurface {
                anchors.fill: parent
                busy: root.busy
                failureCount: root.failureCount
                stats: systemStats
                backgroundSource: root.backgroundPath.length > 0 ? "file://" + root.backgroundPath : ""
                screenRect: lockSurface.screen ? Qt.rect(lockSurface.screen.x, lockSurface.screen.y, lockSurface.screen.width, lockSurface.screen.height) : Qt.rect(0, 0, width, height)
                layoutRect: root.layoutRect.width > 0 ? root.layoutRect : screenRect
                onSubmitted: password => root.submit(password)
            }
        }
    }
}
