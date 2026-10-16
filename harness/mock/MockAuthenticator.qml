import QtQuick

Item {
    id: root
    visible: false

    property bool active: false
    property bool responseRequired: false
    property string scenario: "password-failure"
    property int responseDelay: 360
    property int generation: 0
    property int promptCount: 0
    property int lateGeneration: 0

    signal prompt(string message, bool responseRequired, bool echoResponse, int attemptGeneration)
    signal message(string message, bool error, int attemptGeneration)
    signal failure(string message, int attemptGeneration)
    signal readyToLaunch(int attemptGeneration)
    signal backendError(string message, int attemptGeneration)
    signal launched(int attemptGeneration)

    function begin(user, session, attemptGeneration) {
        void user;
        void session;
        active = true;
        responseRequired = false;
        generation = attemptGeneration;
        promptCount = 0;

        if (scenario === "informational-message")
            message("Touch your security key", false, generation);
        else if (scenario === "error-message")
            message("Security key not detected", true, generation);

        promptCount = 1;
        if (scenario === "visible-prompt")
            prompt("Enter one-time code", true, true, generation);
        else
            prompt("Enter your password", true, false, generation);
        responseRequired = true;
        return true;
    }

    function respond(response, attemptGeneration) {
        if (!active || !responseRequired || attemptGeneration !== generation)
            return false;

        // Keep only protocol state. Never retain, compare, or print the value.
        void response;
        responseRequired = false;
        resultGeneration = attemptGeneration;
        resultTimer.restart();
        response = "";
        return true;
    }

    function cancel(attemptGeneration) {
        if (attemptGeneration !== generation)
            return;

        active = false;
        responseRequired = false;
        resultTimer.stop();
        if (scenario === "late-response-after-cancel") {
            lateGeneration = attemptGeneration;
            lateTimer.restart();
        }
    }

    // Tests opt in; the isolated harness never launches anything.
    property bool launchAccepted: false
    property int launchRequests: 0
    property int lastLaunchGeneration: 0

    function requestSessionLaunch(attemptGeneration) {
        if (!launchAccepted || attemptGeneration === undefined || attemptGeneration !== generation)
            return false;
        launchRequests += 1;
        lastLaunchGeneration = attemptGeneration;
        return true;
    }

    function disconnectBackend() {
        if (!active)
            return;
        active = false;
        responseRequired = false;
        resultTimer.stop();
        backendError("MOCK BACKEND DISCONNECTED", generation);
    }

    property int resultGeneration: 0

    Timer {
        id: resultTimer
        interval: root.responseDelay
        repeat: false

        onTriggered: {
            if (!root.active || root.resultGeneration !== root.generation)
                return;

            if ((root.scenario === "multi-prompt" || root.scenario === "multi-prompt-failure") && root.promptCount === 1) {
                root.promptCount = 2;
                root.responseRequired = true;
                root.prompt("Enter OTP", true, true, root.generation);
                return;
            }

            root.responseRequired = false;
            if (root.scenario === "password-failure" || root.scenario === "multi-prompt-failure") {
                root.active = false;
                root.failure("AUTHENTICATION FAILED · MOCK", root.generation);
            } else {
                root.readyToLaunch(root.generation);
            }
        }
    }

    Timer {
        id: lateTimer
        interval: 700
        repeat: false

        onTriggered: root.failure("LATE MOCK CALLBACK", root.lateGeneration)
    }
}
