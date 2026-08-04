pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

RowLayout {
    spacing: Tokens.spacing.medium

    MaterialIcon {
        visible: Config.bar.status.showNetwork
        text: Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
    }

    MaterialIcon {
        visible: Config.bar.status.showBluetooth
        text: {
            if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                return "bluetooth_disabled";
            if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                return "bluetooth_connected";
            return "bluetooth";
        }
    }

    MaterialIcon {
        visible: Config.bar.status.showBattery && UPower.displayDevice.isLaptopBattery
        fill: 1
        text: Icons.getBatteryIcon(UPower.displayDevice.percentage, [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state))
        color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? Colours.palette.m3onSurface : Colours.palette.m3error
    }
}
