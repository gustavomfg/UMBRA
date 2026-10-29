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
    property string audioUnavailableText: "Audio unavailable"
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
    // A menu owns focus until selection, Escape or Tab. Return focus to its
    // trigger, so dismissing it never wakes the password field accidentally.
    function closeMenu(trigger) {
        dismissMenus();
        trigger.forceActiveFocus();
    }
    function focusOption(repeater, index) {
        const count = repeater.count;
        if (count > 0) {
            const item = repeater.itemAt((index + count) % count);
            if (item && item.enabled)
                item.forceActiveFocus();
        }
    }
    function menuKey(event, repeater, index, trigger, activate) {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            focusOption(repeater, index + (event.key === Qt.Key_Down ? 1 : -1));
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            focusOption(repeater, event.key === Qt.Key_Home ? 0 : repeater.count - 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate();
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            closeMenu(trigger);
            if (event.key !== Qt.Key_Escape)
                trigger.nextItemInFocusChain(event.key !== Qt.Key_Backtab && !(event.modifiers & Qt.ShiftModifier)).forceActiveFocus();
        } else {
            // Do not let a printable key bubble into the idle wake handler.
            event.accepted = true;
            return;
        }
        event.accepted = true;
    }
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
            Accessible.onPressAction: activate()
            Keys.onDownPressed: activate()
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
            objectName: "sessionButton"
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
            Accessible.onPressAction: activate()
            Keys.onDownPressed: activate()
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
            objectName: "networkIndicator"
            icon: "../assets/icons/network.svg"
            label: !root.networkAvailable ? "Network status unavailable" : root.online ? "Connected" : "No connection"
            scaleFactor: root.scaleFactor
            interactive: false
        }
        IconButton {
            objectName: "audioIndicator"
            icon: root.audioAvailable && root.audioMuted ? "../assets/icons/muted.svg" : "../assets/icons/audio.svg"
            label: !root.audioAvailable ? root.audioUnavailableText : root.audioMuted ? "Muted" : "Volume " + root.volumePercent + "%"
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
        objectName: "powerMenu"
        enabled: root.powerMenuOpen
        Accessible.role: Accessible.PopupMenu
        Accessible.name: "Power"
        onEnabledChanged: {
            if (enabled && root.powerActionsEnabled)
                Qt.callLater(() => { if (root.powerMenuOpen) root.focusOption(powerOptions, 0); });
        }
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
                id: powerOptions
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
                    required property int index
                    enabled: root.powerMenuOpen && root.powerActionsEnabled
                    activeFocusOnTab: false
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData.name
                    Accessible.onPressAction: activate()
                    function activate() {
                        if (!enabled) return;
                        root.closeMenu(powerButton);
                        root.powerActionRequested(modelData.action);
                    }
                    Keys.onPressed: event => root.menuKey(event, powerOptions, index, powerButton, activate)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4 * root.scaleFactor
                        radius: 5 * root.scaleFactor
                        color: "#1C1C24"
                        border.color: "#A78BFA"
                        border.width: 1
                        visible: powerRow.activeFocus
                    }
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
                            powerRow.activate();
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
        required property Item trigger
        enabled: open
        Accessible.role: Accessible.PopupMenu
        Accessible.name: trigger.Accessible.name
        onOpenChanged: {
            if (open) Qt.callLater(() => {
                if (menu.open) root.focusOption(optionsRepeater, Math.max(0, menu.selectedIndex));
            });
        }
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
                id: optionsRepeater
                model: menu.options
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    required property int index
                    objectName: menu.objectName + "-option-" + index
                    enabled: menu.open
                    activeFocusOnTab: false
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData[menu.labelKey]
                    Accessible.checkable: true
                    Accessible.checked: index === menu.selectedIndex
                    Accessible.onPressAction: activate()
                    function activate() {
                        if (!enabled) return;
                        root.closeMenu(menu.trigger);
                        menu.chosen(index);
                    }
                    Keys.onPressed: event => root.menuKey(event, optionsRepeater, index, menu.trigger, activate)
                    border.width: activeFocus ? 1 : 0
                    border.color: "#A78BFA"
                    width: optionColumn.width
                    height: 34 * root.scaleFactor
                    radius: 7 * root.scaleFactor
                    color: optionMouse.containsMouse || activeFocus ? "#1C1C24" : "transparent"
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
                            option.activate();
                        }
                    }
                }
            }
        }
    }
    OptionMenu {
        objectName: "userMenu"
        trigger: userButton
        x: root.leftMargin
        options: root.userOptions
        selectedIndex: root.selectedUserIndex
        labelKey: "displayName"
        open: root.userMenuOpen
        onChosen: index => root.userChosen(index)
    }
    OptionMenu {
        objectName: "sessionMenu"
        trigger: sessionButton
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
