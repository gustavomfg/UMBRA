# Production-like tree (local simulation only)

`scripts/stage-isolated-greeter.sh` generates `usr/share/nocturne-greeter/`
inside this project. It contains the pre-login entrypoint (`shell.qml`), the
shared visual QML, assets, QSB, the `GreetdAuthenticator.qml` adapter and the
launch gate. The mock backend and runnable harness shell are added to a
temporary copy by `scripts/run-isolated-greeter.sh`.

The staged policy reads users from `/etc/passwd` and sessions only from the
root-written catalog `/var/lib/nocturne-greeter/sessions.json`; without that
catalog no session can be launched. The installable form of this tree is the
package in `packaging/arch/`.

This directory is not an installable package or an active login configuration.
Nothing here is copied to the host's `/usr` or `/etc`.
