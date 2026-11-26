pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "theme"

// One screen of the lock: planet, clock, password line and the player card.
Item {
    id: surface

    property bool busy: false
    property bool failed: false
    property int failureCount: 0
    property var stats: null
    signal submitted(string password)

    readonly property real uiScale: Math.max(1, Math.min(1.35, height / 900))
    readonly property real edgeMargin: Math.max(42, Math.min(width * .075, 220))
    readonly property bool narrow: width / height < 1.45
    property bool reducedMotion: Quickshell.env("NOCTURNE_REDUCED_MOTION") === "1"

    // ---- intro -----------------------------------------------------------
    opacity: 0
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutSine
    }

    // ---- shader clock ----------------------------------------------------
    // Idle drops to ~30 fps; typing and PAM run at display rate.
    property real shaderTime: 0
    property real lastTick: Date.now()
    readonly property bool interacting: input.text.length > 0 || busy || failureTimeline.running
    function advance() {
        const now = Date.now();
        const seconds = Math.min((now - lastTick) / 1000, .05);
        lastTick = now;
        if (!reducedMotion)
            shaderTime += seconds * (1 - tension * .15);
    }
    FrameAnimation {
        running: surface.visible && surface.interacting
        onRunningChanged: if (running) surface.lastTick = Date.now()
        onTriggered: surface.advance()
    }
    Timer {
        interval: 33
        repeat: true
        running: surface.visible && !surface.interacting
        onRunningChanged: if (running) surface.lastTick = Date.now()
        onTriggered: surface.advance()
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
        if (failureCount > 0) {
            input.text = "";
            failureTimeline.restart();
            input.forceActiveFocus();
        }
    }
    property real typingPulse: 0
    NumberAnimation {
        id: typingDecay
        target: surface
        property: "typingPulse"
        from: 1
        to: 0
        duration: 480
        easing.type: Easing.OutCubic
    }

    CosmicScene {
        // Same framing as the greeter's hero.
        width: surface.narrow ? surface.width * 1.15 : Math.min(surface.width * .74, surface.height * 1.85)
        height: surface.height * (surface.narrow ? .66 : .84)
        x: surface.width * (surface.narrow ? .58 : surface.width / surface.height > 2.1 ? .65 : .64) - width / 2
        y: surface.height * (surface.narrow ? .33 : .51) - height / 2
        time: surface.shaderTime
        authProgress: 0
        wakePulse: 0
        typingPulse: surface.typingPulse
        failureProgress: surface.failureProgress
        successProgress: 0
        authenticationTension: surface.tension
    }

    KeyboardStatus {
        id: keyboard
        active: surface.visible
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- helpers ---------------------------------------------------------
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
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property real cardWidth: Math.min(width * .27, 340 * uiScale) + 80 * uiScale
    readonly property real pad: 24 * uiScale

    // ---- left column: clock, sign-in, player -----------------------------
    Column {
        id: cards
        x: surface.edgeMargin
        anchors.verticalCenter: parent.verticalCenter
        width: surface.cardWidth
        spacing: 14 * surface.uiScale

        LockCard {
            width: parent.width
            height: 148 * surface.uiScale
            scaleFactor: surface.uiScale

            Column {
                anchors.left: parent.left
                anchors.leftMargin: surface.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * surface.uiScale
                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 72 * surface.uiScale
                    font.weight: Font.Light
                    font.letterSpacing: -2 * surface.uiScale
                }
                Text {
                    text: Strings.date(clock.date)
                    color: Theme.secondary
                    font.family: Theme.sans
                    font.pixelSize: 14 * surface.uiScale
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: surface.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: surface.pad - 4 * surface.uiScale
                spacing: 3 * surface.uiScale
                visible: surface.stats !== null && surface.stats.uptimeSeconds > 0
                Text {
                    anchors.right: parent.right
                    text: "UPTIME"
                    color: Theme.quiet
                    font.family: Theme.sans
                    font.pixelSize: 10 * surface.uiScale
                    font.letterSpacing: 1.4 * surface.uiScale
                }
                Text {
                    anchors.right: parent.right
                    text: surface.stats ? surface.uptimeText(surface.stats.uptimeSeconds) : ""
                    color: Theme.secondary
                    font.family: Theme.sans
                    font.pixelSize: 14 * surface.uiScale
                }
            }
        }

        LockCard {
            width: parent.width
            height: loginColumn.implicitHeight + 2 * surface.pad
            scaleFactor: surface.uiScale

            Column {
                id: loginColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: surface.pad
                spacing: 0

                Row {
                    spacing: 14 * surface.uiScale
                    Avatar {
                        size: 46 * surface.uiScale
                        name: surface.userName
                        source: "file://" + (Quickshell.env("HOME") || "") + "/.face"
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * surface.uiScale
                        Text {
                            text: Strings.greeting(clock.date.getHours())
                            color: Theme.secondary
                            font.family: Theme.sans
                            font.pixelSize: 13 * surface.uiScale
                        }
                        Text {
                            text: surface.userName
                            color: Theme.text
                            font.family: Theme.display
                            font.pixelSize: 22 * surface.uiScale
                        }
                    }
                }
                Item {
                    width: 1
                    height: 24 * surface.uiScale
                }

                // Password line: dots on a hairline, lilac only while in use.
                Item {
                    id: field
                    width: parent.width
                    height: 40 * surface.uiScale

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Strings.pt ? "Digite sua senha" : "Enter your password"
                        color: Theme.placeholder
                        font.family: Theme.sans
                        font.pixelSize: 17 * surface.uiScale
                    }
                    TextInput {
                        id: input
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "\u2022"
                        color: Theme.text
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.selectedText
                        font.family: Theme.sans
                        font.pixelSize: 20 * surface.uiScale
                        font.letterSpacing: 3 * surface.uiScale
                        clip: true
                        focus: true
                        enabled: !surface.busy
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: {
                            if (text.length > 0)
                                typingDecay.restart();
                        }
                        onAccepted: {
                            const password = text;
                            text = "";
                            surface.submitted(password);
                        }
                        Keys.onEscapePressed: text = ""
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        height: 1
                        width: input.text.length > 0 || surface.busy ? parent.width : 50 * surface.uiScale
                        color: Theme.lilac
                        opacity: surface.busy || input.text.length > 0 || surface.failed ? 1 : .55
                        Behavior on width {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }
                Text {
                    topPadding: 14 * surface.uiScale
                    text: surface.failed ? (Strings.pt ? "Senha incorreta. Tente de novo." : "Wrong password. Try again.") : keyboard.capsLock ? Strings.capsLock : (Strings.pt ? "Enter para desbloquear" : "Enter to unlock")
                    color: surface.failed || keyboard.capsLock ? Theme.secondary : Theme.quiet
                    font.family: Theme.sans
                    font.pixelSize: 13 * surface.uiScale
                }
            }
        }

        LockCard {
            width: parent.width
            visible: media.shown
            height: media.shown ? media.height + 28 * surface.uiScale : 0
            scaleFactor: surface.uiScale

            MediaCard {
                id: media
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14 * surface.uiScale
                anchors.rightMargin: 14 * surface.uiScale
                scaleFactor: surface.uiScale
            }
        }
    }

    // ---- bottom strip: network, bluetooth, system load -------------------
    Row {
        id: strip
        anchors.right: parent.right
        anchors.rightMargin: surface.edgeMargin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(36, surface.height * .045)
        spacing: 12 * surface.uiScale
        visible: surface.stats !== null

        StatTile {
            scaleFactor: surface.uiScale
            width: 180 * surface.uiScale
            title: surface.stats && surface.stats.netType === "ethernet" ? (Strings.pt ? "Cabo" : "Ethernet") : "Wi-Fi"
            value: !surface.stats || surface.stats.netType === "none" ? Strings.noConnection : (surface.stats.netName || Strings.connected)
        }
        StatTile {
            scaleFactor: surface.uiScale
            width: 180 * surface.uiScale
            title: "Bluetooth"
            value: !surface.stats || surface.stats.btState === "none" ? Strings.unavailable : surface.stats.btState === "off" ? (Strings.pt ? "Desligado" : "Off") : (surface.stats.btDevice || (Strings.pt ? "Ligado" : "On"))
        }
        StatTile {
            scaleFactor: surface.uiScale
            title: "CPU"
            value: surface.stats && surface.stats.cpu >= 0 ? surface.stats.cpu + "%" : "\u2014"
            fraction: surface.stats && surface.stats.cpu >= 0 ? surface.stats.cpu / 100 : -1
        }
        StatTile {
            scaleFactor: surface.uiScale
            title: "RAM"
            value: surface.stats && surface.stats.ram >= 0 ? surface.stats.ram + "%  \u00b7  " + surface.stats.ramGb.toFixed(1) + " GB" : "\u2014"
            width: 190 * surface.uiScale
            fraction: surface.stats && surface.stats.ram >= 0 ? surface.stats.ram / 100 : -1
        }
        StatTile {
            visible: surface.stats !== null && surface.stats.gpu >= 0
            scaleFactor: surface.uiScale
            title: "GPU"
            value: surface.stats && surface.stats.gpu >= 0 ? surface.stats.gpu + "%" : "\u2014"
            fraction: surface.stats && surface.stats.gpu >= 0 ? surface.stats.gpu / 100 : -1
        }
    }

    // Keep typing even if focus is lost (mouse click on the player).
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: input.forceActiveFocus()
    }
}
