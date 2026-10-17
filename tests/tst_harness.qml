import QtQuick
import QtTest
import "../components"
import "../harness/mock"

TestCase {
    id: testCase
    name: "NocturneIsolatedHarness"
    when: windowShown
    visible: true
    width: 900
    height: 500

    MockIdentity {
        id: fixture
    }

    GreeterController {
        id: controller
    }

    MockAuthenticator {
        id: backend
        scenario: "password-failure"
        responseDelay: 60
    }

    AuthenticatorBridge {
        id: boundary
        controller: controller
        backend: backend
        selectedUser: fixture.userId
        selectedSession: fixture.sessionId
    }

    AuthPanel {
        id: authPanel
        width: 400
        height: 260
        controller: controller
        username: fixture.displayName
        loginUser: fixture.userId
        promptText: boundary.promptText
        responseRequired: boundary.responseRequired
        echoResponse: boundary.echoResponse
        previewShortcutsEnabled: false
    }

    SystemChrome {
        id: isolatedStatus
        width: 800
        height: 40
        controller: controller
    }

    SignalSpy {
        id: authResponseSpy
        target: controller
        signalName: "authenticationResponseSubmitted"
    }

    SignalSpy {
        id: previewSuccessSpy
        target: controller
        signalName: "previewSuccessRequested"
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
        backend.scenario = "password-failure";
        if (!controller.isIdle)
            controller.returnToIdle();
        wait(500);
        authPanel.clearInput();
        authResponseSpy.clear();
        previewSuccessSpy.clear();
    }

    function test_fixtureIsNotHostIdentity() {
        compare(fixture.userId, "umbra-fixture");
        compare(fixture.sessionId, "hyprland-mock");
        verify(fixture.availableSessions.length >= 2);
        verify(!fixture.canPowerOff);
        verify(!fixture.networkAvailable);
        verify(!fixture.audioAvailable);
        verify(!fixture.batteryAvailable);
    }

    function test_secretPromptAndFailure() {
        controller.wake();
        verify(backend.active);
        compare(boundary.promptText, "Enter your password");
        authPanel.inputField.text = "wrong";
        authPanel.submit();
        compare(authResponseSpy.count, 1);
        compare(controller.phase, GreeterController.Authenticating);
        compare(authPanel.inputField.text, "");
        wait(90);
        compare(controller.phase, GreeterController.Failure);
        wait(430);
        compare(controller.phase, GreeterController.Auth);
        verify(backend.active);
        verify(boundary.responseRequired);
    }

    function test_multipleChallengesSwitchFromSecretToVisible() {
        backend.scenario = "multi-prompt";
        controller.wake();
        compare(boundary.promptText, "Enter your password");
        compare(boundary.echoResponse, false);
        compare(authPanel.inputField.echoMode, TextInput.Password);

        authPanel.inputField.text = "dummy-password";
        authPanel.submit();
        tryCompare(boundary, "promptText", "Enter OTP", 500);
        verify(boundary.responseRequired);
        compare(boundary.echoResponse, true);
        compare(authPanel.inputField.echoMode, TextInput.Normal);
        compare(authPanel.visiblePasswordDots, 0);

        authPanel.inputField.text = "123456";
        authPanel.submit();
        wait(90);
        compare(controller.phase, GreeterController.Success);
        compare(authPanel.inputField.text, "");
        compare(authResponseSpy.count, 2);
    }

    function test_failureAfterVisibleChallengeClearsEchoModeForRetry() {
        backend.scenario = "multi-prompt-failure";
        controller.wake();
        authPanel.inputField.text = "dummy-password";
        authPanel.submit();
        tryCompare(boundary, "promptText", "Enter OTP", 500);
        verify(boundary.echoResponse);

        authPanel.inputField.text = "123456";
        authPanel.submit();
        tryCompare(controller, "phase", GreeterController.Failure, 500);
        verify(!boundary.echoResponse);
        compare(authPanel.inputField.echoMode, TextInput.Password);
        tryCompare(controller, "phase", GreeterController.Auth, 800);
        verify(boundary.responseRequired);
        verify(!boundary.echoResponse);
    }

    function test_visiblePromptAndEmptyResponse() {
        backend.scenario = "visible-prompt";
        controller.wake();
        compare(boundary.promptText, "Enter one-time code");
        verify(boundary.responseRequired);
        verify(boundary.echoResponse);
        compare(authPanel.inputField.echoMode, TextInput.Normal);

        authPanel.inputField.text = "";
        authPanel.submit();
        compare(authResponseSpy.count, 1);
        wait(90);
        compare(controller.phase, GreeterController.Success);
    }

    function test_informationalAndRecoverableErrorMessages() {
        backend.scenario = "informational-message";
        controller.wake();
        compare(controller.statusMessage, "Touch your security key");
        verify(controller.statusMessageVisible);
        verify(!controller.statusMessageIsError);

        controller.returnToIdle();
        tryCompare(controller, "phase", GreeterController.Idle, 700);
        backend.scenario = "error-message";
        controller.wake();
        compare(controller.statusMessage, "Security key not detected");
        verify(controller.statusMessageVisible);
        verify(controller.statusMessageIsError);
        verify(boundary.responseRequired);
    }

    function test_multiPartPamNoticeAndPromptLabel() {
        backend.scenario = "faillock-messages";
        controller.wake();
        compare(controller.statusMessage, "The account is locked due to 3 failed logins. (10 minutes left to unlock)");
        verify(controller.statusMessageVisible);
        compare(boundary.promptText, "Enter your password");
        authPanel.inputField.text = "dummy";
        authPanel.submit();
        compare(boundary.messageBuffer, "");
    }

    function test_lateCallbackAfterCancelCannotAffectNewAttempt() {
        backend.scenario = "late-response-after-cancel";
        controller.wake();
        authPanel.inputField.text = "dummy";
        authPanel.submit();
        const cancelledGeneration = boundary.generation;
        controller.returnToIdle();
        tryCompare(controller, "phase", GreeterController.Idle, 700);

        controller.wake();
        verify(boundary.generation > cancelledGeneration);
        const newGeneration = boundary.generation;
        wait(280);
        compare(boundary.generation, newGeneration);
        verify(controller.phase === GreeterController.Wake || controller.phase === GreeterController.Auth);
        tryCompare(controller, "phase", GreeterController.Auth, 700);
        verify(boundary.responseRequired);
        verify(backend.active);
    }

    function test_duplicateFailureCallbackDoesNotCorruptRetry() {
        backend.scenario = "password-failure";
        controller.wake();
        authPanel.inputField.text = "dummy";
        authPanel.submit();
        const failedGeneration = boundary.generation;
        tryCompare(controller, "phase", GreeterController.Failure, 500);

        backend.failure("DUPLICATE FAILURE", failedGeneration);
        compare(controller.phase, GreeterController.Failure);
        tryCompare(controller, "phase", GreeterController.Auth, 800);
        verify(boundary.generation > failedGeneration);
        verify(boundary.responseRequired);
        verify(backend.active);
    }

    function test_backendDisappearingFailsClosed() {
        controller.wake();
        backend.disconnectBackend();
        compare(controller.phase, GreeterController.Failure);
        compare(boundary.attemptActive, false);
        verify(controller.statusMessageIsError);
        wait(430);
        compare(controller.phase, GreeterController.Auth);
        verify(!boundary.responseRequired);
    }

    function test_mockReadyToLaunchUsesExistingSuccessMotion() {
        backend.scenario = "password-success";
        controller.wake();
        authPanel.inputField.text = "dummy";
        authPanel.submit();
        wait(90);
        compare(controller.phase, GreeterController.Success);
        compare(previewSuccessSpy.count, 0);
        compare(authPanel.inputField.text, "");
        wait(1450);
        verify(controller.successProgress > .99);
        compare(backend.requestSessionLaunch(), false);
        compare(boundary.requestSessionLaunch(), false);
    }

    function test_cancelPreventsLateResult() {
        controller.wake();
        authPanel.inputField.text = "dummy";
        authPanel.submit();
        compare(controller.phase, GreeterController.Authenticating);
        controller.returnToIdle();
        wait(550);
        compare(controller.phase, GreeterController.Idle);
        verify(!backend.active);
        compare(controller.failureProgress, 0);
        compare(controller.successProgress, 0);
    }

    function test_ctrlEnterCannotRequestPreviewSuccess() {
        controller.wake();
        authPanel.focusInput();
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Return, Qt.ControlModifier);
        compare(previewSuccessSpy.count, 0);
        compare(authResponseSpy.count, 1);
        compare(controller.phase, GreeterController.Authenticating);
    }

    function test_optionalStatusDefaultsDoNotLoadUserServices() {
        compare(isolatedStatus.networkAvailable, false);
        compare(isolatedStatus.audioAvailable, false);
        compare(isolatedStatus.batteryAvailable, false);
    }
}
