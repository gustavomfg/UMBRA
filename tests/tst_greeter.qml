import QtQuick
import QtTest
import "../components"

TestCase {
    id: testCase

    name: "NocturneGreeter"
    when: windowShown
    visible: true
    width: 1280
    height: 720

    GreeterController {
        id: controller
    }

    PreviewAuthenticator {
        id: previewBackend
        controller: controller
    }

    AuthenticatorBridge {
        id: boundary
        controller: controller
        backend: previewBackend
        selectedUser: "preview-user"
        selectedSession: "preview-session"
    }

    AuthPanel {
        id: authPanel
        width: 420
        height: 260
        visible: true
        opacity: 1
        controller: controller
        username: "preview-user"
        previewShortcutsEnabled: true
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
    }

    SignalSpy {
        id: authenticationResponseSpy
        target: controller
        signalName: "authenticationResponseSubmitted"
    }

    Connections {
        target: controller
        function onFocusInputRequested() {
            authPanel.focusInput();
        }

        function onClearInputRequested() {
            authPanel.clearInput();
        }

        function onPhaseChanged() {
            if (controller.phase === GreeterController.Authenticating || controller.phase === GreeterController.Success || controller.phase === GreeterController.Idle)
                testCase.forceActiveFocus();
            else if (controller.phase === GreeterController.Failure)
                authPanel.focusInput();
        }
    }

    function cleanup() {
        if (!controller.isIdle)
            controller.returnToIdle();
        // The real Wayland render loop can deliver the final timer tick later
        // than an absolute sleep. Start each test only after reset is complete.
        tryCompare(controller, "phase", GreeterController.Idle, 1200);
        authPanel.inputField.clear();
        authenticationResponseSpy.clear();
    }

    function test_initialIdle() {
        compare(controller.phase, GreeterController.Idle);
        compare(controller.authReveal, 0);
        verify(!controller.acceptsKeyboardInput);
    }

    function test_wakeReturnAndRepeatedWake() {
        controller.wake();
        compare(controller.phase, GreeterController.Wake);
        controller.wake();
        compare(controller.phase, GreeterController.Wake);

        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        controller.returnToIdle();
        compare(controller.phase, GreeterController.ReturnToIdle);
        wait(500);
        compare(controller.phase, GreeterController.Idle);
        compare(controller.authReveal, 0);
    }

    function test_escapeDuringWakeThenWakeAgain() {
        controller.wake();
        compare(controller.phase, GreeterController.Wake);
        controller.returnToIdle();
        compare(controller.phase, GreeterController.ReturnToIdle);
        wait(500);
        compare(controller.phase, GreeterController.Idle);

        controller.wake();
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        verify(authPanel.inputField.activeFocus);
    }

    function test_keyboardInputAndFailure() {
        controller.wake();
        wait(480);
        verify(authPanel.inputField.activeFocus);
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_B);
        compare(authPanel.inputField.text, "ab");

        keyClick(Qt.Key_Return);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");
        compare(authenticationResponseSpy.count, 1);

        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        wait(20);
        verify(controller.failureProgress > 0);
        compare(authPanel.inputField.text, "");
        verify(controller.acceptsKeyboardInput);
        verify(authPanel.inputField.activeFocus);
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        compare(controller.failureProgress, 0);
        verify(!controller.failureResolving);
        verify(controller.authenticationTension < .05);
        compare(controller.statusMessage, "");
    }

    function test_wakeTypeAndSubmitImmediately() {
        authPanel.wakeWithInitialText("x");
        compare(controller.phase, GreeterController.Wake);
        compare(authPanel.inputField.text, "x");
        authPanel.submit();
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");
        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        verify(controller.acceptsKeyboardInput);
    }

    function test_escapeFromFocusedInput() {
        controller.wake();
        wait(480);
        verify(authPanel.inputField.activeFocus);
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Escape);
        compare(controller.phase, GreeterController.ReturnToIdle);
        compare(authPanel.inputField.text, "");
        wait(500);
        compare(controller.phase, GreeterController.Idle);
    }

    function test_previewSuccessAndReturn() {
        controller.wake();
        wait(480);
        controller.requestPreviewSuccess("preview-user", "preview-secret");
        compare(controller.phase, GreeterController.Authenticating);
        verify(controller.authenticationTensionActive);
        verify(controller.successProgress === 0);
        wait(380);
        compare(controller.phase, GreeterController.Success);
        verify(controller.authenticationTensionActive);
        const progressAtResult = controller.successProgress;
        verify(progressAtResult > 0.12 && progressAtResult < 0.42);
        wait(100);
        verify(controller.successProgress > progressAtResult);
        wait(1150);
        verify(controller.successProgress > 0.99);

        controller.returnToIdle();
        wait(500);
        compare(controller.phase, GreeterController.Idle);
        compare(controller.successProgress, 0);
    }

    function test_mouseFocusAndSubmit() {
        controller.wake();
        wait(1000);
        testCase.forceActiveFocus();
        verify(!authPanel.inputField.activeFocus);
        mouseClick(authPanel.inputField, 30, 25);
        verify(authPanel.inputField.activeFocus);
        keyClick(Qt.Key_A);
        const button = findChild(authPanel, "submitButton");
        verify(button !== null);
        mouseClick(button, button.width / 2, button.height / 2);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authenticationResponseSpy.count, 1);
    }

    function test_cancelPendingAndRepeat() {
        controller.wake();
        wait(200);
        controller.requestAuthentication("preview-user", "test");
        controller.requestAuthentication("preview-user", "test");
        compare(authenticationResponseSpy.count, 1);
        controller.returnToIdle();
        wait(500);
        controller.wake();
        wait(1000);
        compare(controller.phase, GreeterController.Auth);
        compare(controller.statusMessage, "");
    }

    function test_ctrlEnterPreviewShortcut() {
        controller.wake();
        wait(480);
        verify(authPanel.inputField.activeFocus);
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Return, Qt.ControlModifier);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");
        compare(authPanel.visiblePasswordDots, 0);
        tryCompare(controller, "phase", GreeterController.Success, 1200);
    }

    function test_firstKeyAtIdleIsRetained() {
        compare(controller.phase, GreeterController.Idle);
        authPanel.wakeWithInitialText("a");
        compare(controller.phase, GreeterController.Wake);
        compare(authPanel.inputField.text, "a");
        verify(authPanel.inputField.activeFocus);
        compare(authPanel.inputField.echoMode, TextInput.Password);
        controller.returnToIdle();
        wait(500);
        compare(authPanel.inputField.text, "");
    }

    function test_backspaceAndLongPassword() {
        controller.wake();
        wait(480);
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_B);
        keyClick(Qt.Key_Backspace);
        compare(authPanel.inputField.text, "a");

        for (let i = 0; i < 260; ++i)
            keyClick(Qt.Key_X);

        compare(authPanel.inputField.length, 256);
        compare(authPanel.visiblePasswordDots, authPanel.passwordDotCapacity);
        verify(authPanel.passwordDotCapacity > 0);
        compare(authPanel.inputField.echoMode, TextInput.Password);
        authPanel.clearInput();
        compare(authPanel.inputField.length, 0);
        compare(authPanel.visiblePasswordDots, 0);
    }

    function test_escapeCancelsAuthenticatingWithoutLateFailure() {
        controller.wake();
        controller.requestAuthentication("preview-user", "pending");
        compare(controller.phase, GreeterController.Authenticating);
        compare(authenticationResponseSpy.count, 1);

        controller.returnToIdle();
        wait(1000);
        compare(controller.phase, GreeterController.Idle);
        compare(controller.statusMessage, "");
        compare(controller.failureProgress, 0);
    }

    function test_escapeCancelsPreviewSuccessWithoutLateSuccess() {
        controller.wake();
        controller.requestPreviewSuccess("preview-user", "preview-secret");
        compare(controller.phase, GreeterController.Authenticating);
        controller.returnToIdle();
        wait(500);
        compare(controller.phase, GreeterController.Idle);
        compare(controller.successProgress, 0);
        compare(controller.statusMessage, "");
    }

    function test_successCanFollowFailureWithoutStaleFailure() {
        controller.wake();
        wait(480);
        controller.requestAuthentication("preview-user", "wrong");
        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        verify(boundary.responseRequired);
        controller.requestPreviewSuccess("preview-user", "correct");
        compare(controller.phase, GreeterController.Authenticating);
        verify(controller.authenticationTensionActive);
        tryCompare(controller, "phase", GreeterController.Success, 1200);
        verify(controller.authenticationTensionActive);
        wait(300);
        compare(controller.phase, GreeterController.Success);
    }

    function test_retryInputDuringFailureRecovery() {
        controller.wake();
        wait(480);
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Return);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");

        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        verify(authPanel.inputField.activeFocus);
        verify(controller.acceptsKeyboardInput);
        keyClick(Qt.Key_B);
        compare(authPanel.inputField.text, "b");
        keyClick(Qt.Key_Backspace);
        compare(authPanel.inputField.text, "");
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        verify(boundary.responseRequired);
        keyClick(Qt.Key_C);
        keyClick(Qt.Key_Return);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");
        compare(authenticationResponseSpy.count, 2);

        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
        verify(authPanel.inputField.activeFocus);
    }

    function test_fiveConsecutiveFailuresRecover() {
        controller.wake();
        tryCompare(controller, "phase", GreeterController.Auth, 1200);

        for (let attempt = 0; attempt < 5; ++attempt) {
            authPanel.inputField.text = "wrong";
            authPanel.submit();
            compare(controller.phase, GreeterController.Authenticating);
            compare(authPanel.inputField.text, "");
            tryCompare(controller, "phase", GreeterController.Failure, 1200);
            verify(controller.acceptsKeyboardInput);
            verify(authPanel.inputField.activeFocus);
            tryCompare(controller, "phase", GreeterController.Auth, 1200);
            compare(controller.failureProgress, 0);
            verify(!controller.failureResolving);
        }
        compare(authenticationResponseSpy.count, 5);
    }

    function test_escapeCancelsFailureRecovery() {
        controller.wake();
        wait(480);
        authPanel.submit();
        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        tryVerify(() => controller.failureProgress > 0, 300);
        keyClick(Qt.Key_Escape);
        compare(controller.phase, GreeterController.ReturnToIdle);
        compare(authPanel.inputField.text, "");
        wait(100);
        verify(controller.failureProgress < 1);
        wait(500);
        compare(controller.phase, GreeterController.Idle);
        compare(controller.failureProgress, 0);
        verify(!controller.failureResolving);
        compare(controller.statusMessage, "");
    }

    function test_failurePulseReleasesWithoutHold() {
        controller.wake();
        wait(480);
        authPanel.submit();
        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        verify(controller.authenticationTension < 1);
        verify(controller.acceptsKeyboardInput);

        wait(150);
        verify(controller.failureResolving);
        verify(controller.failureProgress > 0 && controller.failureProgress < 1);
        verify(controller.authenticationTension < 1);

        wait(280);
        compare(controller.phase, GreeterController.Auth);
        compare(controller.failureProgress, 0);
        verify(!controller.failureResolving);
        verify(controller.authenticationTension < .05);
    }

    function test_emptyPasswordAndRepeatedSubmit() {
        controller.wake();
        wait(480);
        compare(authPanel.inputField.text, "");
        authPanel.submit();
        authPanel.submit();
        compare(controller.phase, GreeterController.Authenticating);
        compare(authenticationResponseSpy.count, 1);
        compare(authPanel.inputField.text, "");
        tryCompare(controller, "phase", GreeterController.Failure, 1200);
        tryCompare(controller, "phase", GreeterController.Auth, 1200);
    }
}
