pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "greeter-model.js" as Model
import "theme"

FloatingWindow {
    id: window
    property string preferredOutput: Quickshell.env("NOCTURNE_OUTPUT") || ""
    readonly property var primaryScreen: Model.selectScreen(Quickshell.screens, preferredOutput)
    onPrimaryScreenChanged: {
        if (primaryScreen)
            console.info("nocturne-display: " + primaryScreen.name + " outputs=" + Quickshell.screens.length
                         + " scale=" + primaryScreen.devicePixelRatio);
    }
    property bool windowedPreview: false
    property int requestedWidth: 1280
    property int requestedHeight: 720
    property string captureDir: ""
    property bool debugMode: false
    property string username: "user"
    property string loginUser: username
    property string hostname: "Local system"
    property string promptText: "Enter your password"
    property bool responseRequired: false
    property bool echoResponse: false
    property var statusModel: null
    property bool previewShortcutsEnabled: false
    // Keyboard state from KeyboardStatus (shell-level, reads sysfs).
    property bool capsLockOn: false
    property string keyboardLayout: ""
    property string sessionContextText: "Selected session"
    property string powerUnavailableText: "Unavailable"
    property string audioUnavailableText: "Audio unavailable"
    property string windowTitle: "UMBRA"
    property var sessionOptions: []
    property int selectedSessionIndex: -1
    property var userOptions: []
    property int selectedUserIndex: -1
    property bool powerActionsEnabled: false
    // Administrative notice (no sessions, no users, launch module missing).
    property string noticeText: ""
    signal sessionChosen(int index)
    signal userChosen(int index)
    signal powerActionRequested(string action)
    // Restart / shut down reuse the success collapse before the action runs.
    property real powerProgress: 0
    property string pendingPowerAction: ""
    readonly property real exitProgress: Math.max(greeterController.successProgress, powerProgress)
    readonly property bool powerTransitionActive: powerTransition.running || powerProgress > 0
    // `preview` plays the motion without the action being allowed (captures).
    function beginPowerTransition(action, preview) {
        if (action === "suspend") {
            // Suspend returns to this screen; no collapse.
            powerActionRequested(action);
            return;
        }
        if (powerTransitionActive || (!powerActionsEnabled && !preview))
            return;
        systemChrome.dismissMenus();
        pendingPowerAction = action;
        powerTransition.restart();
    }
    NumberAnimation {
        id: powerTransition
        target: window
        property: "powerProgress"
        from: 0
        to: 1
        duration: 950
        easing.type: Easing.InOutCubic
        onFinished: {
            window.powerActionRequested(window.pendingPowerAction);
            powerRecovery.restart();
        }
    }
    // If the machine is still here (action refused or failed), come back.
    Timer {
        id: powerRecovery
        interval: 8000
        onTriggered: powerReturn.restart()
    }
    NumberAnimation {
        id: powerReturn
        target: window
        property: "powerProgress"
        to: 0
        duration: 460
        easing.type: Easing.InOutCubic
    }
    readonly property alias controller: greeterController
    readonly property alias captureTarget: canvas
    readonly property alias authPanel: loginPanel
    readonly property alias chrome: systemChrome
    // The QQuickWindow behind this Quickshell window; the launch gate attaches
    // presentation feedback to its wl_surface.
    readonly property var presentationWindow: canvas.Window.window
    readonly property bool blackHeld: blackHold.visible
    implicitWidth: windowedPreview ? requestedWidth : (primaryScreen ? primaryScreen.width : 1920)
    implicitHeight: windowedPreview ? requestedHeight : (primaryScreen ? primaryScreen.height : 1080)
    screen: primaryScreen
    fullscreen: !windowedPreview
    color: Theme.black
    title: window.windowTitle
    property real shaderTime: 0
    // Freezes the ambient orbit; state transitions still play.
    property bool reducedMotion: false
    readonly property real uiScale: Math.max(1, Math.min(1.35, canvas.height / 900))
    readonly property real edgeMargin: Math.max(42, Math.min(canvas.width * .075, 220))
    function successPresence(start, end, progress) {
        const t = Math.max(0, Math.min(1, (progress - start) / (end - start)));
        const smooth = t * t * (3 - 2 * t);
        return 1 - smooth;
    }
    GreeterController {
        id: greeterController
    }
    Item {
        id: canvas
        layer.enabled: window.captureDir.length > 0
        width: window.captureDir ? window.requestedWidth : parent.width
        height: window.captureDir ? window.requestedHeight : parent.height
        focus: true
        readonly property bool narrow: width / height < 1.45
        readonly property real leftColumnWidth: Math.min(width * .27, 340 * window.uiScale)
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            if (window.powerTransitionActive) {
                event.accepted = true;
                return;
            }
            if (window.previewShortcutsEnabled && event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier)) {
                Qt.quit();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (!systemChrome.dismissMenus() && !greeterController.isIdle)
                    greeterController.returnToIdle();
                event.accepted = true;
                return;
            }
            if (greeterController.isIdle && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                const commandModifier = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
                // Space only wakes; other printable keys start the response.
                const initialText = Model.wakeSeedText(event.text, commandModifier !== 0);
                loginPanel.wakeWithInitialText(initialText);
                event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.black
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!systemChrome.dismissMenus() && greeterController.isIdle)
                    greeterController.wake();
                else if (greeterController.acceptsKeyboardInput)
                    loginPanel.focusInput();
            }
        }
        CosmicScene {
            id: cosmicScene
            // The rings stay whole inside the frame at every supported ratio.
            width: canvas.narrow ? canvas.width * 1.15 : Math.min(canvas.width * .74, canvas.height * 1.85)
            height: canvas.height * (canvas.narrow ? .66 : .84)
            x: canvas.width * (canvas.narrow ? .58 : canvas.width / canvas.height > 2.1 ? .65 : .64) - width / 2
            y: canvas.height * (canvas.narrow ? .33 : .51) - height / 2
            time: window.shaderTime
            authProgress: greeterController.authReveal
            wakePulse: greeterController.wakeTension
            typingPulse: greeterController.typingPulse
            failureProgress: greeterController.failureProgress
            successProgress: window.exitProgress
            authenticationTension: greeterController.authenticationTension
        }
        // Interaction runs the hero at display rate, locked to vsync. Idle
        // drops to ~30 fps: a running FrameAnimation makes the render loop
        // draw every vsync, so idle uses a plain timer instead.
        readonly property bool shaderAnimating: window.visible && !window.reducedMotion && window.exitProgress < .999
        // Rejection recoil of the orbit speed: 1 -> 0.6 -> 1.4 -> 1.
        function recoil(t) {
            if (t <= 0 || t >= 1)
                return 1;
            const ease = u => u * u * (3 - 2 * u);
            if (t < .12)
                return 1 - .4 * ease(t / .12);
            if (t < .38)
                return .6 + .8 * ease((t - .12) / .26);
            return 1.4 - .4 * ease((t - .38) / .62);
        }
        function advanceShader(seconds) {
            // While PAM works the orbit slows slightly (0.85x) but keeps moving.
            const speed = (1 - greeterController.authenticationTension * .15) * recoil(greeterController.failureProgress);
            window.shaderTime += Math.min(seconds, .05) * speed;
        }
        FrameAnimation {
            id: shaderClock
            running: canvas.shaderAnimating && !greeterController.isIdle
            onTriggered: canvas.advanceShader(frameTime)
        }
        // QML exposes no display refresh rate: measure it from vsync-paced
        // frames once at start-up (frames 10..70), then stop.
        FrameAnimation {
            id: refreshProbe
            property real refresh: 60
            property real total: 0
            property int samples: 0
            running: window.visible && samples < 60
            onTriggered: {
                if (currentFrame < 10 || frameTime <= 0 || frameTime > .05)
                    return;
                total += frameTime;
                samples += 1;
                if (samples === 60) {
                    refresh = Math.max(24, Math.min(360, 60 / total));
                    console.info("nocturne-display: measured refresh " + refresh.toFixed(1) + " Hz; idle hero every " + idleShaderClock.framesPerTick + " frames");
                }
            }
        }
        Timer {
            id: idleShaderClock
            // A whole number of display frames per tick (~30 fps), with a
            // fixed orbit step per tick: every idle frame moves the rings by
            // the same amount, so timer jitter cannot show up as uneven steps.
            readonly property real refresh: refreshProbe.refresh
            readonly property int framesPerTick: Math.max(1, Math.round(refresh / 30))
            readonly property real tickSeconds: framesPerTick / refresh
            property real wallStart: 0
            property real advanced: 0
            interval: Math.max(1, Math.round(tickSeconds * 1000))
            repeat: true
            running: canvas.shaderAnimating && greeterController.isIdle
            onRunningChanged: {
                wallStart = Date.now();
                advanced = 0;
            }
            onTriggered: {
                canvas.advanceShader(tickSeconds);
                advanced += tickSeconds;
                // Resynchronise after a stall instead of drifting from real time.
                if (Math.abs((Date.now() - wallStart) / 1000 - advanced) > tickSeconds * 3) {
                    wallStart = Date.now();
                    advanced = 0;
                }
            }
        }
        Item {
            id: editorial
            x: window.edgeMargin
            y: canvas.height * (canvas.narrow ? .585 : .35)
            width: canvas.narrow ? Math.min(canvas.width - window.edgeMargin * 2, 380 * window.uiScale) : canvas.leftColumnWidth
            height: 290 * window.uiScale
            ClockDisplay {
                width: parent.width
                height: 160 * window.uiScale
                scaleFactor: window.uiScale
                opacity: Math.max(0, 1 - greeterController.authReveal / .32) * (1 - window.exitProgress)
                visible: opacity > .001
                y: -greeterController.authReveal * 18 * window.uiScale
                scale: 1 - greeterController.authReveal * .025
                transformOrigin: Item.Left
            }
            Row {
                y: 200 * window.uiScale
                spacing: 10 * window.uiScale
                opacity: Math.max(0, 1 - greeterController.authReveal * 3) * (1 - window.exitProgress)
                visible: opacity > .001
                Text {
                    text: Strings.pressKey
                    color: Theme.placeholder
                    font.family: Theme.sans
                    font.pixelSize: 13 * window.uiScale
                }
                Image {
                    source: "../assets/icons/arrow.svg"
                    width: 16 * window.uiScale
                    height: width
                    opacity: .65
                }
            }
            AuthPanel {
                id: loginPanel
                width: parent.width
                height: parent.height
                controller: greeterController
                username: window.username
                loginUser: window.loginUser
                promptText: window.promptText
                responseRequired: window.responseRequired
                echoResponse: window.echoResponse
                scaleFactor: window.uiScale
                debugMode: window.debugMode
                capsLockOn: window.capsLockOn
                keyboardLayout: window.keyboardLayout
                previewShortcutsEnabled: window.previewShortcutsEnabled
                visible: greeterController.authUiVisible
                opacity: window.successPresence(.05, .50, window.exitProgress)
            }
        }
        SystemChrome {
            id: systemChrome
            anchors.left: parent.left
            anchors.right: parent.right
            y: parent.height - height - 28 * window.uiScale
            height: 40 * window.uiScale
            leftMargin: window.edgeMargin
            rightMargin: window.edgeMargin
            scaleFactor: window.uiScale
            hostname: window.hostname
            desktopSession: window.statusModel ? window.statusModel.desktopSession : "Local session"
            sessionContextText: window.sessionContextText
            powerUnavailableText: window.powerUnavailableText
            audioUnavailableText: window.audioUnavailableText
            networkAvailable: window.statusModel ? window.statusModel.networkAvailable : false
            online: window.statusModel ? window.statusModel.online : false
            audioAvailable: window.statusModel ? window.statusModel.audioAvailable : false
            audioMuted: window.statusModel ? window.statusModel.audioMuted : false
            volumePercent: window.statusModel ? window.statusModel.volumePercent : 0
            batteryAvailable: window.statusModel ? window.statusModel.batteryAvailable : false
            batteryPercent: window.statusModel ? window.statusModel.batteryPercent : 0
            controller: greeterController
            sessionOptions: window.sessionOptions
            selectedSessionIndex: window.selectedSessionIndex
            userOptions: window.userOptions
            selectedUserIndex: window.selectedUserIndex
            userSelectionEnabled: greeterController.isIdle
            powerActionsEnabled: window.powerActionsEnabled
            onSessionChosen: index => window.sessionChosen(index)
            onUserChosen: index => window.userChosen(index)
            onPowerActionRequested: action => window.beginPowerTransition(action, false)
            opacity: window.successPresence(.30, .78, window.exitProgress)
            enabled: greeterController.phase !== GreeterController.Success
        }
        Text {
            objectName: "noticeText"
            visible: window.noticeText.length > 0
            x: window.edgeMargin
            width: canvas.width - window.edgeMargin * 2
            y: systemChrome.y - height - 14 * window.uiScale
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: window.noticeText
            color: Theme.lilac
            opacity: window.successPresence(.05, .50, window.exitProgress)
            font.family: Theme.sans
            font.pixelSize: 12 * window.uiScale
        }
        MouseArea {
            // Swallow pointer input while the power collapse plays.
            anchors.fill: parent
            z: 999
            visible: window.powerTransitionActive
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }
        Rectangle {
            id: blackHold
            // Immutable opaque black scene after SUCCESS. Nothing from the
            // previous frame can show through while the launch gate runs.
            anchors.fill: parent
            z: 1000
            color: Theme.black
            visible: greeterController.successComplete
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
            }
        }
        Text {
            visible: window.debugMode
            x: window.edgeMargin
            y: parent.height - 16
            text: "PREVIEW  ·  " + canvas.width + " × " + canvas.height + "  ·  phase " + greeterController.phase
            color: Theme.quiet
            font.family: Theme.mono
            font.pixelSize: 10
        }
    }
    Connections {
        target: greeterController
        function onFocusInputRequested() {
            loginPanel.focusInput();
        }
        function onClearInputRequested() {
            loginPanel.clearInput();
        }
        function onPhaseChanged() {
            if (greeterController.phase === GreeterController.Authenticating || greeterController.phase === GreeterController.Success || greeterController.phase === GreeterController.Idle)
                canvas.forceActiveFocus();
            else if (greeterController.phase === GreeterController.Failure)
                loginPanel.focusInput();
        }
    }
}
