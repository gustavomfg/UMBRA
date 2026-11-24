import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io

// Caps Lock from the keyboard LEDs (/sys/class/leds/*::capslock, world
// readable) and the XKB layout the greeter compositor was started with.
// sysfs does not notify changes, so LEDs are re-read while `active`.
Item {
    id: root
    visible: false

    property bool active: true
    property int pollInterval: 250
    // XKB_DEFAULT_LAYOUT as given to Cage, e.g. "br" or "us,br".
    property string layout: ""
    readonly property bool capsLock: capsCount > 0
    property int capsCount: 0

    function refresh() {
        let lit = 0;
        for (let i = 0; i < leds.count; ++i) {
            const view = leds.objectAt(i);
            if (!view || !view.capsLed)
                continue;
            view.reload();
            if (Number(String(view.text()).trim()) > 0)
                lit += 1;
        }
        capsCount = lit;
    }

    FolderListModel {
        id: ledDirs
        folder: "file:///sys/class/leds"
        nameFilters: ["*::capslock"]
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
    }

    Instantiator {
        id: leds
        model: ledDirs
        delegate: FileView {
            required property string fileName
            // FolderListModel name filters do not apply to directories.
            readonly property bool capsLed: fileName.endsWith("::capslock")
            path: capsLed ? "/sys/class/leds/" + fileName + "/brightness" : ""
            blockLoading: true
            printErrors: false
        }
        onObjectAdded: root.refresh()
    }

    Timer {
        interval: root.pollInterval
        repeat: true
        running: root.active && leds.count > 0
        onTriggered: root.refresh()
    }
}
