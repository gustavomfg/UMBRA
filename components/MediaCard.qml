pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "theme"

// Now-playing card. Hidden when no MPRIS player is running. Prefers a
// player that is playing, then Spotify, then whichever is first.
Item {
    id: card

    property real scaleFactor: 1
    // Preview/captures only: a stand-in with the MPRIS fields used here.
    property var previewPlayer: null
    property bool preferPreview: false
    signal interacted

    readonly property var player: {
        const list = Mpris.players.values;
        let playing = null;
        let spotify = null;
        for (let i = 0; i < list.length; ++i) {
            const candidate = list[i];
            if (candidate.isPlaying && !playing)
                playing = candidate;
            if (!spotify && (candidate.identity === "Spotify" || candidate.desktopEntry === "spotify"))
                spotify = candidate;
        }
        const found = playing ? playing : spotify ? spotify : (list.length > 0 ? list[0] : null);
        return preferPreview && previewPlayer ? previewPlayer : found ? found : previewPlayer;
    }
    readonly property bool shown: player !== null && player.trackTitle.length > 0
    readonly property real artSize: 48 * scaleFactor

    implicitHeight: shown ? artSize : 0
    height: implicitHeight
    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 360
            easing.type: Easing.InOutSine
        }
    }

    // MPRIS only notifies position when asked.
    Timer {
        interval: 1000
        repeat: true
        running: card.shown && card.player.isPlaying
        onTriggered: card.player.positionChanged()
    }

    Rectangle {
        id: artFrame
        width: card.artSize
        height: card.artSize
        radius: 8 * card.scaleFactor
        color: Theme.graphite
        border.color: Theme.surfaceEdge
        border.width: 1

        Image {
            id: art
            anchors.fill: parent
            anchors.margins: 1
            source: card.shown ? card.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(card.artSize * 2, card.artSize * 2)
            visible: false
            layer.enabled: true
        }
        Rectangle {
            id: artMask
            anchors.fill: art
            radius: 7 * card.scaleFactor
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: art
            source: art
            maskEnabled: true
            maskSource: artMask
            visible: art.status === Image.Ready
            opacity: card.shown && card.player.isPlaying ? 1 : .55
            Behavior on opacity {
                NumberAnimation {
                    duration: 260
                }
            }
        }
    }

    Column {
        id: text
        anchors.left: artFrame.right
        anchors.leftMargin: 16 * card.scaleFactor
        anchors.right: controls.left
        anchors.rightMargin: 10 * card.scaleFactor
        anchors.top: artFrame.top
        anchors.topMargin: 2 * card.scaleFactor
        spacing: 3 * card.scaleFactor

        Text {
            width: parent.width
            text: card.shown ? card.player.trackTitle : ""
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 14 * card.scaleFactor
        }
        Text {
            width: parent.width
            text: card.shown ? card.player.trackArtist : ""
            color: Theme.secondary
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 13 * card.scaleFactor
        }
    }

    // Hairline progress in the quiet tone (lilac is reserved for focus/feedback).
    Rectangle {
        anchors.left: text.left
        anchors.right: text.right
        anchors.bottom: artFrame.bottom
        anchors.bottomMargin: 2 * card.scaleFactor
        height: 1
        color: Theme.outline
        visible: card.shown && card.player.lengthSupported && card.player.length > 0

        Rectangle {
            height: 1
            color: Theme.secondary
            width: card.shown && card.player.length > 0 ? parent.width * Math.max(0, Math.min(1, card.player.position / card.player.length)) : 0
            Behavior on width {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.Linear
                }
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: artFrame.verticalCenter
        spacing: 0
        IconButton {
            icon: Qt.resolvedUrl("../assets/icons/media-prev.svg")
            label: Strings.previous
            scaleFactor: card.scaleFactor * .8
            enabled: card.shown && card.player.canGoPrevious
            onClicked: {
                card.player.previous();
                card.interacted();
            }
        }
        IconButton {
            icon: card.shown && card.player.isPlaying ? Qt.resolvedUrl("../assets/icons/media-pause.svg") : Qt.resolvedUrl("../assets/icons/media-play.svg")
            label: Strings.playPause
            scaleFactor: card.scaleFactor * .8
            enabled: card.shown && card.player.canTogglePlaying
            onClicked: {
                card.player.togglePlaying();
                card.interacted();
            }
        }
        IconButton {
            icon: Qt.resolvedUrl("../assets/icons/media-next.svg")
            label: Strings.next
            scaleFactor: card.scaleFactor * .8
            enabled: card.shown && card.player.canGoNext
            onClicked: {
                card.player.next();
                card.interacted();
            }
        }
    }
}
