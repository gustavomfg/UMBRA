import QtQuick
import "components"

// Drives the pre-login entrypoint through one successful fixture login. Used
// only by scripts/test-launch-gate-e2e.sh; never staged for a real greeter.
Item {
    id: root
    visible: false

    property var controller
    property var authPanel

    Timer {
        interval: 600
        running: true
        onTriggered: {
            console.info("e2e: wake");
            root.controller.wake();
            submitTimer.start();
        }
    }

    Timer {
        id: submitTimer
        interval: 1200
        onTriggered: {
            console.info("e2e: submit");
            root.authPanel.inputField.text = "fixture-response";
            root.authPanel.submit();
        }
    }
}
