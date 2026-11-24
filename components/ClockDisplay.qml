import QtQuick
import Quickshell
import "theme"

Item {
    id: root
    property real scaleFactor: 1
    property real authProgress: 0
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Column {
        spacing: 9 * root.scaleFactor
        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: 88 * root.scaleFactor
            font.weight: Font.Light
            font.letterSpacing: -3 * root.scaleFactor
        }
        Text {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.secondary
            font.family: Theme.sans
            font.pixelSize: 14 * root.scaleFactor
        }
    }
}
