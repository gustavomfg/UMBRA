import QtQuick

Item {
    id: root
    required property Item targetItem
    required property var controller
    required property var authPanel
    required property var chrome
    required property string outputDirectory
    required property string selectedState
    property int step: 0
    // "failure-at" / "wait-at": capture this many ms after the rejection /
    // after Enter, for frame sequences of the failure motion.
    property int offset: 0
    function capture(name) {
        if (name !== selectedState)
            return;
        sequence.stop();
        const tag = name === "failure-at" || name === "wait-at" ? name + "-" + String(offset).padStart(4, "0") : name;
        targetItem.grabToImage(function (result) {
            const path = outputDirectory + "/" + targetItem.width + "x" + targetItem.height + "-" + tag + ".png";
            if (!result.saveToFile(path))
                console.error("Capture failed:", path);
            else
                console.info("Captured", path);
            Qt.quit();
        });
    }
    Timer {
        id: offsetTimer
        repeat: false
        onTriggered: root.capture(root.selectedState)
    }
    Connections {
        target: root.controller
        function onPhaseChanged() {
            if (root.selectedState === "failure-at" && root.controller.phase === GreeterController.Failure)
                offsetTimer.restart();
        }
    }
    Timer {
        id: sequence
        interval: 700
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                if (root.selectedState === "idle-long") {
                    interval = 30000;
                    break;
                }
                root.capture("idle");
                interval = 250;
                break;
            case 1:
                if (root.selectedState === "idle-long") {
                    root.capture("idle-long");
                    break;
                }
                root.controller.wake();
                interval = root.selectedState === "wake-middle" ? 350 : 180;
                break;
            case 2:
                root.capture(root.selectedState === "wake-middle" ? "wake-middle" : "wake");
                interval = 950;
                break;
            case 3:
                if (root.selectedState === "auth-long") {
                    interval = 30000;
                    break;
                }
                root.capture("auth");
                if (root.selectedState === "return-middle")
                    root.controller.returnToIdle();
                interval = root.selectedState === "return-middle" ? 220 : 250;
                break;
            case 4:
                if (root.selectedState === "auth-long") {
                    root.capture("auth-long");
                    break;
                }
                if (root.selectedState === "return-middle") {
                    root.capture("return-middle");
                    break;
                }
                if (root.selectedState === "power")
                    root.chrome.powerMenuOpen = true;
                else if (root.selectedState === "session")
                    root.chrome.sessionMenuOpen = true;
                else if (root.selectedState === "typing-long")
                    root.authPanel.inputField.text = "x".repeat(80);
                else {
                    root.authPanel.inputField.text = "preview";
                    root.controller.noteKey();
                }
                interval = root.selectedState === "power" || root.selectedState === "session" ? 320 : 60;
                break;
            case 5:
                root.capture(root.selectedState === "power" ? "power" : root.selectedState === "session" ? "session" : root.selectedState === "typing-long" ? "typing-long" : "typing");
                interval = 200;
                break;
            case 6:
                root.authPanel.submit();
                if (root.selectedState === "failure-at" || root.selectedState === "wait-at") {
                    offsetTimer.interval = Math.max(1, root.offset);
                    if (root.selectedState === "wait-at")
                        offsetTimer.restart();
                    sequence.stop();
                    break;
                }
                interval = root.selectedState === "submit-feedback" ? 90 : root.selectedState === "authenticating" ? 180 : root.selectedState === "failure" ? 510 : 450;
                break;
            case 7:
                root.capture(root.selectedState === "submit-feedback" ? "submit-feedback" : "authenticating");
                interval = root.selectedState === "failure" ? 20 : 540;
                break;
            case 8:
                root.capture("failure");
                interval = 800;
                break;
            case 9:
                root.authPanel.submit(true);
                interval = 740;
                break;
            case 10:
                root.capture("collapse");
                interval = 850;
                break;
            case 11:
                root.capture("black");
                stop();
                break;
            }
        }
    }
}
