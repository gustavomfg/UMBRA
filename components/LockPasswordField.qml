pragma ComponentBehavior: Bound
import QtQuick
import "theme"

// The lock's password line, built like the greeter's: dots on a hairline,
// a thin caret, hold-to-peek and a submit arrow, then one message line that
// crossfades between hint, Caps Lock, checking and error.
Item {
    id: root

    property real scaleFactor: 1
    property bool busy: false
    property bool capsLock: false
    // Bumped by the lock on every rejection.
    property int failureCount: 0
    signal submitted(string password)
    signal typed

    readonly property alias input: passwordInput
    readonly property bool hasText: passwordInput.length > 0
    // Dot count kept after Enter clears the field, so the dots can wait for
    // PAM and shake on rejection. Only a length, never the secret.
    property int heldDots: 0
    property real shake: 0
    // After a rejection the line rests (grey, short) until the next key.
    property bool resting: false

    readonly property bool peeking: peekArea.pressed && passwordInput.length > 0
    readonly property real s: scaleFactor
    readonly property int dotCapacity: Math.max(0, Math.floor((textArea.width - 12 * s) / (15 * s)))
    readonly property int shownDots: peeking ? 0 : Math.min(passwordInput.length > 0 ? passwordInput.length : heldDots, dotCapacity)
    readonly property bool showingHeld: passwordInput.length === 0 && heldDots > 0

    implicitHeight: line.height + messageText.anchors.topMargin + messageText.height

    function focusInput() {
        passwordInput.forceActiveFocus();
    }
    function submit() {
        if (busy || passwordInput.length === 0)
            return;
        const password = passwordInput.text;
        heldDots = passwordInput.length;
        passwordInput.text = "";
        submitted(password);
    }
    function dropHeld() {
        failureShake.stop();
        shake = 0;
        dotsRow.opacity = 1;
        heldDots = 0;
    }

    onFailureCountChanged: {
        if (failureCount <= 0)
            return;
        resting = true;
        if (heldDots > 0)
            failureShake.restart();
        passwordInput.forceActiveFocus();
    }

    // Damped horizontal shake (+-6 units, 2.5 oscillations), then fade out.
    SequentialAnimation {
        id: failureShake
        NumberAnimation {
            target: root
            property: "shake"
            from: 0
            to: 1
            duration: 300
        }
        ScriptAction {
            script: root.shake = 0
        }
        NumberAnimation {
            target: dotsRow
            property: "opacity"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                root.heldDots = 0;
                dotsRow.opacity = 1;
            }
        }
    }

    Item {
        id: line
        width: parent.width
        height: 44 * root.s

        Item {
            id: textArea
            anchors.left: parent.left
            anchors.right: peekButton.visible ? peekButton.left : submitButton.left
            anchors.rightMargin: 8 * root.s
            height: parent.height
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: passwordInput.length === 0 && !root.showingHeld
                text: Strings.prompt("Enter your password")
                color: Theme.placeholder
                font.family: Theme.sans
                font.pixelSize: 15 * root.s
            }
            Row {
                id: dotsRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s
                transform: Translate {
                    x: 6 * root.s * (1 - root.shake) * Math.sin(root.shake * Math.PI * 5)
                }
                Repeater {
                    model: root.shownDots
                    delegate: Rectangle {
                        required property int index
                        property real appear: 0
                        Component.onCompleted: appear = 1
                        Behavior on appear {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                        width: 5 * root.s
                        height: width
                        radius: width / 2
                        color: Theme.text
                        opacity: appear * (root.showingHeld ? .45 : .8)
                        scale: .35 + .65 * appear
                    }
                }
            }
            TextInput {
                id: passwordInput
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.peeking ? TextInput.Normal : TextInput.Password
                color: root.peeking ? Theme.text : "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                font.family: Theme.sans
                font.pixelSize: 15 * root.s
                maximumLength: 256
                // Keeps focus while PAM runs (disabling would drop it).
                readOnly: root.busy
                focus: true
                cursorDelegate: Item {}
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                Accessible.name: Strings.prompt("Enter your password")
                onTextEdited: {
                    root.resting = false;
                    if (root.heldDots > 0)
                        root.dropHeld();
                    caretBlink.restart();
                    root.typed();
                }
                onAccepted: root.submit()
                Keys.onEscapePressed: {
                    text = "";
                    root.resting = false;
                }
            }
        }

        // Thin caret: after the last dot, at the text when peeking, or just
        // before the placeholder when empty.
        Rectangle {
            id: caret
            readonly property bool active: passwordInput.activeFocus && !root.busy
            x: root.peeking ? passwordInput.cursorRectangle.x : root.shownDots > 0 && !root.showingHeld ? dotsRow.width + 8 * root.s : -5 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, Math.round(1.5 * root.s))
            height: 18 * root.s
            radius: width / 2
            color: Theme.text
            visible: active
            SequentialAnimation on opacity {
                id: caretBlink
                running: caret.active
                loops: Animation.Infinite
                PropertyAction {
                    value: 1
                }
                PauseAnimation {
                    duration: 560
                }
                NumberAnimation {
                    to: 0
                    duration: 100
                }
                PauseAnimation {
                    duration: 440
                }
                NumberAnimation {
                    to: 1
                    duration: 100
                }
            }
        }

        // Hold to peek; not a focusable button, so the field keeps the keys.
        Item {
            id: peekButton
            anchors.right: submitButton.left
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * root.s
            height: width
            visible: passwordInput.length > 0 && !root.busy
            Accessible.role: Accessible.Button
            Accessible.name: Strings.peek
            Image {
                anchors.centerIn: parent
                width: 17 * root.s
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: "../assets/icons/eye.svg"
                opacity: peekArea.pressed ? 1 : peekArea.containsMouse ? .85 : .55
                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }
            MouseArea {
                id: peekArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onReleased: passwordInput.forceActiveFocus()
                onCanceled: passwordInput.forceActiveFocus()
            }
        }
        Item {
            id: submitButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * root.s
            height: width
            Accessible.role: Accessible.Button
            Accessible.name: Strings.unlock
            Image {
                anchors.centerIn: parent
                width: 19 * root.s
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: "../assets/icons/arrow.svg"
                opacity: !root.hasText || root.busy ? .35 : submitArea.containsMouse ? 1 : .8
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }
            MouseArea {
                id: submitArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.hasText && !root.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.submit();
                    passwordInput.forceActiveFocus();
                }
            }
        }

        // Full-width track under the field, ending under the arrow glyph.
        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width - (submitButton.width - 19 * root.s) / 2
            height: 1
            color: Theme.outline
        }
        // Lilac segment: follows what is typed instead of jumping to full
        // width, runs the whole track while PAM checks, rests after an error.
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 1
            readonly property bool lit: passwordInput.activeFocus && !root.resting
            width: !lit ? 18 * root.s : root.busy ? track.width : Math.max(42 * root.s, Math.min(track.width, (root.shownDots > 0 ? dotsRow.width : 0) + 28 * root.s))
            color: lit ? Theme.lilac : Theme.outline
            Behavior on width {
                NumberAnimation {
                    duration: root.busy ? 420 : 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }
    }

    // One message line; changes crossfade instead of swapping in place.
    readonly property string message: resting && !hasText ? Strings.lockFailed : busy ? Strings.lockChecking : capsLock ? Strings.capsLock : Strings.lockHint
    readonly property bool messageIsFeedback: (resting && !hasText) || (capsLock && !busy)
    onMessageChanged: messageSwap.restart()
    Component.onCompleted: {
        messageText.text = message;
        messageText.color = messageIsFeedback ? Theme.lilac : Theme.placeholder;
    }
    Text {
        id: messageText
        anchors.top: line.bottom
        anchors.topMargin: 12 * root.s
        width: parent.width
        elide: Text.ElideRight
        font.family: Theme.sans
        font.pixelSize: 13 * root.s
    }
    SequentialAnimation {
        id: messageSwap
        NumberAnimation {
            target: messageText
            property: "opacity"
            to: 0
            duration: 90
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                messageText.text = root.message;
                messageText.color = root.messageIsFeedback ? Theme.lilac : Theme.placeholder;
            }
        }
        NumberAnimation {
            target: messageText
            property: "opacity"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
}
