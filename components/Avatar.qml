import QtQuick
import QtQuick.Effects
import "theme"

// Round user picture (~/.face); falls back to the initial.
Item {
    id: root

    property string source: ""
    property string name: ""
    property real size: 44

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.graphite
        border.color: Theme.surfaceEdge
        border.width: 1
    }
    Text {
        anchors.centerIn: parent
        visible: face.status !== Image.Ready
        text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : ""
        color: Theme.secondary
        font.family: Theme.sans
        font.pixelSize: root.size * .42
    }
    Image {
        id: face
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        visible: false
        layer.enabled: true
    }
    Rectangle {
        id: faceMask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: face
        maskEnabled: true
        maskSource: faceMask
        visible: face.status === Image.Ready
    }
}
