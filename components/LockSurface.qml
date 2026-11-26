pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "theme"

// One screen of the lock: blurred desktop + planet behind a single frosted
// panel holding the clock, identity, password line, player and readings.
Item {
    id: surface

    property bool busy: false
    property int failureCount: 0
    property var stats: null
    // Blurred desktop (see LockBackdrop); "" keeps the black scene.
    property url backgroundSource: ""
    property rect screenRect: Qt.rect(0, 0, width, height)
    property rect layoutRect: Qt.rect(0, 0, width, height)
    // Preview/captures only.
    property var previewPlayer: null
    property bool preferPreviewPlayer: false
    property bool capsLockOverride: false
    signal submitted(string password)

    readonly property real uiScale: Math.max(1, Math.min(1.35, height / 900))
    readonly property real s: uiScale
    readonly property bool narrow: width / height < 1.45
    property bool reducedMotion: Quickshell.env("NOCTURNE_REDUCED_MOTION") === "1"
    readonly property string userName: Quickshell.env("USER") || "user"

    // ---- intro -----------------------------------------------------------
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }

    // ---- shader clock ----------------------------------------------------
    // Typing, PAM and the failure wave run at display rate (vsync-locked);
    // idle redraws at ~30 fps on whole display frames, as in the greeter.
    property real shaderTime: 0
    readonly property bool interacting: field.hasText || busy || failureTimeline.running || typingPulse > 0
    function advance(seconds) {
        if (!reducedMotion)
            shaderTime += Math.min(seconds, .05) * (1 - tension * .15) * recoil(failureProgress);
    }
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
    FrameAnimation {
        id: refreshProbe
        property real refresh: 60
        property real total: 0
        property int samples: 0
        running: surface.visible && samples < 60
        onTriggered: {
            if (currentFrame < 10 || frameTime <= 0 || frameTime > .05)
                return;
            total += frameTime;
            samples += 1;
            if (samples === 60)
                refresh = Math.max(24, Math.min(360, 60 / total));
        }
    }
    FrameAnimation {
        running: surface.visible && surface.interacting && !surface.reducedMotion
        onTriggered: surface.advance(frameTime)
    }
    Timer {
        readonly property int framesPerTick: Math.max(1, Math.round(refreshProbe.refresh / 30))
        readonly property real tickSeconds: framesPerTick / refreshProbe.refresh
        interval: Math.max(1, Math.round(tickSeconds * 1000))
        repeat: true
        running: surface.visible && !surface.interacting && !surface.reducedMotion
        onTriggered: surface.advance(tickSeconds)
    }

    // ---- scene state -----------------------------------------------------
    property real tension: busy ? 1 : 0
    Behavior on tension {
        NumberAnimation {
            duration: surface.busy ? 360 : 440
            easing.type: surface.busy ? Easing.OutCubic : Easing.InOutCubic
        }
    }
    property real failureProgress: 0
    NumberAnimation {
        id: failureTimeline
        target: surface
        property: "failureProgress"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.InOutSine
        onFinished: surface.failureProgress = 0
    }
    onFailureCountChanged: {
        if (failureCount > 0)
            failureTimeline.restart();
    }
    property real typingPulse: 0
    NumberAnimation {
        id: typingDecay
        target: surface
        property: "typingPulse"
        from: 1
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
    }

    // ---- background --------------------------------------------------------
    Item {
        id: backdrop
        anchors.fill: parent

        LockBackdrop {
            anchors.fill: parent
            source: surface.backgroundSource
            screenRect: surface.screenRect
            layoutRect: surface.layoutRect
        }
        CosmicScene {
            // The greeter's hero framing: the planet stays the main element.
            width: surface.narrow ? surface.width * 1.15 : Math.min(surface.width * .74, surface.height * 1.85)
            height: surface.height * (surface.narrow ? .66 : .84)
            x: surface.width * (surface.narrow ? .58 : surface.width / surface.height > 2.1 ? .65 : .64) - width / 2
            y: surface.height * (surface.narrow ? .33 : .51) - height / 2
            shader: Qt.resolvedUrl("../shaders/pulse-lock.frag.qsb")
            time: surface.shaderTime
            typingPulse: surface.typingPulse
            failureProgress: surface.failureProgress
            authenticationTension: surface.tension
        }
    }

    KeyboardStatus {
        id: keyboard
        active: surface.visible
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- helpers -----------------------------------------------------------
    function uptimeText(total) {
        const d = Math.floor(total / 86400);
        const h = Math.floor(total % 86400 / 3600);
        const m = Math.floor(total % 3600 / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h" + (m < 10 ? "0" : "") + m + "m";
        return m + "m";
    }
    function refocus() {
        if (surface.visible)
            field.focusInput();
    }

    // Anything that takes focus (media buttons, clicks) hands it back, so the
    // keyboard always types into the password.
    MouseArea {
        anchors.fill: parent
        onClicked: surface.refocus()
    }

    // ---- frosted panel -------------------------------------------------------
    readonly property real pad: 30 * s
    readonly property real panelWidth: Math.min(width - 48 * s, 480 * s)

    Item {
        id: panel
        width: surface.panelWidth
        height: content.implicitHeight + 2 * surface.pad
        // Left of the planet, over the tip of its rings; centred on narrow
        // screens where the planet sits above.
        x: surface.narrow ? (surface.width - width) / 2 : Math.max(48 * surface.s, surface.width * .25 - width / 2)
        y: surface.narrow ? Math.min(surface.height - height - 48 * surface.s, surface.height * .56) : (surface.height - height) / 2

        // Glass: the scene behind the panel, blurred, inside rounded corners.
        ShaderEffectSource {
            id: behind
            sourceItem: backdrop
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            textureSize: Qt.size(Math.max(1, panel.width / 2), Math.max(1, panel.height / 2))
            live: true
            visible: false
            anchors.fill: parent
        }
        Rectangle {
            id: glassMask
            anchors.fill: parent
            radius: rim.radius
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: behind
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: -.2
            maskEnabled: true
            maskSource: glassMask
            autoPaddingEnabled: false
        }
        LockCard {
            id: rim
            anchors.fill: parent
            scaleFactor: surface.s
        }

        Column {
            id: content
            x: surface.pad
            y: surface.pad
            width: parent.width - 2 * surface.pad
            spacing: 0

            // Clock and date, uptime on the right.
            Item {
                width: parent.width
                height: clockText.height + dateText.height + 4 * surface.s
                Text {
                    id: clockText
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 56 * surface.s
                    font.weight: Font.Light
                    font.letterSpacing: -1.6 * surface.s
                }
                Text {
                    id: dateText
                    anchors.top: clockText.bottom
                    anchors.topMargin: 4 * surface.s
                    text: Strings.date(clock.date)
                    color: Theme.secondary
                    font.family: Theme.sans
                    font.pixelSize: 13 * surface.s
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: dateText.baseline
                    visible: surface.stats !== null && surface.stats.uptimeSeconds > 0
                    text: surface.stats ? Strings.uptime + " " + surface.uptimeText(surface.stats.uptimeSeconds) : ""
                    color: Theme.quiet
                    font.family: Theme.sans
                    font.pixelSize: 12 * surface.s
                }
            }

            Item {
                width: 1
                height: 26 * surface.s
            }

            // Identity.
            Row {
                spacing: 14 * surface.s
                Avatar {
                    size: 44 * surface.s
                    name: surface.userName
                    source: "file://" + (Quickshell.env("HOME") || "") + "/.face"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * surface.s
                    Text {
                        text: Strings.greeting(clock.date.getHours())
                        color: Theme.secondary
                        font.family: Theme.sans
                        font.pixelSize: 13 * surface.s
                    }
                    Text {
                        text: surface.userName
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 20 * surface.s
                        font.letterSpacing: -.3 * surface.s
                    }
                }
            }

            Item {
                width: 1
                height: 14 * surface.s
            }

            LockPasswordField {
                id: field
                width: parent.width
                scaleFactor: surface.s
                busy: surface.busy
                capsLock: keyboard.capsLock || surface.capsLockOverride
                failureCount: surface.failureCount
                Component.onCompleted: focusInput()
                onSubmitted: password => surface.submitted(password)
                onTyped: typingDecay.restart()
                Connections {
                    target: field.input
                    function onActiveFocusChanged() {
                        if (!field.input.activeFocus)
                            Qt.callLater(surface.refocus);
                    }
                }
            }

            // Player.
            Item {
                width: parent.width
                height: media.shown ? 22 * surface.s : 0
                visible: media.shown
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceEdge
                visible: media.shown
            }
            Item {
                width: parent.width
                height: media.shown ? 16 * surface.s : 0
                visible: media.shown
            }
            MediaCard {
                id: media
                width: parent.width
                scaleFactor: surface.s
                previewPlayer: surface.previewPlayer
                preferPreview: surface.preferPreviewPlayer
                onInteracted: surface.refocus()
            }

            // Readings.
            Item {
                width: parent.width
                height: 22 * surface.s
                visible: readings.visible
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceEdge
                visible: readings.visible
            }
            Item {
                width: parent.width
                height: 16 * surface.s
                visible: readings.visible
            }
            Row {
                id: readings
                width: parent.width
                visible: surface.stats !== null
                readonly property bool showBluetooth: surface.stats !== null && surface.stats.btState !== "none"
                readonly property bool showGpu: surface.stats !== null && surface.stats.gpu >= 0
                // Named readings get more room than the percentage gauges.
                readonly property real gap: 16 * surface.s
                readonly property real units: 1.7 + (showBluetooth ? 1.4 : 0) + 2 + (showGpu ? 1 : 0)
                readonly property int count: 3 + (showBluetooth ? 1 : 0) + (showGpu ? 1 : 0)
                readonly property real unit: (width - gap * (count - 1)) / units
                readonly property real cell: unit
                spacing: gap

                StatTile {
                    width: readings.unit * 1.7
                    scaleFactor: surface.s
                    title: surface.stats && surface.stats.netType === "ethernet" ? Strings.ethernet : Strings.wifi
                    value: !surface.stats || surface.stats.netType === "none" ? Strings.noConnection : (surface.stats.netName || Strings.connected)
                }
                StatTile {
                    width: readings.unit * 1.4
                    visible: readings.showBluetooth
                    scaleFactor: surface.s
                    title: Strings.bluetooth
                    value: !surface.stats || surface.stats.btState === "none" ? Strings.unavailable : surface.stats.btState === "off" ? Strings.switchedOff : (surface.stats.btDevice || Strings.switchedOn)
                }
                StatTile {
                    width: readings.cell
                    scaleFactor: surface.s
                    title: "CPU"
                    value: surface.stats && surface.stats.cpu >= 0 ? surface.stats.cpu + "%" : "—"
                    fraction: surface.stats && surface.stats.cpu >= 0 ? surface.stats.cpu / 100 : -1
                }
                StatTile {
                    width: readings.cell
                    scaleFactor: surface.s
                    title: "RAM"
                    value: surface.stats && surface.stats.ram >= 0 ? surface.stats.ramGb.toFixed(1) + " GB" : "—"
                    fraction: surface.stats && surface.stats.ram >= 0 ? surface.stats.ram / 100 : -1
                }
                StatTile {
                    id: gpuTile
                    width: readings.cell
                    visible: readings.showGpu
                    scaleFactor: surface.s
                    title: "GPU"
                    value: surface.stats && surface.stats.gpu >= 0 ? surface.stats.gpu + "%" : "—"
                    fraction: surface.stats && surface.stats.gpu >= 0 ? surface.stats.gpu / 100 : -1
                }
            }
        }
    }
}
