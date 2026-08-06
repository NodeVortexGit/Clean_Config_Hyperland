pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.greeter

// Drop-in replacement for the lock screen's Pam.qml, backed by greetd.
//
// Deliberately keeps the filename - and therefore the QML type name - so
// InputField, StateMessage and PasswordInput, which all declare
// `required property Pam pam`, keep type-checking with no edits. Only the
// internals change: instead of running a PAM conversation ourselves, we
// hand credentials to greetd, which owns PAM before any session exists.
//
// greetd's conversation is strictly request/response:
//   create_session{username}       -> auth_message{secret,"Password:"}
//   post_auth_message_response{pw} -> success | error{auth_error}
//   start_session{cmd}             -> success, then greetd execs the session
//
// A failed attempt terminates the session server-side, so we always open a
// fresh create_session before the user can type again.
Scope {
    id: root

    required property var lock

    // Whoever the account picker has selected.
    property string username: Users.currentName

    // greetd's conversation is bound to the username given at create_session,
    // so switching account mid-prompt has to start a fresh one - otherwise the
    // password would be checked against the previously selected user.
    onUsernameChanged: {
        if (!authenticated) {
            buffer = "";
            beginSession();
        }
    }
    // Whatever the session picker currently has selected. GreeterInfo.sessionCmd
    // is only the fallback for the case where no .desktop files were found.
    property var sessionCmd: Sessions.currentCmd.length > 0 ? Sessions.currentCmd : GreeterInfo.sessionCmd

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    property string lockMessage
    property string state
    property string fprintState
    property string buffer

    signal flashMsg
    // Correct password - Content.qml settles the physics sim back into place
    // and then calls lock.unlock() itself, which is what starts the session.
    signal succeeded

    // Set once greetd has accepted the password, so the unlock() that arrives
    // after the settle animation knows to start the session rather than
    // re-authenticate.
    property bool authenticated: false

    function send(obj: var): void {
        bridge.write(JSON.stringify(obj) + "\n");
    }

    // greetd's spec calls a failed password "not a fatal error ... handle as
    // appropriate" without saying whether the half-configured session survives
    // it. Rather than bet on one reading, always clear any existing session
    // before opening a new one. If there was nothing to cancel, greetd answers
    // with an error - which is why the cancel is tagged, so its reply can be
    // discarded instead of being shown to the user as a login failure.
    function beginSession(): void {
        if (!bridge.running)
            return;
        state = "";
        send({
            type: "cancel_session",
            _tag: "discard"
        });
        send({
            type: "create_session",
            username: root.username
        });
    }

    // Reachable from two places on purpose - the unlock animation's last step
    // and the watchdog that fires if that animation never finishes - so it has
    // to be safe to call twice. A second start_session would be an error reply
    // from greetd, surfaced as a failure on a login that already succeeded.
    property bool sessionStarted: false

    function startSession(): void {
        if (sessionStarted)
            return;
        sessionStarted = true;
        sessionWatchdog.stop();
        send({
            type: "start_session",
            cmd: root.sessionCmd,
            env: []
        });
    }

    function handleKey(event: KeyEvent): void {
        // PasswordInput force-holds focus, so this is the one key path
        // guaranteed to be reachable - which is exactly why the demo escape
        // hatch lives here rather than on a Shortcut.
        if (GreeterInfo.demo && event.key === Qt.Key_Escape) {
            Qt.quit();
            return;
        }

        if (passwd.active || state === "max")
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier) {
                buffer = "";
            } else {
                buffer = buffer.slice(0, -1);
            }
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Allow anything except control characters
            buffer += event.text;
        }
    }

    // Mirrors PamContext's shape closely enough that the UI can't tell the
    // difference: `active` drives the spinner, `message` the error text.
    QtObject {
        id: passwd

        property bool active
        property string message

        function start(): void {
            // An empty submission is always a rejection: it explodes the
            // screen, and it counts against pam_faillock like any other failed
            // attempt. Nothing is gained by sending it.
            if (active || !root.awaitingResponse || root.buffer.length === 0)
                return;
            active = true;
            root.send({
                type: "post_auth_message_response",
                response: root.buffer
            });
            root.buffer = "";
        }
    }

    // greetd exposes one PAM conversation and no separate fingerprint path,
    // so this stays inert. Kept because PasswordInput and StateMessage read
    // .available/.tries/.active unconditionally.
    QtObject {
        id: fprint

        readonly property bool available: false
        readonly property int tries: 0
        readonly property int errorTries: 0
        readonly property bool active: false
        readonly property string message: ""

        function start(): void {}
        function abort(): void {}
    }

    // True between an auth_message asking for input and our reply to it.
    property bool awaitingResponse: false

    Process {
        id: bridge

        command: ["python3", `${Quickshell.shellDir}/assets/greetd-bridge.py`].concat(Quickshell.env("GREETER_DEMO") ? ["--demo"] : [])
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    console.warn("greeter: unparseable bridge line:", line);
                    return;
                }

                if (msg.bridge === "ready") {
                    root.beginSession();
                    return;
                }
                if (msg.bridge === "fatal") {
                    root.state = "error";
                    passwd.message = msg.error ?? "greetd unavailable";
                    return;
                }
                if (msg.bridge)
                    return;

                // Reply to a speculative request we never wanted to hear about.
                if (msg._tag === "discard")
                    return;

                root.handleReply(msg);
            }
        }

        onExited: code => {
            if (!root.authenticated) {
                root.state = "error";
                passwd.message = `greetd bridge exited (${code})`;
            }
        }
    }

    function handleReply(msg: var): void {
        if (msg.type === "auth_message") {
            // "secret" and "visible" want input; "info"/"error" are just text
            // and must be acknowledged with an empty response to advance.
            const kind = msg.auth_message_type;
            if (kind === "secret" || kind === "visible") {
                awaitingResponse = true;
                passwd.active = false;
            } else {
                if (kind === "error")
                    lockMessage = msg.auth_message ?? "";
                send({
                    type: "post_auth_message_response",
                    response: ""
                });
            }
            return;
        }

        if (msg.type === "success") {
            if (authenticated)
                return; // reply to start_session; greetd is taking over now

            awaitingResponse = false;
            passwd.active = false;
            authenticated = true;
            succeeded();
            sessionWatchdog.restart();
            return;
        }

        if (msg.type === "error") {
            awaitingResponse = false;
            passwd.active = false;
            buffer = "";

            if (msg.error_type === "auth_error") {
                state = "fail";
            } else {
                state = "error";
                passwd.message = msg.description ?? "";
            }

            flashMsg();
            stateReset.restart();
            // greetd tore the session down on failure - open a fresh one so
            // the next keystroke has a conversation to talk to.
            beginSession();
        }
    }

    // Safety net: the password was correct, so the session MUST start even if
    // the settle animation never finishes. Never let a cosmetic effect strand
    // the user at a greeter they've already authenticated to.
    Timer {
        id: sessionWatchdog

        interval: 5000
        onTriggered: root.startSession()
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: {
            if (root.state !== "max")
                root.state = "";
        }
    }
}
