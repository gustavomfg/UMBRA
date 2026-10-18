import QtQuick

Item {
    id: root
    visible: false

    property var controller
    property bool active: false
    property bool responseRequired: false
    property int generation: 0
    property int responseDelay: 360

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
        responseRequired = true;
        generation = attemptGeneration;
        prompt("Enter your password", true, false, generation);
        return true;
    }

    function respond(response, attemptGeneration) {
        if (!active || !responseRequired || attemptGeneration !== generation)
            return false;

        // This preview discards the response and never evaluates it.
        void response;
        responseRequired = false;
        rejectionTimer.restart();
        response = "";
        return true;
    }

    function cancel(attemptGeneration) {
        if (attemptGeneration !== generation)
            return;
        rejectionTimer.stop();
        successTimer.stop();
        responseRequired = false;
        active = false;
    }

    function requestSessionLaunch() {
        return false;
    }

    Connections {
        target: root.controller

        function onPreviewSuccessRequested() {
            if (!root.active)
                return;
            rejectionTimer.stop();
            successTimer.restart();
        }
    }

    Timer {
        id: rejectionTimer
        interval: root.responseDelay
        repeat: false

        onTriggered: {
            if (!root.active)
                return;
            root.active = false;
            root.responseRequired = false;
            root.failure("BACKEND OFFLINE · PREVIEW ONLY", root.generation);
        }
    }

    Timer {
        id: successTimer
        interval: root.responseDelay
        repeat: false

        onTriggered: {
            if (root.active)
                root.readyToLaunch(root.generation);
        }
    }
}
