pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property var knownUsbLines: []
    property bool usbBaselined: false

    property bool ethernetWasConnected: false
    property bool ethernetBaselined: false

    property int screenCount: 0
    property bool screensBaselined: false

    property var pendingLabels: []

    function reportPlugged(label: string): void {
        pendingLabels.push(label);
        debounceTimer.restart();
    }

    Timer {
        id: debounceTimer

        // Groups hotplug events that land within ~1.2s of each other (e.g.
        // a dock waking up multiple interfaces at once) into a single
        // "Dock connected" flash instead of one flash per device.
        interval: 1200
        onTriggered: {
            if (root.pendingLabels.length > 1)
                Island.flashHotplug(qsTr("Dock connected"));
            else if (root.pendingLabels.length === 1)
                Island.flashHotplug(root.pendingLabels[0]);
            root.pendingLabels = [];
        }
    }

    // USB devices: no reactive service exists for this, so poll and diff.
    Process {
        id: usbProc

        command: ["lsusb"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                if (root.usbBaselined) {
                    const added = lines.filter(l => !root.knownUsbLines.includes(l));
                    for (const _ of added)
                        root.reportPlugged(qsTr("USB device connected"));
                }
                root.knownUsbLines = lines;
                root.usbBaselined = true;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!usbProc.running)
            usbProc.running = true
    }

    // Ethernet: Nmcli already tracks this reactively, just watch for a
    // disconnected -> connected transition.
    Connections {
        function onEthernetDevicesChanged(): void {
            const nowConnected = Nmcli.ethernetDevices.some(d => d.connected);
            if (root.ethernetBaselined && nowConnected && !root.ethernetWasConnected)
                root.reportPlugged(qsTr("Ethernet connected"));
            root.ethernetWasConnected = nowConnected;
            root.ethernetBaselined = true;
        }

        target: Nmcli
    }

    // Displays (HDMI/DisplayPort/USB-C): Quickshell already tracks connected
    // screens reactively via Screens.qml.
    Connections {
        function onScreensChanged(): void {
            const count = Screens.screens.length;
            if (root.screensBaselined && count > root.screenCount)
                root.reportPlugged(qsTr("Display connected"));
            root.screenCount = count;
            root.screensBaselined = true;
        }

        target: Screens
    }
}
