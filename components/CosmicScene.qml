import QtQuick

Item {
    id: root

    property real time: 0
    property real authProgress: 0
    property real wakePulse: 0
    property real typingPulse: 0
    property real failureProgress: 0
    property real successProgress: 0
    property real authenticationTension: 0

    ShaderEffect {
        anchors.fill: parent

        property real time: root.time
        property vector2d resolution: Qt.vector2d(width, height)
        property real authProgress: root.authProgress
        property real wakePulse: root.wakePulse
        property real typingPulse: root.typingPulse
        property real failureProgress: root.failureProgress
        property real successProgress: root.successProgress
        property real authenticationTension: root.authenticationTension

        fragmentShader: Qt.resolvedUrl("../shaders/pulse.frag.qsb")
    }
}
