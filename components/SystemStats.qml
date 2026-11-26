import QtQuick
import Quickshell
import Quickshell.Io

// Numbers for the lock screen cards, sampled every few seconds by
// lock/umbra-lock-stats. -1 / "none" means the probe is unavailable.
Item {
    id: root
    visible: false

    property bool active: true
    property int uptimeSeconds: 0
    property int cpu: -1
    property int ram: -1
    property real ramGb: 0
    property int gpu: -1
    property string netType: "none"
    property string netName: ""
    property string btState: "none"
    property string btDevice: ""

    function number(value) {
        const n = parseInt(value);
        return isNaN(n) ? -1 : n;
    }

    function parse(text) {
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const at = lines[i].indexOf("=");
            if (at < 0)
                continue;
            const key = lines[i].slice(0, at);
            const value = lines[i].slice(at + 1).trim();
            const parts = value.split("|");
            if (key === "uptime")
                uptimeSeconds = Math.max(0, number(value));
            else if (key === "cpu")
                cpu = number(value);
            else if (key === "ram")
                ram = number(value);
            else if (key === "ramgb")
                ramGb = Number(value) || 0;
            else if (key === "gpu")
                gpu = number(value);
            else if (key === "net") {
                netType = parts[0] || "none";
                netName = parts.slice(1).join("|");
            } else if (key === "bt") {
                btState = parts[0] || "none";
                btDevice = parts.slice(1).join("|");
            }
        }
    }

    Process {
        id: sampler
        command: ["bash", Quickshell.shellPath("lock/umbra-lock-stats")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
        }
    }
}
