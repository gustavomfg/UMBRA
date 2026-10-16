# Production-like tree (local simulation only)

`scripts/stage-isolated-greeter.sh` generates `usr/share/nocturne-greeter/`
inside this project. It contains the pre-login entrypoint (`shell.qml`), the
shared visual QML, assets, QSB, the `GreetdAuthenticator.qml` adapter and the
launch gate. The mock backend and runnable harness shell are added to a
temporary copy by `scripts/run-isolated-greeter.sh`.

The staged `SessionLaunchPolicy.qml` has no user and no command, so this tree
never calls `Greetd.launch()`. Only `scripts/stage-vm-greeter.sh`, inside the
guarded VM, replaces it with the fixed test policy from `vm/`.

This directory is not an installable package or an active login configuration.
Nothing here is copied to the host's `/usr` or `/etc`.
