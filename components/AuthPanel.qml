pragma ComponentBehavior: Bound
import QtQuick
import "theme"

Item {
    id: root
    property var controller
    property string username: "user"
    property string loginUser: username
    property string promptText: "Enter your password"
    property bool responseRequired: true
    property bool echoResponse: false
    property real scaleFactor: 1
    property bool debugMode: false
    property bool capsLockOn: false
    // XKB layout(s) of the greeter compositor, e.g. "br" or "us,br".
    property string keyboardLayout: ""
    property bool previewShortcutsEnabled: false
    property alias inputField: passwordInput
    readonly property real identityReveal: Math.max(0, Math.min(1, (controller.authReveal - .36) / .64))
    readonly property real fieldReveal: Math.max(0, Math.min(1, (controller.authReveal - .50) * 2))
    readonly property real hintReveal: Math.max(0, Math.min(1, (controller.authReveal - .68) / .32))
    // Dot count kept after Enter clears the field, so the dots can wait for
    // PAM and shake on rejection. Only a length; never the secret.
    property int heldDots: 0
    property real shake: 0
    // Crossfade between the hint and "Couldn't sign in".
    property real failureCopy: controller.failureNoticeVisible ? 1 : 0
    Behavior on failureCopy {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    readonly property bool preparingAuthentication: controller.phase === GreeterController.Authenticating || controller.phase === GreeterController.Success
    readonly property int passwordDotCapacity: Math.max(0, Math.floor((passphraseArea.width - submitButton.width - 18 * root.scaleFactor) / (16 * root.scaleFactor)))
    // Hold-to-peek: the hidden response shows as text only while held.
    readonly property bool peeking: peekArea.pressed && !echoResponse && passwordInput.length > 0
    readonly property bool showingText: echoResponse || peeking
    readonly property int visiblePasswordDots: showingText ? 0 : Math.min(passwordInput.length > 0 ? passwordInput.length : heldDots, passwordDotCapacity)
    readonly property bool showingHeldDots: passwordInput.length === 0 && heldDots > 0
    function focusInput() {
        passwordInput.forceActiveFocus();
    }
    function clearInput() {
        passwordInput.clear();
    }
    function dropHeldDots() {
        failureShake.stop();
        shake = 0;
        dotsRow.opacity = 1;
        heldDots = 0;
    }
    Connections {
        target: root.controller
        function onPhaseChanged() {
            const phase = root.controller.phase;
            if (phase === GreeterController.Failure && root.heldDots > 0)
                failureShake.restart();
            else if (phase === GreeterController.Idle || phase === GreeterController.ReturnToIdle || phase === GreeterController.Wake)
                root.dropHeldDots();
        }
    }
    // Damped horizontal shake (+-6 units, 2.5 oscillations) then fade out.
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
    function wakeWithInitialText(text) {
        if (!controller.isIdle)
            return;
        controller.wake();
        if (text.length === 0)
            return;
        passwordInput.insert(passwordInput.cursorPosition, text);
        controller.noteKey();
    }
    function submit(previewSuccess) {
        if (!controller.acceptsKeyboardInput || !responseRequired)
            return;
        let submittedResponse = passwordInput.text;
        heldDots = echoResponse ? 0 : passwordInput.length;
        if (previewSuccess && previewShortcutsEnabled)
            controller.requestPreviewSuccess(loginUser, submittedResponse);
        else
            controller.requestAuthentication(loginUser, submittedResponse);
        passwordInput.clear();
        submittedResponse = "";
    }
    Column {
        y: (1 - root.identityReveal) * 12
        opacity: root.identityReveal * (1 - root.controller.authenticationTension * .08)
        spacing: 10 * root.scaleFactor
        Text {
            // Re-evaluated on every phase change, so it follows the clock.
            text: { root.controller.phase; return Strings.greeting(new Date().getHours()); }
            color: Theme.secondary
            font.family: Theme.sans
            font.pixelSize: 15 * root.scaleFactor
        }
        Text {
            width: root.width
            text: root.username
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 37 * root.scaleFactor
            font.weight: Font.Normal
            font.letterSpacing: -.6 * root.scaleFactor
        }
    }
    Item {
        id: passphraseArea
        x: (1 - root.fieldReveal) * -9
        y: 110 * root.scaleFactor
        width: parent.width
        height: 60 * root.scaleFactor
        opacity: root.fieldReveal * (1 - root.controller.authenticationTension * .12)
        Item {
            anchors.left: parent.left
            anchors.right: peekButton.visible ? peekButton.left : submitButton.left
            anchors.rightMargin: (peekButton.visible ? 8 : 18) * root.scaleFactor
            height: parent.height
            clip: true
            Row {
                id: dotsRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.scaleFactor
                transform: Translate {
                    x: 6 * root.scaleFactor * (1 - root.shake) * Math.sin(root.shake * Math.PI * 5)
                }
                Repeater {
                    id: passwordDots
                    objectName: "passwordDots"
                    model: root.visiblePasswordDots
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
                        width: 5 * root.scaleFactor
                        height: width
                        radius: width / 2
                        color: Theme.text
                        opacity: appear * (root.showingHeldDots ? .45 : index === root.visiblePasswordDots - 1 ? .75 + .25 * root.controller.typingPulse : .75)
                        scale: (.35 + .65 * appear) * (index === root.visiblePasswordDots - 1
                               ? 1 + root.controller.typingPulse * .16 : 1)
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Strings.prompt(root.promptText)
                visible: passwordInput.length === 0 && !root.showingHeldDots
                color: Theme.placeholder
                font.family: Theme.sans
                font.pixelSize: 15 * root.scaleFactor
                textFormat: Text.PlainText
            }
            TextInput {
                id: passwordInput
                anchors.fill: parent
                enabled: root.controller.acceptsKeyboardInput
                activeFocusOnPress: true
                echoMode: root.showingText ? TextInput.Normal : TextInput.Password
                maximumLength: 256
                color: root.showingText ? Theme.text : "transparent"
                selectionColor: root.echoResponse ? Theme.selection : "transparent"
                selectedTextColor: root.echoResponse ? Theme.selectedText : "transparent"
                // Same metrics as the placeholder, centred on the field's line.
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.sans
                font.pixelSize: 15 * root.scaleFactor
                // The native caret follows hidden glyphs, not the dots; the
                // field draws its own caret below.
                cursorDelegate: Item {}
                onTextChanged: {
                    caretBlink.restart();
                    if (length > 0 && root.heldDots > 0)
                        root.dropHeldDots();
                }
                inputMethodHints: root.echoResponse
                                  ? Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                  : Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                Accessible.name: root.echoResponse ? "Visible authentication response" : "Hidden authentication response"
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.controller.returnToIdle();
                        event.accepted = true;
                    } else if (root.previewShortcutsEnabled && event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier)) {
                        Qt.quit();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                        root.submit(true);
                        event.accepted = true;
                    }
                }
                onTextEdited: root.controller.noteKey()
                onAccepted: root.submit()
            }
        }
        Rectangle {
            id: caret
            objectName: "caret"
            readonly property bool active: passwordInput.activeFocus && root.controller.acceptsKeyboardInput
            // After the last dot, at the native cursor for visible responses,
            // or just before the placeholder when the field is empty.
            x: root.showingText ? passwordInput.cursorRectangle.x
               : root.visiblePasswordDots > 0 && !root.showingHeldDots ? dotsRow.width + 8 * root.scaleFactor
               : -5 * root.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, Math.round(1.5 * root.scaleFactor))
            height: 18 * root.scaleFactor
            radius: width / 2
            color: Theme.text
            visible: active
            SequentialAnimation on opacity {
                id: caretBlink
                running: caret.active
                loops: Animation.Infinite
                alwaysRunToEnd: false
                PropertyAction { value: 1 }
                PauseAnimation { duration: 560 }
                NumberAnimation { to: 0; duration: 100 }
                PauseAnimation { duration: 440 }
                NumberAnimation { to: 1; duration: 100 }
            }
        }
        Rectangle {
            // Full-width base of the field, ending under the arrow glyph.
            objectName: "fieldTrack"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width - (submitButton.width - 19 * root.scaleFactor) / 2
            height: 1
            color: Theme.outline
            opacity: 1 - root.controller.authenticationTension * .18
        }
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            // After a rejection the focus segment rests until the next key.
            readonly property bool lit: passwordInput.activeFocus && !root.controller.failureNoticeVisible
            width: lit ? 42 * root.scaleFactor : 18 * root.scaleFactor
            height: 1
            color: lit ? Theme.lilac : Theme.outline
            opacity: 1 - root.controller.authenticationTension * .18
            Behavior on width {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }
        // Not an IconButton: pressing it must not take focus from the field.
        Item {
            id: peekButton
            objectName: "peekButton"
            anchors.right: submitButton.left
            anchors.verticalCenter: parent.verticalCenter
            width: 36 * root.scaleFactor
            height: width
            visible: !root.echoResponse && passwordInput.length > 0 && root.controller.acceptsKeyboardInput
            Accessible.role: Accessible.Button
            Accessible.name: Strings.peek
            Image {
                anchors.centerIn: parent
                width: 17 * root.scaleFactor
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
        IconButton {
            id: submitButton
            objectName: "submitButton"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44 * root.scaleFactor
            height: width
            icon: "../assets/icons/arrow.svg"
            label: Strings.signIn
            scaleFactor: root.scaleFactor
            enabled: root.controller.acceptsKeyboardInput
            onClicked: root.submit()
        }
    }
    Text {
        y: 196 * root.scaleFactor + (1 - root.hintReveal) * 8
        width: parent.width
        wrapMode: Text.WordWrap
        visible: !root.controller.statusMessageVisible
        opacity: root.hintReveal * (1 - root.failureCopy) * (root.preparingAuthentication ? Math.abs(1 - 2 * root.controller.authenticationTension) : 1 - root.controller.authenticationTension)
        text: root.preparingAuthentication && root.controller.authenticationTension >= .5 ? Strings.preparing : Strings.hint
        color: Theme.placeholder
        font.family: Theme.sans
        font.pixelSize: 13 * root.scaleFactor
    }
    Text {
        y: 196 * root.scaleFactor + (1 - root.hintReveal) * 8
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        visible: root.controller.statusMessageVisible && root.controller.phase !== GreeterController.Failure
        opacity: root.hintReveal * (1 - root.controller.authenticationTension)
        text: root.controller.statusMessage
        color: root.controller.statusMessageIsError ? Theme.lilac : Theme.placeholder
        font.family: Theme.sans
        font.pixelSize: 13 * root.scaleFactor
    }
    Text {
        y: 196 * root.scaleFactor + (1 - root.hintReveal) * 8
        width: parent.width
        wrapMode: Text.WordWrap
        opacity: root.hintReveal * root.failureCopy * (root.controller.statusMessageVisible && root.controller.phase !== GreeterController.Failure ? 0 : 1)
        text: Strings.failed
        color: Theme.lilac
        font.family: Theme.sans
        font.pixelSize: 13 * root.scaleFactor
    }
    // Caps Lock (lilac, it changes what the password is) and the layout.
    Row {
        objectName: "keyboardIndicator"
        anchors.right: parent.right
        // Ends under the arrow glyph, like the field track.
        anchors.rightMargin: (44 - 19) / 2 * root.scaleFactor
        y: 196 * root.scaleFactor + (1 - root.hintReveal) * 8
        spacing: 8 * root.scaleFactor
        opacity: root.hintReveal * (1 - root.controller.authenticationTension)
        visible: root.capsLockOn || root.keyboardLayout.length > 0
        Text {
            objectName: "capsLockIndicator"
            visible: root.capsLockOn
            text: Strings.capsLock
            color: Theme.lilac
            font.family: Theme.sans
            font.pixelSize: 13 * root.scaleFactor
        }
        Text {
            visible: root.keyboardLayout.length > 0
            text: root.keyboardLayout.toUpperCase().replace(/,/g, " · ")
            color: Theme.quiet
            font.family: Theme.sans
            font.pixelSize: 13 * root.scaleFactor
        }
    }
    Text {
        y: 238 * root.scaleFactor
        width: parent.width
        visible: root.debugMode
        text: "Preview only · Ctrl+Enter: success\n" + root.controller.statusMessage
        color: Theme.secondary
        font.family: Theme.mono
        font.pixelSize: 10 * root.scaleFactor
    }
}
