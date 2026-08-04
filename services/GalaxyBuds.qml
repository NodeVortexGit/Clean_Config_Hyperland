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

    // Only poll while something is actually asking (the quick-settings panel).
    // Polling unconditionally in the background was spawning a full flatpak
    // sandbox every few seconds forever, and re-triggering the timer without
    // checking whether the previous call had finished could kill and restart
    // it mid-flight - real, continuous system load unrelated to whether
    // anyone was even looking at the panel.
    property bool polling: false

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
        interval: 8000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        // Skip the tick entirely if the previous call is still running instead
        // of killing and respawning it.
        onTriggered: if (!deviceProc.running)
            deviceProc.running = true
    }

    Timer {
        interval: 20000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!actionsProc.running)
            actionsProc.running = true
    }
}
