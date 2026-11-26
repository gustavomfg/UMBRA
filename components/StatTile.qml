import QtQuick
import "theme"

// Compact status tile: small caption, value, optional hairline gauge.
LockCard {
    id: tile

    property string title: ""
    property string value: ""
    // 0..1, or -1 for no gauge.
    property real fraction: -1

    implicitWidth: 150 * scaleFactor
    implicitHeight: 66 * scaleFactor
    radius: 14 * scaleFactor

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16 * tile.scaleFactor
        anchors.rightMargin: 16 * tile.scaleFactor
        spacing: 5 * tile.scaleFactor

        Text {
            width: parent.width
            text: tile.title
            color: Theme.quiet
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 11 * tile.scaleFactor
            font.letterSpacing: 1.2 * tile.scaleFactor
            font.capitalization: Font.AllUppercase
        }
        Text {
            width: parent.width
            text: tile.value
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 16 * tile.scaleFactor
        }
        Rectangle {
            visible: tile.fraction >= 0
            width: parent.width
            height: 1
            color: Theme.outline
            Rectangle {
                height: 1
                width: parent.width * Math.max(0, Math.min(1, tile.fraction))
                color: Theme.secondary
                Behavior on width {
                    NumberAnimation {
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
