import QtQuick
import Quickshell.Networking

// NetworkManager is a system service and can be observed before login.
// Audio belongs to the authenticated user's session: never connect to that
// user's PipeWire socket, launch a daemon or manufacture a volume reading.
QtObject {
    property string desktopSession: "Local session"
    readonly property var devices: Networking.devices
    readonly property bool networkAvailable: Networking.backend === NetworkBackendType.NetworkManager
                                            && devices !== null && devices.values.length > 0
    readonly property bool online: networkAvailable && devices.values.some(device => device.connected)
    readonly property bool audioAvailable: false
    readonly property bool audioMuted: false
    readonly property int volumePercent: 0
    readonly property bool batteryAvailable: false
    readonly property int batteryPercent: 0
}
