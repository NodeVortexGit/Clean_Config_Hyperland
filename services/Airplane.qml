pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services

Singleton {
    id: root

    readonly property bool enabled: !Network.wifiEnabled && !(Bluetooth.defaultAdapter?.enabled ?? true)

    function toggle(): void {
        const turnOn = !root.enabled;
        Network.enableWifi(!turnOn);
        const adapter = Bluetooth.defaultAdapter;
        if (adapter)
            adapter.enabled = !turnOn;
    }
}
