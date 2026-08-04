pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string cmd: "me.timschneeberger.GalaxyBudsClient"

    property bool connected: false
    property var device: null
    property var actions: []

    function execute(actionId: string): void {
        Quickshell.execDetached(["flatpak", "run", root.cmd, "action", "-e", actionId]);
    }

    Component.onCompleted: launchCheck.running = true

    // Launch the manager app in the background (once) if it isn't already running -
    // its own "minimize to tray" setting keeps it out of the way.
    Process {
        id: launchCheck

        command: ["pgrep", "-f", "GalaxyBudsClient"]
        onExited: code => {
            if (code !== 0)
                Quickshell.execDetached(["flatpak", "run", root.cmd]);
        }
    }

    Process {
        id: deviceProc

        command: ["flatpak", "run", root.cmd, "device", "--get-all", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.device = JSON.parse(text);
                    root.connected = true;
                } catch (e) {
                    root.device = null;
                    root.connected = false;
                }
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.device = null;
                root.connected = false;
            }
        }
    }

    Process {
        id: actionsProc

        command: ["flatpak", "run", root.cmd, "action", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Best-effort parse: one action per line, "id: description" or similar.
                // Falls back to an empty list (card just won't show actions) if the
                // format doesn't match once real output is seen with buds connected.
                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0 && l.includes(":"));
                root.actions = lines.map(l => {
                    const idx = l.indexOf(":");
                    return {
                        id: l.slice(0, idx).trim(),
                        name: l.slice(idx + 1).trim()
                    };
                });
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            deviceProc.running = false;
            deviceProc.running = true;
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            actionsProc.running = false;
            actionsProc.running = true;
        }
    }
}
