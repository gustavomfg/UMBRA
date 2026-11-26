import QtQuick
import "theme"

// Dark graphite card: the lock screen's only container style.
Rectangle {
    property real scaleFactor: 1
    radius: 20 * scaleFactor
    color: Qt.rgba(.067, .067, .086, .74)
    border.color: Theme.surfaceEdge
    border.width: 1
}
