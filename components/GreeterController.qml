import QtQuick

Item {
    id: root

    visible: false

    enum Phase {
        Idle,
        Wake,
        Auth,
        Authenticating,
        Success,
        Failure,
        ReturnToIdle
    }

    property int phase: GreeterController.Idle
    property real authReveal: 0
    property real wakeTension: 0
    property real typingPulse: 0
    property real failureProgress: 0
    property bool failureResolving: false
    property real successProgress: 0
    // True only after the SUCCESS timeline finished for the current Success
    // phase. The window then holds an opaque black scene for the launch gate.
    property bool successComplete: false
    property real authenticationTension: 0
    property string statusMessage: ""
    property bool statusMessageVisible: false
    property bool statusMessageIsError: false
    property bool responseRequired: false
    property bool echoResponse: false

    readonly property bool isIdle: phase === GreeterController.Idle
    readonly property bool authenticationTensionActive: phase === GreeterController.Authenticating || phase === GreeterController.Success
    readonly property bool authUiVisible: phase === GreeterController.Wake || phase === GreeterController.Auth || phase === GreeterController.Authenticating || phase === GreeterController.Failure || phase === GreeterController.ReturnToIdle || phase === GreeterController.Success
    readonly property bool acceptsKeyboardInput: phase === GreeterController.Wake || phase === GreeterController.Auth || phase === GreeterController.Failure

    signal focusInputRequested
    signal clearInputRequested
    signal authenticationRequested(string username, string response)
    signal authenticationResponseSubmitted
    signal previewSuccessRequested

    function wake() {
        if (!isIdle)
            return;
        statusMessage = "";
        statusMessageVisible = false;
        statusMessageIsError = false;
        responseRequired = false;
        echoResponse = false;
        authReveal = 0;
        wakeTension = 0;
        failureProgress = 0;
        successProgress = 0;
        successComplete = false;
        phase = GreeterController.Wake;
        focusInputRequested();
        wakeTimeline.restart();
    }

    function noteKey() {
        if (!acceptsKeyboardInput)
            return;
        typingAnimation.stop();
        typingPulse = 1;
        typingAnimation.restart();
    }

    function requestAuthentication(username, response) {
        if (phase !== GreeterController.Wake && phase !== GreeterController.Auth && phase !== GreeterController.Failure) {
            return;
        }
        if (!responseRequired)
            return;

        failureTimeline.stop();
        failureProgress = 0;
        failureResolving = false;
        statusMessage = "Authentication pending";
        statusMessageVisible = false;
        statusMessageIsError = false;
        responseRequired = false;
        echoResponse = false;
        phase = GreeterController.Authenticating;
        clearInputRequested();
        authenticationRequested(username, response);
        authenticationResponseSubmitted();
        response = "";
    }

    function presentPrompt(message, required, responseEchoed) {
        responseRequired = required;
        echoResponse = responseEchoed;
        if (!required)
            return;

        if (statusMessage === "Authentication pending") {
            statusMessage = "";
            statusMessageVisible = false;
        }

        if (phase === GreeterController.Authenticating) {
            phase = GreeterController.Auth;
            focusInputRequested();
        } else if (phase === GreeterController.Failure) {
            failureTimeline.stop();
            failureProgress = 0;
            failureResolving = false;
            phase = GreeterController.Auth;
            focusInputRequested();
        }
        void message;
    }

    function presentMessage(message, isError) {
        statusMessage = message;
        statusMessageVisible = message.length > 0;
        statusMessageIsError = isError;
    }

    function rejectAuthentication(message) {
        if (phase !== GreeterController.Wake && phase !== GreeterController.Auth && phase !== GreeterController.Authenticating)
            return;
        statusMessage = message;
        statusMessageVisible = false;
        statusMessageIsError = true;
        responseRequired = false;
        echoResponse = false;
        failureProgress = 0;
        failureResolving = false;
        phase = GreeterController.Failure;
        failureTimeline.restart();
    }

    function requestPreviewSuccess(username, response) {
        if (phase !== GreeterController.Wake && phase !== GreeterController.Auth && phase !== GreeterController.Failure)
            return;
        if (!responseRequired)
            return;

        requestAuthentication(username, response);
        response = "";
        if (phase !== GreeterController.Authenticating)
            return;

        previewSuccessRequested();
        successProgress = 0;
        successTimeline.restart();
    }

    function completeAuthentication() {
        if (phase !== GreeterController.Wake && phase !== GreeterController.Auth && phase !== GreeterController.Authenticating)
            return;

        failureTimeline.stop();
        statusMessage = "";
        statusMessageVisible = false;
        statusMessageIsError = false;
        responseRequired = false;
        echoResponse = false;
        failureProgress = 0;
        phase = GreeterController.Success;
        clearInputRequested();
        if (!successTimeline.running)
            successTimeline.restart();
    }

    // Keep the preview API while the real backend boundary is built separately.
    function completePreviewSuccess() {
        completeAuthentication();
    }

    function returnToIdle() {
        if (isIdle || phase === GreeterController.ReturnToIdle)
            return;
        wakeTimeline.stop();
        failureTimeline.stop();
        successTimeline.stop();
        statusMessage = "";
        statusMessageVisible = false;
        statusMessageIsError = false;
        responseRequired = false;
        echoResponse = false;
        failureResolving = false;
        successComplete = false;
        typingAnimation.stop();
        typingPulse = 0;
        phase = GreeterController.ReturnToIdle;
        clearInputRequested();
        returnTimeline.restart();
    }

    onAuthenticationTensionActiveChanged: authenticationTension = authenticationTensionActive ? 1 : 0
    Behavior on authenticationTension {
        NumberAnimation {
            duration: root.authenticationTensionActive ? 360 : 440
            easing.type: root.authenticationTensionActive ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    ParallelAnimation {
        id: wakeTimeline

        SequentialAnimation {
            PauseAnimation {
                duration: 160
            }
            NumberAnimation {
                target: root
                property: "authReveal"
                from: 0
                to: 1
                duration: 840
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "wakeTension"
                from: 0
                to: 1
                duration: 190
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "wakeTension"
                to: 0
                duration: 820
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 430
            }
            ScriptAction {
                script: {
                    if (root.phase === GreeterController.Wake)
                        root.phase = GreeterController.Auth;
                }
            }
        }
    }

    NumberAnimation {
        id: typingAnimation
        target: root
        property: "typingPulse"
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: failureTimeline

        NumberAnimation {
            target: root
            property: "failureProgress"
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: {
                if (root.phase === GreeterController.Failure)
                    root.failureResolving = true;
            }
        }

        NumberAnimation {
            target: root
            property: "failureProgress"
            to: 0
            duration: 260
            easing.type: Easing.InOutSine
        }

        ScriptAction {
            script: {
                if (root.phase === GreeterController.Failure) {
                    root.phase = GreeterController.Auth;
                    root.statusMessage = "";
                    root.statusMessageVisible = false;
                    root.statusMessageIsError = false;
                }
                root.failureResolving = false;
            }
        }
    }

    NumberAnimation {
        id: successTimeline
        target: root
        property: "successProgress"
        from: 0
        to: 1
        duration: 1480
        easing.type: Easing.InOutCubic

        onFinished: {
            if (root.phase === GreeterController.Success && root.successProgress >= 1)
                root.successComplete = true;
        }
    }

    ParallelAnimation {
        id: returnTimeline

        NumberAnimation {
            target: root
            property: "authReveal"
            to: 0
            duration: 460
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: root
            property: "wakeTension"
            to: 0
            duration: 360
            easing.type: Easing.OutSine
        }

        NumberAnimation {
            target: root
            property: "successProgress"
            to: 0
            duration: 460
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: root
            property: "failureProgress"
            to: 0
            duration: 460
            easing.type: Easing.InOutCubic
        }

        onFinished: {
            if (root.phase === GreeterController.ReturnToIdle) {
                root.failureProgress = 0;
                root.phase = GreeterController.Idle;
            }
        }
    }
}
