import QtQuick
import QtQuick.Effects
import "theme"

// Lock background: the desktop as it was just before locking (a grim
// screenshot taken by lock/umbra-lock), heavily blurred and darkened,
// with the planet blended over it. Without a screenshot, or if it fails to
// load, this is the plain black scene with the planet: never a broken frame.
Item {
    id: root

    // file:// URL of the screenshot, or "" for none.
    property url source: ""
    // This output's rectangle and the whole layout, in logical pixels, so a
    // multi-output screenshot can be cropped to the right part.
    property rect screenRect: Qt.rect(0, 0, width, height)
    property rect layoutRect: Qt.rect(0, 0, width, height)
    readonly property bool hasDesktop: shot.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        color: Theme.black
    }

    Image {
        id: shot
        source: root.source
        visible: false
        asynchronous: false
        cache: false
        smooth: true
        // Crop to this output; grim captures in physical pixels.
        readonly property real pixelScale: implicitWidth > 0 && root.layoutRect.width > 0 ? implicitWidth / root.layoutRect.width : 1
        sourceClipRect: implicitWidth > 0 ? Qt.rect((root.screenRect.x - root.layoutRect.x) * pixelScale, (root.screenRect.y - root.layoutRect.y) * pixelScale, root.screenRect.width * pixelScale, root.screenRect.height * pixelScale) : Qt.rect(0, 0, 0, 0)
        width: root.width
        height: root.height
    }

    // Downsample first: a quarter-size texture blurred reads as frosted glass
    // instead of a soft copy of the desktop.
    ShaderEffectSource {
        id: small
        sourceItem: shot
        hideSource: true
        // Static image: re-rendered only when it changes.
        live: true
        textureSize: Qt.size(Math.max(1, root.width / 4), Math.max(1, root.height / 4))
        visible: false
        width: root.width
        height: root.height
    }

    MultiEffect {
        anchors.fill: parent
        source: small
        visible: root.hasDesktop
        blurEnabled: true
        blur: 1
        blurMax: 64
        blurMultiplier: .6
        saturation: -.35
        autoPaddingEnabled: false
    }

    // Darken so the planet stays the brightest thing on screen.
    Rectangle {
        anchors.fill: parent
        visible: root.hasDesktop
        color: Theme.black
        opacity: .58
    }
}
