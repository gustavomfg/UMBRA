import QtQuick
import "theme"

// Rim of the lock's glass panel: thin edge over the frosted backdrop.
Rectangle {
    property real scaleFactor: 1
    radius: 22 * scaleFactor
    // Graphite (#111116) at 55 %: the blurred scene still shows through.
    color: Qt.rgba(Theme.graphite.r, Theme.graphite.g, Theme.graphite.b, .55)
    border.color: Theme.surfaceEdge
    border.width: 1
}
