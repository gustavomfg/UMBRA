import QtQuick
import QtTest
import "../components"
import "../components/greeter-model.js" as Model

TestCase {
    id: testCase
    name: "NocturneGreeterModel"
    when: windowShown
    visible: true
    width: 900
    height: 400

    readonly property string passwd: [
        "root:x:0:0::/root:/usr/bin/bash",
        "greeter:x:967:967:greetd greeter user:/:/bin/bash",
        "nobody:x:65534:65534:Kernel Overflow User:/:/usr/bin/nologin",
        "alice:x:1000:1000:Alice Doe,Room 1:/home/alice:/usr/bin/zsh",
        "svc:x:1001:1001::/var/empty:/usr/bin/nologin",
        "bob:x:1002:1002::/home/bob:/bin/bash",
        "Bad Name:x:1003:1003::/home/x:/bin/bash",
        "broken-line",
        "alice:x:1004:1004::/home/alice2:/bin/bash",
        "huge:x:70000:70000::/home/huge:/bin/bash"
    ].join("\n")

    function test_loginDefsRange() {
        compare(Model.parseLoginDefs("# c\nUID_MIN\t\t 2000\nUID_MAX 3000\n"), { uidMin: 2000, uidMax: 3000 });
        compare(Model.parseLoginDefs(""), { uidMin: 1000, uidMax: 60000 });
        compare(Model.parseLoginDefs("UID_MIN 5000\nUID_MAX 10\n"), { uidMin: 1000, uidMax: 60000 });
    }

    function test_passwdFiltersSystemAndNologinUsers() {
        const users = Model.parsePasswd(passwd, 1000, 60000);
        compare(users.length, 2);
        compare(users[0], { id: "alice", displayName: "Alice Doe" });
        compare(users[1], { id: "bob", displayName: "bob" });
    }

    function test_sessionCatalogValidation() {
        const catalog = JSON.stringify({
            version: 1,
            sessions: [
                { id: "hyprland", name: "Hyprland", command: ["/usr/bin/start-hyprland"], desktopNames: ["Hyprland"], type: "wayland" },
                { id: "relative", name: "Relative", command: ["uwsm", "start"], desktopNames: [] },
                { id: "bad id!", name: "Bad", command: ["/usr/bin/true"] },
                { id: "x11", name: "X", command: ["/usr/bin/true"], type: "x11" },
                { id: "badnames", name: "Bad names", command: ["/usr/bin/true"], desktopNames: ["a;b"] },
                { id: "empty", name: "Empty", command: [] },
                { id: "plasma", name: "Plasma (Wayland)", command: ["/usr/lib/run", "/usr/bin/startplasma-wayland"], desktopNames: ["KDE"] }
            ]
        });
        const sessions = Model.parseSessionCatalog(catalog);
        compare(sessions.map(s => s.id), ["hyprland", "plasma"]);
        compare(Model.parseSessionCatalog("not json"), []);
        compare(Model.parseSessionCatalog(JSON.stringify({ version: 2, sessions: [] })), []);
    }

    function test_sessionEnvironment() {
        compare(Model.sessionEnvironment({ id: "plasma", desktopNames: ["KDE"] }),
                ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=plasma", "XDG_CURRENT_DESKTOP=KDE"]);
        compare(Model.sessionEnvironment({ id: "plain", desktopNames: [] }),
                ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=plain"]);
        compare(Model.sessionEnvironment(null), []);
    }

    function test_sessionCommandPrefix() {
        const session = { id: "hyprland-uwsm", command: ["/usr/bin/uwsm", "start", "hyprland.desktop"] };
        compare(Model.sessionCommand(session, ["/usr/bin/systemd-cat", "--identifier=nocturne-session", "--"]),
                ["/usr/bin/systemd-cat", "--identifier=nocturne-session", "--", "/usr/bin/uwsm", "start", "hyprland.desktop"]);
        compare(Model.sessionCommand(session, []), session.command);
        compare(Model.sessionCommand(null, ["/usr/bin/systemd-cat"]), []);
    }

    function test_stateRoundTripAndRejection() {
        compare(Model.parseState(Model.serializeState("alice", "hyprland-uwsm")), { user: "alice", session: "hyprland-uwsm" });
        compare(Model.parseState('{"user": "../../etc", "session": "a b"}'), { user: "", session: "" });
        compare(Model.parseState("garbage"), { user: "", session: "" });
    }

    function test_indexOfIdFallsBackToFirst() {
        const list = [{ id: "a" }, { id: "b" }];
        compare(Model.indexOfId(list, "b"), 1);
        compare(Model.indexOfId(list, "zzz"), 0);
        compare(Model.indexOfId([], "a"), -1);
    }

    function test_displayPrompt() {
        compare(Model.displayPrompt("Password: "), "Enter your password");
        compare(Model.displayPrompt("password:"), "Enter your password");
        compare(Model.displayPrompt("Enter OTP"), "Enter OTP");
    }

    function test_wakeSeedText() {
        compare(Model.wakeSeedText(" ", false), "");
        compare(Model.wakeSeedText("\r", false), "");
        compare(Model.wakeSeedText("\u007f", false), "");
        compare(Model.wakeSeedText("a", true), "");
        compare(Model.wakeSeedText("a", false), "a");
        compare(Model.wakeSeedText("ç", false), "ç");
    }

    function test_screenSelectionAndHotplug() {
        const left = { name: "DP-2", x: -1920, y: 0 };
        const origin = { name: "HDMI-A-1", x: 0, y: 0 };
        const other = { name: "DP-1", x: 1920, y: 0 };
        compare(Model.selectScreen([], "DP-2"), null);
        compare(Model.selectScreen([left, origin], "DP-2"), left);
        compare(Model.selectScreen([left, origin], "missing"), origin);
        compare(Model.selectScreen([left, origin], ""), origin);
        compare(Model.selectScreen([origin, left], ""), origin);
        compare(Model.selectScreen([left, other], ""), other);
        // A disconnected preferred connector falls back; reconnecting picks it.
        compare(Model.selectScreen([origin], "DP-2"), origin);
        compare(Model.selectScreen([origin, left], "DP-2"), left);
    }

    function test_hostname() {
        compare(Model.firstLine("my-host\n"), "my-host");
        compare(Model.firstLine("bad host!\n"), "");
    }

    // --- SystemChrome menus ---

    GreeterController {
        id: controller
    }

    SystemChrome {
        id: chrome
        y: 300
        width: 800
        height: 40
        controller: controller
        sessionOptions: [{ id: "hyprland", name: "Hyprland" }, { id: "plasma", name: "Plasma (Wayland)" }]
        selectedSessionIndex: 0
        userOptions: [{ id: "alice", displayName: "Alice Doe" }, { id: "bob", displayName: "bob" }]
        selectedUserIndex: 0
        powerActionsEnabled: true
    }

    SignalSpy {
        id: sessionSpy
        target: chrome
        signalName: "sessionChosen"
    }

    SignalSpy {
        id: userSpy
        target: chrome
        signalName: "userChosen"
    }

    SignalSpy {
        id: powerSpy
        target: chrome
        signalName: "powerActionRequested"
    }

    function findChild(item, name) {
        if (item.objectName === name)
            return item;
        const children = item.children || [];
        for (let i = 0; i < children.length; ++i) {
            const found = findChild(children[i], name);
            if (found)
                return found;
        }
        return null;
    }

    function init() {
        chrome.dismissMenus();
        sessionSpy.clear();
        userSpy.clear();
        powerSpy.clear();
    }

    function test_statusIndicatorsRemainVisibleWithoutServices() {
        chrome.networkAvailable = false;
        chrome.audioAvailable = false;
        chrome.online = true; // Stale values must not appear as live status.
        chrome.audioMuted = true;
        chrome.volumePercent = 73;
        const network = findChild(chrome, "networkIndicator");
        const audio = findChild(chrome, "audioIndicator");
        const power = findChild(chrome, "powerButton");
        verify(network.visible);
        verify(audio.visible);
        compare(network.label, "Network status unavailable");
        compare(audio.label, "Audio unavailable");
        verify(audio.icon.endsWith("/audio.svg"));
        verify(!network.interactive && !audio.interactive);
        verify(!network.activeFocusOnTab && !audio.activeFocusOnTab);
        verify(network.mapToItem(chrome, 0, 0).x < audio.mapToItem(chrome, 0, 0).x);
        verify(audio.mapToItem(chrome, 0, 0).x < power.mapToItem(chrome, 0, 0).x);
        mouseClick(audio, audio.width / 2, audio.height / 2);
        compare(powerSpy.count, 0);
        verify(!chrome.powerMenuOpen);
        chrome.online = false;
        chrome.audioMuted = false;
        chrome.volumePercent = 0;
    }

    function test_statusIndicatorsUpdateWhenServicesAreAvailable() {
        const network = findChild(chrome, "networkIndicator");
        const audio = findChild(chrome, "audioIndicator");
        chrome.networkAvailable = true;
        chrome.online = true;
        compare(network.label, "Connected");
        chrome.online = false;
        compare(network.label, "No connection");
        chrome.audioAvailable = true;
        chrome.volumePercent = 42;
        compare(audio.label, "Volume 42%");
        chrome.audioMuted = true;
        compare(audio.label, "Muted");
        verify(audio.icon.endsWith("/muted.svg"));
        chrome.audioAvailable = false;
        chrome.audioUnavailableText = "Audio unavailable before sign-in";
        compare(audio.label, "Audio unavailable before sign-in");
        chrome.audioUnavailableText = "Audio unavailable";
        chrome.networkAvailable = false;
        chrome.audioMuted = false;
        chrome.volumePercent = 0;
    }

    function test_keyboardSessionMenu() {
        const button = findChild(chrome, "sessionButton");
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        const first = findChild(chrome, "sessionMenu-option-0");
        const second = findChild(chrome, "sessionMenu-option-1");
        tryCompare(first, "activeFocus", true);
        keyClick(Qt.Key_Up); // wrap to the last entry
        tryCompare(second, "activeFocus", true);
        keyClick(Qt.Key_Home);
        tryCompare(first, "activeFocus", true);
        keyClick(Qt.Key_End);
        tryCompare(second, "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(sessionSpy.count, 1);
        compare(sessionSpy.signalArguments[0][0], 1);
        verify(!chrome.sessionMenuOpen);
        verify(button.activeFocus);
    }

    function test_keyboardUserMenuEscapeAndTab() {
        const button = findChild(chrome, "userButton");
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        tryCompare(findChild(chrome, "userMenu-option-0"), "activeFocus", true);
        keyClick(Qt.Key_Escape);
        verify(!chrome.userMenuOpen);
        verify(button.activeFocus);
        compare(userSpy.count, 0);
        keyClick(Qt.Key_Return);
        tryCompare(findChild(chrome, "userMenu-option-0"), "activeFocus", true);
        keyClick(Qt.Key_Tab);
        verify(!chrome.userMenuOpen);
        verify(findChild(chrome, "sessionButton").activeFocus);
    }

    function test_keyboardUserMenuSelects() {
        const button = findChild(chrome, "userButton");
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        tryCompare(findChild(chrome, "userMenu-option-0"), "activeFocus", true);
        keyClick(Qt.Key_Down);
        tryCompare(findChild(chrome, "userMenu-option-1"), "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(userSpy.count, 1);
        compare(userSpy.signalArguments[0][0], 1);
        verify(button.activeFocus);
    }

    function test_keyboardPowerMenu() {
        const button = findChild(chrome, "powerButton");
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        tryCompare(findChild(chrome, "power-suspend"), "activeFocus", true);
        keyClick(Qt.Key_Down);
        tryCompare(findChild(chrome, "power-reboot"), "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(powerSpy.count, 1);
        compare(powerSpy.signalArguments[0][0], "reboot");
        verify(button.activeFocus);
        chrome.powerActionsEnabled = false;
        keyClick(Qt.Key_Return);
        wait(300);
        verify(!findChild(chrome, "power-reboot").enabled);
        compare(powerSpy.count, 1);
        chrome.powerActionsEnabled = true;
    }

    function test_sessionMenuChoosesSession() {
        chrome.sessionMenuOpen = true;
        const menu = findChild(chrome, "sessionMenu");
        tryCompare(menu, "opacity", 1, 1000);
        // Second option row: 12 px top padding + one 34 px row + 2 px spacing.
        mouseClick(menu, menu.width / 2, 12 + 34 + 2 + 17);
        compare(sessionSpy.count, 1);
        compare(sessionSpy.signalArguments[0][0], 1);
        verify(!chrome.sessionMenuOpen);
    }

    function test_userMenuOnlyWhenSelectable() {
        const button = findChild(chrome, "userButton");
        verify(button.visible);
        chrome.userSelectionEnabled = false;
        verify(!button.visible);
        chrome.userSelectionEnabled = true;
        chrome.userMenuOpen = true;
        const menu = findChild(chrome, "userMenu");
        tryCompare(menu, "opacity", 1, 1000);
        mouseClick(menu, menu.width / 2, 12 + 34 + 2 + 17);
        compare(userSpy.count, 1);
        compare(userSpy.signalArguments[0][0], 1);
    }

    function test_powerActionsEmitOnlyWhenEnabled() {
        chrome.powerMenuOpen = true;
        const reboot = findChild(chrome, "power-reboot");
        tryCompare(reboot.parent.parent, "opacity", 1, 1000);
        mouseClick(reboot, 5, 5);
        compare(powerSpy.count, 1);
        compare(powerSpy.signalArguments[0][0], "reboot");

        chrome.powerActionsEnabled = false;
        chrome.powerMenuOpen = true;
        wait(300);
        mouseClick(findChild(chrome, "power-poweroff"), 5, 5);
        compare(powerSpy.count, 1);
        chrome.powerActionsEnabled = true;
    }
}
