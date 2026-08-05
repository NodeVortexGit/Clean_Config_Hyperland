pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services

Scope {
    id: root

    property var knownUsbLines: []
    property bool usbBaselined: false

    property bool ethernetWasConnected: false
    property bool ethernetBaselined: false

    property int screenCount: 0
    property bool screensBaselined: false

    property var pendingPlugged: []
    property var pendingUnplugged: []

    function reportPlugged(label: string): void {
        pendingPlugged.push(label);
        debounceTimer.restart();
    }

    function reportUnplugged(label: string): void {
        pendingUnplugged.push(label);
        debounceTimer.restart();
    }

    // Appended to a "Dock plugged" message when the machine happens to be on
    // AC at that moment - a dock's power-delivery port doesn't show up as its
    // own distinct USB/ethernet/display line, so this is the practical signal
    // that a charger was among whatever just got connected.
    function chargingSuffix(): string {
        if (UPower.onBattery)
            return "";
        return qsTr(" – Charging %1%").arg(Math.round(UPower.displayDevice.percentage * 100));
    }

    Timer {
        id: debounceTimer

        // Groups hotplug events that land within ~1.2s of each other (e.g.
        // a dock waking up multiple interfaces at once) into a single
        // "Dock plugged/unplugged" flash instead of one flash per device.
        interval: 1200
        onTriggered: {
            if (root.pendingPlugged.length > 1)
                Island.flashHotplug(qsTr("Dock plugged") + root.chargingSuffix());
            else if (root.pendingPlugged.length === 1)
                Island.flashHotplug(root.pendingPlugged[0] + root.chargingSuffix());

            if (root.pendingUnplugged.length > 1)
                Island.flashHotplug(qsTr("Dock unplugged"));
            else if (root.pendingUnplugged.length === 1)
                Island.flashHotplug(root.pendingUnplugged[0]);

            root.pendingPlugged = [];
            root.pendingUnplugged = [];
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
                    const removed = root.knownUsbLines.filter(l => !lines.includes(l));
                    for (const _ of added)
                        root.reportPlugged(qsTr("USB device plugged"));
                    for (const _ of removed)
                        root.reportUnplugged(qsTr("USB device unplugged"));
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

    // Ethernet: Nmcli already tracks this reactively, just watch for
    // connected <-> disconnected transitions in either direction.
    Connections {
        function onEthernetDevicesChanged(): void {
            const nowConnected = Nmcli.ethernetDevices.some(d => d.connected);
            if (root.ethernetBaselined) {
                if (nowConnected && !root.ethernetWasConnected)
                    root.reportPlugged(qsTr("Ethernet plugged"));
                else if (!nowConnected && root.ethernetWasConnected)
                    root.reportUnplugged(qsTr("Ethernet unplugged"));
            }
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
            if (root.screensBaselined) {
                if (count > root.screenCount)
                    root.reportPlugged(qsTr("Display plugged"));
                else if (count < root.screenCount)
                    root.reportUnplugged(qsTr("Display unplugged"));
            }
            root.screenCount = count;
            root.screensBaselined = true;
        }

        target: Screens
    }
}
