import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import "components"

// Run inside Quickshell (its Greetd module is linked into the binary) by
// scripts/test-greetd-adapter.sh. Exercises GreetdAuthenticator's launch
// policy against a fake Greetd API; never touches a greetd socket.
ShellRoot {
    id: root

    property int failures: 0
    property int passes: 0

    function check(name, condition) {
        if (condition) {
            passes += 1;
            console.info("PASS " + name);
        } else {
            failures += 1;
            console.warn("FAIL " + name);
        }
    }

    QtObject {
        id: fakeGreetd
        property bool available: true
        property int state: GreetdState.Inactive
        property var launches: []
        signal authMessage(string text, bool error, bool requiresResponse, bool echoResponse)
        signal authFailure(string text)
        signal readyToLaunch
        signal error(string text)
        signal launched
        function createSession(user) {
            state = GreetdState.Authenticating;
        }
        function respond(response) {
        }
        function cancelSession() {
            state = GreetdState.Inactive;
        }
        function launch(command, environment, quit) {
            launches = launches.concat([[command, environment, quit]]);
        }
    }

    GreetdAuthenticator {
        id: adapter
        api: fakeGreetd
    }

    function readyAdapter(command) {
        adapter.cancellationPoisoned = false;
        adapter.active = false;
        adapter.ready = false;
        adapter.launchCommand = command;
        adapter.launchEnvironment = ["XDG_SESSION_TYPE=wayland"];
        fakeGreetd.state = GreetdState.Inactive;
        fakeGreetd.launches = [];
        const began = adapter.begin("gate-fixture", "fixed-session", 41);
        fakeGreetd.state = GreetdState.ReadyToLaunch;
        fakeGreetd.readyToLaunch();
        return began && adapter.ready;
    }

    Component.onCompleted: {
        check("ready with empty policy", readyAdapter([]));
        check("empty policy keeps safeMode", adapter.safeMode);
        check("empty policy refuses launch", adapter.requestSessionLaunch(41) === false && fakeGreetd.launches.length === 0);

        readyAdapter(["cage", "--", "/usr/bin/foot"]);
        check("relative command refused", adapter.requestSessionLaunch(41) === false && fakeGreetd.launches.length === 0);

        readyAdapter(["/usr/bin/cage", "--", "/usr/bin/foot"]);
        adapter.launchEnvironment = ["NOT_AN_ASSIGNMENT"];
        check("malformed environment refused", adapter.requestSessionLaunch(41) === false && fakeGreetd.launches.length === 0);

        const argv = ["/usr/bin/cage", "--", "/usr/bin/foot"];
        readyAdapter(argv);
        check("allowlisted policy leaves safeMode", !adapter.safeMode);
        check("wrong generation refused", adapter.requestSessionLaunch(40) === false);
        check("missing generation refused", adapter.requestSessionLaunch() === false);
        check("matching generation launches", adapter.requestSessionLaunch(41) === true);
        check("second request refused", adapter.requestSessionLaunch(41) === false);
        check("exactly one launch", fakeGreetd.launches.length === 1);
        check("argv passed verbatim", JSON.stringify(fakeGreetd.launches[0][0]) === JSON.stringify(argv));
        check("quit requested", fakeGreetd.launches[0][2] === true);
        let launchedGeneration = 0;
        const onLaunched = generation => launchedGeneration = generation;
        adapter.launched.connect(onLaunched);
        fakeGreetd.launched();
        adapter.launched.disconnect(onLaunched);
        check("requested launch acknowledged", launchedGeneration === 41 && !adapter.active);

        readyAdapter(argv);
        fakeGreetd.state = GreetdState.Inactive;
        check("non-ready API state refused", adapter.requestSessionLaunch(41) === false && fakeGreetd.launches.length === 0);

        readyAdapter(argv);
        adapter.cancel(41);
        check("cancelled attempt refused", adapter.requestSessionLaunch(41) === false && fakeGreetd.launches.length === 0);

        readyAdapter(["/usr/bin/cage"]);
        let errors = 0;
        const onError = () => errors += 1;
        adapter.backendError.connect(onError);
        fakeGreetd.launched();
        adapter.backendError.disconnect(onError);
        check("unrequested launch acknowledgement is an error", errors === 1);

        console.info("greetd-adapter: " + passes + " passed, " + failures + " failed");
        quitTimer.start();
    }

    // Qt.quit() is ignored before Quickshell's event loop is running.
    Timer {
        id: quitTimer
        interval: 0
        onTriggered: Qt.quit()
    }
}
