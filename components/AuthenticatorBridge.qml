import QtQuick

Item {
    id: root
    visible: false

    property var controller
    property var backend
    property string selectedUser: ""
    property string selectedSession: ""
    property string promptText: "Enter your password"
    property bool responseRequired: false
    property bool echoResponse: false
    property int promptSerial: 0
    property int generation: 0
    property bool attemptActive: false
    property bool retryAfterFailure: false
    // Generation that reached readyToLaunch; 0 when no attempt is ready.
    property int readyGeneration: 0
    property bool launchRequested: false

    signal sessionLaunched(int attemptGeneration)

    function beginIfNeeded(userHint) {
        if (attemptActive)
            return true;

        if (!backend || typeof backend.begin !== "function") {
            controller.rejectAuthentication("Authentication backend unavailable");
            return false;
        }

        generation += 1;
        const thisGeneration = generation;
        const userId = userHint || selectedUser;
        responseRequired = false;
        echoResponse = false;
        attemptActive = true;
        retryAfterFailure = false;
        readyGeneration = 0;
        launchRequested = false;

        const started = backend.begin(userId, selectedSession, thisGeneration);
        if (started === false && generation === thisGeneration) {
            attemptActive = false;
            responseRequired = false;
            controller.rejectAuthentication("Authentication backend unavailable");
            return false;
        }
        return true;
    }

    function cancelAttempt() {
        if (!attemptActive)
            return;

        const cancelledGeneration = generation;
        generation += 1;
        attemptActive = false;
        retryAfterFailure = false;
        responseRequired = false;
        echoResponse = false;
        readyGeneration = 0;

        if (backend && typeof backend.cancel === "function")
            backend.cancel(cancelledGeneration);
    }

    // Only SessionLaunchGate calls this, after the black frame was presented.
    function requestSessionLaunch(attemptGeneration) {
        if (attemptGeneration === undefined || attemptGeneration !== readyGeneration || attemptGeneration !== generation)
            return false;
        if (!attemptActive || launchRequested)
            return false;
        if (!backend || typeof backend.requestSessionLaunch !== "function")
            return false;

        launchRequested = true;
        return backend.requestSessionLaunch(attemptGeneration) === true;
    }

    Connections {
        target: root.controller

        function onPhaseChanged() {
            if (!root.controller || !root.backend)
                return;

            if (root.controller.phase === GreeterController.Wake)
                root.beginIfNeeded();
            else if (root.controller.phase === GreeterController.ReturnToIdle
                     || root.controller.phase === GreeterController.Idle)
                root.cancelAttempt();
            else if (root.controller.phase === GreeterController.Auth && root.retryAfterFailure)
                root.beginIfNeeded();
        }

        function onAuthenticationRequested(username, response) {
            if (!root.attemptActive && !root.beginIfNeeded(username))
                return;
            if (!root.responseRequired || !root.backend || typeof root.backend.respond !== "function")
                return;

            const thisGeneration = root.generation;
            root.responseRequired = false;
            root.echoResponse = false;
            root.backend.respond(response, thisGeneration);
            response = "";
        }
    }

    Connections {
        target: root.backend

        function onPrompt(message, responseRequired, echoResponse, attemptGeneration) {
            if (!root.attemptActive || attemptGeneration !== root.generation)
                return;
            if (!responseRequired)
                return;

            root.promptText = message;
            root.responseRequired = true;
            root.echoResponse = echoResponse;
            root.promptSerial += 1;
            root.controller.presentPrompt(message, true, echoResponse);
        }

        function onMessage(message, error, attemptGeneration) {
            if (!root.attemptActive || attemptGeneration !== root.generation)
                return;
            root.controller.presentMessage(message, error);
        }

        function onFailure(message, attemptGeneration) {
            if (!root.attemptActive || attemptGeneration !== root.generation)
                return;

            root.attemptActive = false;
            root.responseRequired = false;
            root.echoResponse = false;
            root.retryAfterFailure = true;
            root.readyGeneration = 0;
            root.controller.rejectAuthentication(message);
        }

        function onReadyToLaunch(attemptGeneration) {
            if (!root.attemptActive || attemptGeneration !== root.generation)
                return;

            root.responseRequired = false;
            root.echoResponse = false;
            root.retryAfterFailure = false;
            root.readyGeneration = attemptGeneration;
            root.controller.completeAuthentication();
        }

        function onLaunched(attemptGeneration) {
            if (!root.launchRequested || attemptGeneration !== root.readyGeneration)
                return;
            root.sessionLaunched(attemptGeneration);
        }

        function onBackendError(message, attemptGeneration) {
            if (!root.attemptActive || attemptGeneration !== root.generation)
                return;

            root.attemptActive = false;
            root.responseRequired = false;
            root.echoResponse = false;
            root.retryAfterFailure = false;
            root.readyGeneration = 0;
            root.controller.rejectAuthentication(message);
        }
    }
}
