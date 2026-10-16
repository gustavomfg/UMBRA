import QtQuick
import QtTest
import "../components"
import "../harness/mock"

TestCase {
    id: testCase
    name: "NocturneLaunchGate"
    when: windowShown
    visible: true
    width: 600
    height: 400

    GreeterController {
        id: controller
    }

    MockAuthenticator {
        id: backend
        scenario: "password-success"
        responseDelay: 20
        launchAccepted: true
    }

    AuthenticatorBridge {
        id: boundary
        controller: controller
        backend: backend
        selectedUser: "gate-fixture"
        selectedSession: "fixed-session"
    }

    // Stand-in for the QQuickWindow: counts update() calls and lets the test
    // emit frameSwapped explicitly.
    QtObject {
        id: fakeWindow
        property int updates: 0
        signal frameSwapped
        function update() {
            updates += 1;
        }
    }

    QtObject {
        id: fakeProbe
        property bool available: true
        property string unavailableReason: ""
        property int armCount: 0
        property int disarmCount: 0
        property var armedWindow: null
        property int nextToken: 1
        property int pendingToken: 0
        property bool refuseArm: false
        signal presented(int token, int flags)
        signal discarded(int token)
        signal failed(int token, string reason)
        function arm(window) {
            if (refuseArm)
                return 0;
            armCount += 1;
            armedWindow = window;
            pendingToken = nextToken++;
            return pendingToken;
        }
        function disarm() {
            disarmCount += 1;
            pendingToken = 0;
        }
    }

    property bool blackHeld: controller.successComplete

    SessionLaunchGate {
        id: gate
        controller: controller
        boundary: boundary
        window: fakeWindow
        blackHeld: testCase.blackHeld
        probe: fakeProbe
        presentationTimeout: 200
    }

    SignalSpy {
        id: markerSpy
        target: gate
        signalName: "transition"
    }

    SignalSpy {
        id: blockedSpy
        target: gate
        signalName: "blocked"
    }

    function init() {
        backend.scenario = "password-success";
        backend.launchAccepted = true;
        backend.launchRequests = 0;
        fakeProbe.available = true;
        fakeProbe.refuseArm = false;
        fakeProbe.armCount = 0;
        fakeProbe.disarmCount = 0;
        fakeProbe.pendingToken = 0;
        markerSpy.clear();
        blockedSpy.clear();
    }

    function cleanup() {
        if (!controller.isIdle)
            controller.returnToIdle();
        tryCompare(controller, "phase", GreeterController.Idle, 1000);
        gate.reset();
    }

    function markers() {
        const result = [];
        for (let i = 0; i < markerSpy.count; ++i)
            result.push(markerSpy.signalArguments[i][0]);
        return result;
    }

    function authenticateToBlackHold() {
        controller.wake();
        tryVerify(() => boundary.responseRequired, 500);
        controller.requestAuthentication("gate-fixture", "dummy");
        tryCompare(controller, "phase", GreeterController.Success, 500);
        tryVerify(() => controller.successComplete, 2500);
        tryCompare(gate, "gateState", "holding", 200);
    }

    function test_presentedBlackFrameLaunchesExactlyOnce() {
        authenticateToBlackHold();
        compare(fakeProbe.armCount, 0);
        fakeWindow.frameSwapped();
        compare(fakeProbe.armCount, 0);
        fakeWindow.frameSwapped();
        compare(fakeProbe.armCount, 1);
        compare(gate.gateState, "armed");
        compare(backend.launchRequests, 0);

        fakeProbe.presented(fakeProbe.pendingToken, 0);
        compare(backend.launchRequests, 1);
        compare(backend.lastLaunchGeneration, boundary.readyGeneration);
        compare(gate.gateState, "launching");
        compare(markers(), ["success-finished", "black-commit-armed", "black-commit-presented", "launch-requested"]);

        // A duplicate presentation event cannot launch twice.
        fakeProbe.presented(1, 0);
        compare(backend.launchRequests, 1);
        compare(boundary.requestSessionLaunch(boundary.readyGeneration), false);
        compare(backend.launchRequests, 1);
    }

    function test_noLaunchBeforeSuccessFinishes() {
        controller.wake();
        tryVerify(() => boundary.responseRequired, 500);
        controller.requestAuthentication("gate-fixture", "dummy");
        tryCompare(controller, "phase", GreeterController.Success, 500);
        verify(!controller.successComplete);
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        compare(fakeProbe.armCount, 0);
        compare(gate.gateState, "idle");
        compare(backend.launchRequests, 0);
    }

    function test_discardedFrameBlocksLaunch() {
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        fakeProbe.discarded(fakeProbe.pendingToken);
        compare(gate.gateState, "blocked");
        compare(blockedSpy.count, 1);
        compare(backend.launchRequests, 0);
    }

    function test_timeoutNeverGrantsLaunch() {
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        const token = fakeProbe.pendingToken;
        tryCompare(gate, "gateState", "blocked", 500);
        compare(backend.launchRequests, 0);
        // A presentation that arrives after the timeout is ignored.
        fakeProbe.presented(token, 0);
        compare(backend.launchRequests, 0);
    }

    function test_missingProbeBlocksLaunch() {
        fakeProbe.available = false;
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        compare(gate.gateState, "blocked");
        compare(backend.launchRequests, 0);
    }

    function test_probeRefusingSurfaceBlocksLaunch() {
        fakeProbe.refuseArm = true;
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        compare(gate.gateState, "blocked");
        compare(backend.launchRequests, 0);
    }

    function test_staleTokenIsIgnored() {
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        fakeProbe.presented(fakeProbe.pendingToken + 7, 0);
        compare(gate.gateState, "armed");
        compare(backend.launchRequests, 0);
    }

    function test_cancelWhileArmedBlocksLaunch() {
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        const token = fakeProbe.pendingToken;
        controller.returnToIdle();
        verify(fakeProbe.disarmCount >= 1);
        fakeProbe.presented(token, 0);
        compare(backend.launchRequests, 0);
    }

    function test_backendRefusalBlocks() {
        backend.launchAccepted = false;
        authenticateToBlackHold();
        fakeWindow.frameSwapped();
        fakeWindow.frameSwapped();
        fakeProbe.presented(fakeProbe.pendingToken, 0);
        compare(gate.gateState, "blocked");
        compare(backend.launchRequests, 0);
    }

    function test_bridgeRejectsWrongGeneration() {
        authenticateToBlackHold();
        compare(boundary.requestSessionLaunch(boundary.readyGeneration + 1), false);
        compare(boundary.requestSessionLaunch(), false);
        compare(backend.launchRequests, 0);
    }
}
