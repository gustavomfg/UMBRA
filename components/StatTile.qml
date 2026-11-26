import QtQuick
import "theme"

// Compact reading inside the lock panel: caption, value, optional hairline
// gauge. No card of its own; the panel is the only container.
Item {
    id: tile

    property real scaleFactor: 1
    property string title: ""
    property string value: ""
    // 0..1, or -1 for no gauge.
    property real fraction: -1

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4 * tile.scaleFactor

        Text {
            width: parent.width
            text: tile.title
            color: Theme.quiet
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 10 * tile.scaleFactor
            font.letterSpacing: 1.1 * tile.scaleFactor
            font.capitalization: Font.AllUppercase
        }
        Text {
            width: parent.width
            text: tile.value
            color: Theme.secondary
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 13 * tile.scaleFactor
        }
        Item {
            width: parent.width
            height: 3 * tile.scaleFactor
            Rectangle {
                visible: tile.fraction >= 0
                anchors.bottom: parent.bottom
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
}
