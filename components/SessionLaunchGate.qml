import QtQuick

// Holds session launch until the opaque black SUCCESS scene was presented.
//
// Launch is requested only when all of these hold for one generation:
//   1. the SUCCESS timeline finished and the black hold is visible;
//   2. Qt swapped `requiredBlackFrames` frames of that black scene;
//   3. a PresentationProbe `presented` event arrived for a feedback object
//      armed on this exact window after (2);
//   4. the boundary still reports the same ready generation and no launch.
// A missing probe, `discarded`, a probe failure or the timeout block launch.
// The timeout never grants permission.
Item {
    id: root
    visible: false

    property var controller
    property var boundary
    property var window
    property bool blackHeld: false
    // Nocturne.Presentation PresentationProbe, or null when unavailable.
    property var probe: null
    property int requiredBlackFrames: 2
    property int presentationTimeout: 3000

    // gateState: idle | holding | armed | launching | blocked
    property string gateState: "idle"
    property int gateGeneration: 0
    property int blackFrames: 0
    property int armedToken: 0
    property string blockReason: ""

    signal transition(string marker)
    signal blocked(string reason)

    function reset() {
        presentationTimer.stop();
        if (armedToken !== 0 && probe)
            probe.disarm();
        gateState = "idle";
        gateGeneration = 0;
        blackFrames = 0;
        armedToken = 0;
        blockReason = "";
    }

    function block(reason) {
        if (gateState === "blocked" || gateState === "idle")
            return;
        presentationTimer.stop();
        if (armedToken !== 0 && probe)
            probe.disarm();
        armedToken = 0;
        gateState = "blocked";
        blockReason = reason;
        transition("launch-blocked");
        blocked(reason);
    }

    function stillValid() {
        return controller && boundary
            && controller.phase === GreeterController.Success
            && controller.successComplete && root.blackHeld
            && boundary.attemptActive && !boundary.launchRequested
            && boundary.readyGeneration === gateGeneration && gateGeneration > 0;
    }

    function begin() {
        if (gateState !== "idle")
            return;
        if (!boundary || boundary.readyGeneration <= 0) {
            gateState = "holding";
            block("Authentication is not ready to launch");
            return;
        }
        gateGeneration = boundary.readyGeneration;
        blackFrames = 0;
        gateState = "holding";
        transition("success-finished");
        if (window && typeof window.update === "function")
            window.update();
    }

    function arm() {
        if (!stillValid()) {
            block("Launch state changed before presentation");
            return;
        }
        if (!probe || !probe.available) {
            block("Presentation feedback unavailable" + (probe && probe.unavailableReason ? ": " + probe.unavailableReason : ""));
            return;
        }
        const token = probe.arm(window);
        if (!token) {
            block("Presentation feedback could not be armed on the greeter surface");
            return;
        }
        armedToken = token;
        gateState = "armed";
        transition("black-commit-armed");
        presentationTimer.restart();
    }

    function onProbePresented(token) {
        if (gateState !== "armed" || token !== armedToken)
            return;
        presentationTimer.stop();
        armedToken = 0;
        if (!stillValid()) {
            block("Launch state changed before presentation");
            return;
        }
        transition("black-commit-presented");
        gateState = "launching";
        if (!boundary.requestSessionLaunch(gateGeneration)) {
            block("Session launch refused by backend");
            return;
        }
        transition("launch-requested");
    }

    Connections {
        target: root.controller
        function onSuccessCompleteChanged() {
            if (root.controller.successComplete)
                Qt.callLater(root.begin);
            else
                root.reset();
        }
        function onPhaseChanged() {
            if (root.controller.phase !== GreeterController.Success) {
                if (root.gateState === "holding" || root.gateState === "armed")
                    root.block("Greeter left SUCCESS before launch");
                root.reset();
            }
        }
    }

    Connections {
        target: root.window
        ignoreUnknownSignals: true
        function onFrameSwapped() {
            if (root.gateState !== "holding" || !root.blackHeld)
                return;
            root.blackFrames += 1;
            if (root.blackFrames >= root.requiredBlackFrames)
                root.arm();
            else
                root.window.update();
        }
    }

    Connections {
        target: root.probe
        ignoreUnknownSignals: true
        function onPresented(token, flags) {
            root.onProbePresented(token);
        }
        function onDiscarded(token) {
            if (token === root.armedToken)
                root.block("Black frame was discarded by the compositor");
        }
        function onFailed(token, reason) {
            if (token === root.armedToken)
                root.block("Presentation feedback failed: " + reason);
        }
    }

    Timer {
        id: presentationTimer
        interval: root.presentationTimeout
        repeat: false
        onTriggered: root.block("Timed out waiting for black-frame presentation")
    }
}
