pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property real scaleFactor: 1
    property real leftMargin: 32
    property real rightMargin: 32
    property string hostname: "Local system"
    property string desktopSession: "Local session"
    property string sessionContextText: "Selected session"
    property string powerUnavailableText: "Unavailable"
    property bool networkAvailable: false
    property bool online: false
    property bool audioAvailable: false
    property bool audioMuted: false
    property int volumePercent: 0
    property bool batteryAvailable: false
    property int batteryPercent: 0
    property var controller
    property bool powerMenuOpen: false
    property bool sessionMenuOpen: false
    property bool userMenuOpen: false
    // Selectable options; empty lists keep the read-only preview behaviour.
    property var sessionOptions: []
    property int selectedSessionIndex: -1
    property var userOptions: []
    property int selectedUserIndex: -1
    property bool userSelectionEnabled: true
    property bool powerActionsEnabled: false
    signal sessionChosen(int index)
    signal userChosen(int index)
    signal powerActionRequested(string action)
    function dismissMenus() {
        const wasOpen = powerMenuOpen || sessionMenuOpen || userMenuOpen;
        powerMenuOpen = false;
        sessionMenuOpen = false;
        userMenuOpen = false;
        return wasOpen;
    }
    Connections {
        target: root.controller
        function onPhaseChanged() {
            root.dismissMenus();
        }
    }
    Row {
        x: root.leftMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18 * root.scaleFactor
        Text {
            text: root.hostname
            width: Math.min(implicitWidth, root.width * .18)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            color: "#777781"
            font.family: "Adwaita Sans"
            font.pixelSize: 12 * root.scaleFactor
        }
        Rectangle {
            width: 1
            height: 12 * root.scaleFactor
            color: "#34343D"
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            id: userButton
            objectName: "userButton"
            visible: root.userOptions.length > 1 && root.userSelectionEnabled
            width: userLabel.implicitWidth + 24 * root.scaleFactor
            height: 40 * root.scaleFactor
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button
            Accessible.name: "User: " + userLabel.text
            function activate() {
                root.userMenuOpen = !root.userMenuOpen;
                root.sessionMenuOpen = false;
                root.powerMenuOpen = false;
            }
            Keys.onReturnPressed: activate()
            Keys.onSpacePressed: activate()
            Text {
                id: userLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.selectedUserIndex >= 0 && root.selectedUserIndex < root.userOptions.length ? root.userOptions[root.selectedUserIndex].displayName : ""
                color: userMouse.containsMouse || userButton.activeFocus ? "#F2F2F3" : "#A6A6B0"
                font.family: "Adwaita Sans"
                font.pixelSize: 12 * root.scaleFactor
            }
            Image {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * root.scaleFactor
                height: width
                source: "../assets/icons/chevron.svg"
                rotation: root.userMenuOpen ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                id: userMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    userButton.forceActiveFocus();
                    userButton.activate();
                }
            }
        }
        Rectangle {
            visible: userButton.visible
            width: 1
            height: 12 * root.scaleFactor
            color: "#34343D"
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            id: sessionButton
            width: sessionLabel.implicitWidth + 24 * root.scaleFactor
            height: 40 * root.scaleFactor
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Session: " + root.desktopSession
            function activate() {
                root.sessionMenuOpen = !root.sessionMenuOpen;
                root.powerMenuOpen = false;
                root.userMenuOpen = false;
            }
            Keys.onReturnPressed: activate()
            Keys.onSpacePressed: activate()
            Text {
                id: sessionLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.desktopSession
                color: sessionMouse.containsMouse || sessionButton.activeFocus ? "#F2F2F3" : "#A6A6B0"
                font.family: "Adwaita Sans"
                font.pixelSize: 12 * root.scaleFactor
            }
            Image {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * root.scaleFactor
                height: width
                source: "../assets/icons/chevron.svg"
                rotation: root.sessionMenuOpen ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sessionButton.forceActiveFocus();
                    sessionButton.activate();
                }
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.rightMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * root.scaleFactor
        IconButton {
            visible: root.networkAvailable
            icon: "../assets/icons/network.svg"
            label: root.online ? "Connected" : "No connection"
            scaleFactor: root.scaleFactor
            interactive: false
        }
        IconButton {
            visible: root.audioAvailable
            icon: root.audioMuted ? "../assets/icons/muted.svg" : "../assets/icons/audio.svg"
            label: root.audioMuted ? "Muted" : "Volume " + root.volumePercent + "%"
            scaleFactor: root.scaleFactor
            interactive: false
        }
        IconButton {
            visible: root.batteryAvailable
            icon: "../assets/icons/battery.svg"
            label: root.batteryPercent + "% battery"
            scaleFactor: root.scaleFactor
            interactive: false
        }
        Item {
            width: 14 * root.scaleFactor
            height: 1
        }
        IconButton {
            id: powerButton
            objectName: "powerButton"
            icon: "../assets/icons/power.svg"
            label: "Power"
            scaleFactor: root.scaleFactor
            selected: root.powerMenuOpen
            onClicked: {
                root.powerMenuOpen = !root.powerMenuOpen;
                root.sessionMenuOpen = false;
                root.userMenuOpen = false;
            }
        }
    }
    Rectangle {
        id: powerMenu
        anchors.right: parent.right
        anchors.rightMargin: root.rightMargin
        y: -height - 8 * root.scaleFactor + (1 - opacity) * 10
        width: 220 * root.scaleFactor
        height: powerColumn.implicitHeight + 36 * root.scaleFactor
        radius: 10 * root.scaleFactor
        color: "#111116"
        border.width: 1
        border.color: "#292930"
        visible: opacity > .001
        opacity: root.powerMenuOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        Column {
            id: powerColumn
            x: 18 * root.scaleFactor
            y: 18 * root.scaleFactor
            width: parent.width - 36 * root.scaleFactor
            spacing: 15 * root.scaleFactor
            Repeater {
                model: [
                    {
                        name: "Sleep",
                        icon: "moon",
                        action: "suspend"
                    },
                    {
                        name: "Restart",
                        icon: "restart",
                        action: "reboot"
                    },
                    {
                        name: "Shut down",
                        icon: "power",
                        action: "poweroff"
                    }
                ]
                delegate: Item {
                    id: powerRow
                    required property var modelData
                    objectName: "power-" + modelData.action
                    width: powerRowContent.implicitWidth
                    height: powerRowContent.implicitHeight
                    opacity: root.powerActionsEnabled ? (powerRowMouse.containsMouse ? 1 : .82) : .5
                    Row {
                        id: powerRowContent
                        spacing: 12 * root.scaleFactor
                        Image {
                            source: "../assets/icons/" + powerRow.modelData.icon + ".svg"
                            width: 17 * root.scaleFactor
                            height: width
                        }
                        Text {
                            text: powerRow.modelData.name
                            color: "#A6A6B0"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 13 * root.scaleFactor
                        }
                    }
                    MouseArea {
                        id: powerRowMouse
                        anchors.fill: parent
                        enabled: root.powerActionsEnabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dismissMenus();
                            root.powerActionRequested(powerRow.modelData.action);
                        }
                    }
                }
            }
            Text {
                visible: !root.powerActionsEnabled
                text: root.powerUnavailableText
                color: "#777781"
                font.family: "Adwaita Sans"
                font.pixelSize: 11 * root.scaleFactor
            }
        }
    }
    component OptionMenu: Rectangle {
        id: menu
        property var options: []
        property int selectedIndex: -1
        property string labelKey: "name"
        property bool open: false
        signal chosen(int index)
        y: -height - 8 * root.scaleFactor + (1 - opacity) * 10
        width: 260 * root.scaleFactor
        height: optionColumn.implicitHeight + 24 * root.scaleFactor
        radius: 10 * root.scaleFactor
        color: "#111116"
        border.width: 1
        border.color: "#292930"
        visible: opacity > .001
        opacity: open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        Column {
            id: optionColumn
            x: 8 * root.scaleFactor
            y: 12 * root.scaleFactor
            width: parent.width - 16 * root.scaleFactor
            spacing: 2 * root.scaleFactor
            Repeater {
                model: menu.options
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    required property int index
                    width: optionColumn.width
                    height: 34 * root.scaleFactor
                    radius: 7 * root.scaleFactor
                    color: optionMouse.containsMouse ? "#1C1C24" : "transparent"
                    Text {
                        x: 12 * root.scaleFactor
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40 * root.scaleFactor
                        elide: Text.ElideRight
                        text: option.modelData[menu.labelKey]
                        color: option.index === menu.selectedIndex ? "#F2F2F3" : "#A6A6B0"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13 * root.scaleFactor
                    }
                    Image {
                        visible: option.index === menu.selectedIndex
                        anchors.right: parent.right
                        anchors.rightMargin: 10 * root.scaleFactor
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.scaleFactor
                        height: width
                        source: "../assets/icons/check.svg"
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: menu.open
                        onClicked: {
                            root.dismissMenus();
                            menu.chosen(option.index);
                        }
                    }
                }
            }
        }
    }
    OptionMenu {
        objectName: "userMenu"
        x: root.leftMargin
        options: root.userOptions
        selectedIndex: root.selectedUserIndex
        labelKey: "displayName"
        open: root.userMenuOpen
        onChosen: index => root.userChosen(index)
    }
    OptionMenu {
        objectName: "sessionMenu"
        x: root.leftMargin
        visible: opacity > .001 && root.sessionOptions.length > 0
        options: root.sessionOptions
        selectedIndex: root.selectedSessionIndex
        open: root.sessionMenuOpen && root.sessionOptions.length > 0
        onChosen: index => root.sessionChosen(index)
    }
    Rectangle {
        x: root.leftMargin
        y: -height - 8 * root.scaleFactor + (1 - opacity) * 10
        width: 240 * root.scaleFactor
        height: 96 * root.scaleFactor
        radius: 10 * root.scaleFactor
        color: "#111116"
        border.width: 1
        border.color: "#292930"
        visible: opacity > .001
        opacity: root.sessionMenuOpen && root.sessionOptions.length === 0 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        Column {
            anchors.fill: parent
            anchors.margins: 18 * root.scaleFactor
            spacing: 12 * root.scaleFactor
            Text {
                text: root.desktopSession
                color: "#F2F2F3"
                font.family: "Adwaita Sans"
                font.pixelSize: 14 * root.scaleFactor
            }
            Text {
                text: root.sessionContextText
                color: "#777781"
                font.family: "Adwaita Sans"
                font.pixelSize: 11 * root.scaleFactor
            }
        }
    }
}
