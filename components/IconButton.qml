import QtQuick

Item {
    id: root
    property string icon: ""
    property string label: ""
    property real scaleFactor: 1
    property bool selected: false
    property bool interactive: true
    signal clicked
    implicitWidth: 40 * scaleFactor
    implicitHeight: 40 * scaleFactor
    activeFocusOnTab: interactive
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: label
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#111116"
        opacity: root.activeFocus || pointer.containsMouse || root.selected ? 1 : 0
        border.color: root.activeFocus ? "#A78BFA" : "#34343D"
        border.width: root.activeFocus ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }
    Image {
        anchors.centerIn: parent
        width: 19 * root.scaleFactor
        height: width
        source: root.icon
        sourceSize: Qt.size(width * 2, height * 2)
        opacity: root.enabled ? (pointer.containsMouse || root.activeFocus ? 1 : .8) : .35
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
        scale: pointer.pressed ? .92 : 1
        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled && root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.interactive) {
                root.forceActiveFocus();
                root.clicked();
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: 9
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltip.implicitWidth + 20
        height: 30
        radius: 5
        color: "#111116"
        readonly property bool shown: pointer.containsMouse && root.label.length > 0 && !root.selected
        opacity: shown ? 1 : 0
        visible: opacity > .001
        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        Text {
            id: tooltip
            anchors.centerIn: parent
            text: root.label
            color: "#A6A6B0"
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }
}
