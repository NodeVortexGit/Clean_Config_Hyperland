pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    // BlueZ keeps every device it has ever seen in its list, with no "is it
    // actually nearby" flag exposed - so the panel was listing ~17 stale
    // entries for ~3 real devices. Paired/connected ones are always shown;
    // anything else only while discovery is actually running, and only if it
    // has a real name (random BLE ads just use their own MAC as the name).
    readonly property var visibleDevices: {
        const discovering = Bluetooth.defaultAdapter?.discovering ?? false; // qmllint disable unresolved-type
        return [...Bluetooth.devices.values].filter(d => {
            // qmllint disable unresolved-type
            if (d.paired || d.bonded || d.connected)
                return true;
            if (!discovering)
                return false;
            return d.name && d.name.length > 0 && !/^[0-9A-F]{2}([:-][0-9A-F]{2}){5}$/i.test(d.name);
        }).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || "")).filter((d, i, arr) => {
            // Same physical device can appear several times under rotating
            // BLE addresses (the Buds showed up 3x) - keep only the first
            // entry per name, which the sort above has already made the
            // connected/paired one.
            return arr.findIndex(o => (o.name || o.address) === (d.name || d.address)) === i;
        });
    }

    // Discovery runs only while this card is on screen. Without it BlueZ
    // never refreshes, so "nearby" can't be known at all; leaving it on
    // permanently would scan in the background forever.
    Component.onCompleted: {
        const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
        if (adapter?.enabled)
            adapter.discovering = true;
    }

    Component.onDestruction: {
        const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
        if (adapter)
            adapter.discovering = false;
    }

    width: 300
    spacing: Tokens.spacing.small

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.extraSmall
        text: qsTr("Bluetooth")
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.enabled = checked;
        }
    }

    Toggle {
        label: qsTr("Discovering")
        checked: Bluetooth.defaultAdapter?.discovering ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.discovering = checked;
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small
        Layout.rightMargin: Tokens.padding.extraSmall
        text: {
            const devices = root.visibleDevices;
            let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
            const connected = devices.filter(d => d.connected).length;
            if (connected > 0)
                available += qsTr(" (%1 connected)").arg(connected);
            return available;
        }
        color: DarkAccent.textMuted
        font: Tokens.font.body.small
    }

    Repeater {
        model: ScriptModel {
            values: root.visibleDevices.slice(0, 5)
        }

        RowLayout {
            id: device

            required property BluetoothDevice modelData
            readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting // qmllint disable unresolved-type

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall
            spacing: Tokens.spacing.small

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: Icons.getBluetoothIcon(device.modelData.icon)
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.extraSmall
                Layout.rightMargin: Tokens.spacing.extraSmall
                Layout.fillWidth: true
                text: device.modelData.name
                elide: Text.ElideRight
            }

            MaterialIcon {
                visible: device.modelData.state === BluetoothDeviceState.Connected  // qmllint disable unresolved-type
                text: device.modelData.batteryAvailable ? Icons.getBatteryIcon(device.modelData.battery) : "battery_alert"
                color: device.modelData.batteryAvailable && device.modelData.battery < 0.2 ? Colours.palette.m3error : DarkAccent.textMuted
            }

            StyledRect {
                id: connectBtn

                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Tokens.padding.extraSmall

                radius: Tokens.rounding.full
                color: Qt.alpha(DarkAccent.accent, device.modelData.state === BluetoothDeviceState.Connected ? 1 : 0) // qmllint disable unresolved-type

                CircularIndicator {
                    anchors.fill: parent
                    running: device.loading
                }

                StateLayer {
                    color: DarkAccent.text // qmllint disable unresolved-type
                    disabled: device.loading
                    onClicked: device.modelData.connected = !device.modelData.connected
                }

                MaterialIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: device.modelData.connected ? "link_off" : "link"
                    color: DarkAccent.text // qmllint disable unresolved-type

                    opacity: device.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }

            Loader {
                visible: status === Loader.Ready
                asynchronous: true
                active: device.modelData.bonded
                sourceComponent: Item {
                    implicitWidth: connectBtn.implicitWidth
                    implicitHeight: connectBtn.implicitHeight

                    StateLayer {
                        radius: Tokens.rounding.full
                        onClicked: device.modelData.forget()
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete"
                    }
                }
            }
        }
    }

    // Discovery toggle lives as a small pinned button on the card itself (see
    // FullScreen.qml) instead of flowing here - a long device list would
    // otherwise clip it out of reach.

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
            accentColour: DarkAccent.accent
            accentOnColour: DarkAccent.bg
        }
    }
}
