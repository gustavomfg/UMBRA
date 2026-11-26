pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "components"
import "components/theme"

// Lock screen preview in an ordinary window: no session lock, no PAM.
// Enter "fails" after 1.2 s so the wait and the error motion can be seen.
//
//   UMBRA_LOCK_BACKGROUND=/usr/share/hypr/wall1.png quickshell --path lock-preview.qml
//
// Captures (one state per run, then quits):
//   UMBRA_LOCK_CAPTURE_DIR=dir UMBRA_LOCK_CAPTURE_STATE=idle|typing|busy|failure|caps
//   UMBRA_LOCK_WIDTH / UMBRA_LOCK_HEIGHT (default 1920x1080)
//   Run captures with QSG_RENDER_LOOP=basic: a hidden window does not
//   advance threaded animations.
ShellRoot {
    id: root

    readonly property string captureDir: Quickshell.env("UMBRA_LOCK_CAPTURE_DIR") || ""
    readonly property string captureState: Quickshell.env("UMBRA_LOCK_CAPTURE_STATE") || "idle"
    readonly property int previewWidth: Number(Quickshell.env("UMBRA_LOCK_WIDTH")) || 1920
    readonly property int previewHeight: Number(Quickshell.env("UMBRA_LOCK_HEIGHT")) || 1080
    readonly property string backgroundPath: Quickshell.env("UMBRA_LOCK_BACKGROUND") || ""
    property bool busy: false
    property int failureCount: 0

    Component.onCompleted: {
        const chosen = Quickshell.env("NOCTURNE_LANGUAGE") || "";
        Strings.language = chosen === "en" || chosen === "pt-BR" ? chosen : (Quickshell.env("LANG") || "").startsWith("pt") ? "pt-BR" : "en";
    }

    SystemStats {
        id: sampleStats
    }

    // Stand-in for an MPRIS player.
    QtObject {
        id: fakePlayer
        property string trackTitle: "Orbital Drift"
        property string trackArtist: "Umbra Ensemble"
        property url trackArtUrl: Qt.resolvedUrl("lock/umbra-lock-bg.png")
        property bool isPlaying: true
        property bool lengthSupported: true
        property real length: 245
        property real position: 96
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        function previous() {}
        function next() {}
        function togglePlaying() {
            isPlaying = !isPlaying;
        }
    }

    Timer {
        id: fakePam
        interval: 1200
        onTriggered: {
            root.busy = false;
            root.failureCount += 1;
        }
    }

    FloatingWindow {
        id: window
        implicitWidth: root.previewWidth
        implicitHeight: root.previewHeight
        color: Theme.black
        title: "UMBRA lock · preview"

        LockSurface {
            id: surface
            width: root.previewWidth
            height: root.previewHeight
            busy: root.busy
            failureCount: root.failureCount
            stats: sampleStats
            previewPlayer: fakePlayer
            // Captures always use the stand-in, never what is playing here.
            preferPreviewPlayer: root.captureDir.length > 0
            capsLockOverride: root.captureState === "caps"
            backgroundSource: root.backgroundPath.length > 0 ? "file://" + root.backgroundPath : ""
            onSubmitted: password => {
                void password;
                root.busy = true;
                fakePam.restart();
            }
        }
    }

    // Capture sequence.
    function typeSample() {
        const input = findInput(surface);
        if (input) {
            input.text = "preview";
            input.textEdited();
        }
        return input;
    }
    function findInput(item) {
        if (item.echoMode !== undefined && item.passwordCharacter !== undefined)
            return item;
        for (let i = 0; i < item.children.length; ++i) {
            const found = findInput(item.children[i]);
            if (found)
                return found;
        }
        return null;
    }
    Timer {
        id: capture
        property int step: 0
        running: root.captureDir.length > 0
        // Long enough for the first stats sample.
        interval: 3200
        repeat: true
        onTriggered: {
            const state = root.captureState;
            if (step === 0 && (state === "typing" || state === "busy" || state === "failure")) {
                const input = root.typeSample();
                if (state !== "typing" && input)
                    input.accepted();
                interval = state === "busy" ? 700 : state === "failure" ? 1200 + 260 : 400;
                step = 1;
                return;
            }
            stop();
            surface.grabToImage(result => {
                const path = root.captureDir + "/lock-" + root.previewWidth + "x" + root.previewHeight + "-" + state + ".png";
                console.info(result.saveToFile(path) ? "Captured " + path : "Capture failed " + path);
                Qt.quit();
            });
        }
    }
}
