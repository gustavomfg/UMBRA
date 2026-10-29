import QtQuick
import "components"

// Drives the pre-login entrypoint through one successful fixture login. Used
// only by scripts/test-launch-gate-e2e.sh; never staged for a real greeter.
Item {
    id: root
    visible: false

    property var controller
    property var chrome
    property var authPanel

    Timer {
        interval: 600
        running: true
        onTriggered: {
            function find(item, name) {
                if (item.objectName === name) return item;
                for (let child of item.children || []) {
                    const found = find(child, name);
                    if (found) return found;
                }
                return null;
            }
            const network = find(root.chrome, "networkIndicator");
            const audio = find(root.chrome, "audioIndicator");
            if (!network || !audio || !network.visible || !audio.visible
                    || network.interactive || audio.interactive) {
                console.error("e2e: status indicators missing or interactive");
                Qt.exit(1);
                return;
            }
            console.info("e2e: status indicators visible and read-only");
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
