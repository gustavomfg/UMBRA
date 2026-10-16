pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

FloatingWindow {
    id: window
    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
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
    property string sessionContextText: "Selected session"
    property string powerUnavailableText: "Unavailable"
    property string windowTitle: "Nocturne Umbra"
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
    color: "#000000"
    title: window.windowTitle
    property real shaderTime: 0
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
                const initialText = !commandModifier && event.text.length > 0 && event.text.charCodeAt(0) >= 32 ? event.text : "";
                loginPanel.wakeWithInitialText(initialText);
                event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#000000"
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
            width: canvas.narrow ? canvas.width * 1.15 : Math.min(canvas.width * .79, canvas.height * 1.85)
            height: canvas.height * (canvas.narrow ? .66 : .84)
            x: canvas.width * (canvas.narrow ? .58 : canvas.width / canvas.height > 2.1 ? .65 : .66) - width / 2
            y: canvas.height * (canvas.narrow ? .35 : .51) - height / 2
            time: window.shaderTime
            authProgress: greeterController.authReveal
            wakePulse: greeterController.wakeTension
            typingPulse: greeterController.typingPulse
            failureProgress: greeterController.failureProgress
            successProgress: greeterController.successProgress
            authenticationTension: greeterController.authenticationTension
        }
        ElapsedTimer {
            id: shaderElapsed
            Component.onCompleted: restart()
        }
        Timer {
            id: shaderClock
            // Qt Quick Timer intervals are integer milliseconds; elapsed time below keeps motion speed independent of timer jitter.
            interval: 16
            repeat: true
            running: window.visible && greeterController.successProgress < .999
            onTriggered: {
                const elapsed = Math.min(shaderElapsed.restart(), .05);
                window.shaderTime += elapsed * (1 - greeterController.authenticationTension * .82);
            }
        }
        Row {
            x: window.edgeMargin
            y: Math.max(36, canvas.height * .065)
            spacing: 14 * window.uiScale
            opacity: window.successPresence(.30, .78, greeterController.successProgress)
            Image {
                source: "../assets/nocturne-mark.svg"
                width: 30 * window.uiScale
                height: width
                sourceSize: Qt.size(120, 120)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "NOCTURNE"
                color: "#F2F2F3"
                font.family: "Adwaita Sans"
                font.pixelSize: 13 * window.uiScale
                font.weight: Font.Medium
                font.letterSpacing: 3.5 * window.uiScale
            }
        }
        Item {
            id: editorial
            x: window.edgeMargin
            y: canvas.height * (canvas.narrow ? .63 : .35)
            width: canvas.narrow ? Math.min(canvas.width - window.edgeMargin * 2, 380 * window.uiScale) : canvas.leftColumnWidth
            height: 290 * window.uiScale
            ClockDisplay {
                width: parent.width
                height: 160 * window.uiScale
                scaleFactor: window.uiScale
                opacity: Math.max(0, 1 - greeterController.authReveal / .32) * (1 - greeterController.successProgress)
                visible: opacity > .001
                y: -greeterController.authReveal * 18 * window.uiScale
                scale: 1 - greeterController.authReveal * .025
                transformOrigin: Item.Left
            }
            Row {
                y: 200 * window.uiScale
                spacing: 10 * window.uiScale
                opacity: Math.max(0, 1 - greeterController.authReveal * 3)
                visible: opacity > .001
                Text {
                    text: "Press a key to enter"
                    color: "#92929E"
                    font.family: "Adwaita Sans"
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
                previewShortcutsEnabled: window.previewShortcutsEnabled
                visible: greeterController.authUiVisible
                opacity: window.successPresence(.05, .50, greeterController.successProgress)
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
            networkAvailable: window.statusModel ? window.statusModel.networkAvailable : false
            online: window.statusModel ? window.statusModel.online : false
            audioAvailable: window.statusModel ? window.statusModel.audioAvailable : false
            audioMuted: window.statusModel ? window.statusModel.audioMuted : false
            volumePercent: window.statusModel ? window.statusModel.volumePercent : 0
            batteryAvailable: window.statusModel ? window.statusModel.batteryAvailable : false
            batteryPercent: window.statusModel ? window.statusModel.batteryPercent : 0
            controller: greeterController
            opacity: window.successPresence(.30, .78, greeterController.successProgress)
            enabled: greeterController.phase !== GreeterController.Success
        }
        Rectangle {
            id: blackHold
            // Immutable opaque black scene after SUCCESS. Nothing from the
            // previous frame can show through while the launch gate runs.
            anchors.fill: parent
            z: 1000
            color: "#000000"
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
            color: "#777781"
            font.family: "Adwaita Mono"
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
