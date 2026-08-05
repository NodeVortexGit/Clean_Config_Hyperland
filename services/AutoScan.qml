pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// Keeps WiFi scanning continuously in the background (like a phone does)
// instead of requiring a manual rescan tap. Bluetooth discovery is
// deliberately NOT forced on here - unlike WiFi it surfaces a constant churn
// of nameless/random-address BLE devices while active, so it stays a manual
// "Discovering" toggle (see Bluetooth.qml) instead of an always-on scan.
Scope {
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Nmcli.wifiEnabled && !Nmcli.scanning)
                Nmcli.rescanWifi();
        }
    }
}
