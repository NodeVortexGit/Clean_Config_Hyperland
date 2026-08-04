pragma ComponentBehavior: Bound

import "../components" as BarComponents
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.widgets as Widgets
import qs.modules.dashboard.media as DashMedia
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool showMedia: Players.active?.isPlaying ?? false

    focus: true
    Keys.onEscapePressed: Island.collapse()
    Component.onCompleted: forceActiveFocus()

    Loader {
        anchors.fill: parent
        active: root.showMedia
        visible: active
        sourceComponent: RowLayout {
            spacing: Tokens.spacing.extraLarge

            Widgets.CoverArt {
                Layout.preferredWidth: Tokens.sizes.dashboard.mediaCoverArtSize * 0.7
                Layout.preferredHeight: Tokens.sizes.dashboard.mediaCoverArtSize * 0.7
            }

            DashMedia.Details {
                Layout.fillWidth: true
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.showMedia
        visible: active
        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.large

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.large

                QuickToggle {
                    icon: "wifi"
                    label: qsTr("Wi-Fi")
                    checked: Network.wifiEnabled
                    onToggled: Network.toggleWifi()
                }

                QuickToggle {
                    icon: Bluetooth.defaultAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
                    label: qsTr("Bluetooth")
                    checked: Bluetooth.defaultAdapter?.enabled ?? false
                    onToggled: {
                        const adapter = Bluetooth.defaultAdapter;
                        if (adapter)
                            adapter.enabled = !adapter.enabled;
                    }
                }

                QuickToggle {
                    icon: "do_not_disturb_on"
                    label: qsTr("Focus")
                    checked: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }

                QuickToggle {
                    icon: "airplanemode_active"
                    label: qsTr("Airplane")
                    checked: Airplane.enabled
                    onToggled: Airplane.toggle()
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.extraLarge

                BarComponents.IslandWorkspaces {}

                BarComponents.IslandTimerControls {}
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: GalaxyBuds.connected
                visible: active

                sourceComponent: RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "headset"
                    }

                    StyledText {
                        text: qsTr("Galaxy Buds connected")
                        font: Tokens.font.body.small
                    }

                    Repeater {
                        model: GalaxyBuds.actions

                        StateLayer {
                            required property var modelData

                            implicitWidth: label.implicitWidth + Tokens.padding.medium
                            implicitHeight: label.implicitHeight + Tokens.padding.small
                            radius: Tokens.rounding.full
                            onClicked: GalaxyBuds.execute(modelData.id)

                            StyledText {
                                id: label
                                anchors.centerIn: parent
                                text: modelData.name
                                font: Tokens.font.body.small
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            BarComponents.Power {
                Layout.alignment: Qt.AlignHCenter
                visibilities: root.visibilities
            }
        }
    }

    component QuickToggle: Item {
        id: toggle

        required property string icon
        required property string label
        required property bool checked
        signal toggled

        implicitWidth: 110
        implicitHeight: 84

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: toggle.checked ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

            Behavior on color {
                CAnim {}
            }

            MouseArea {
                anchors.fill: parent
                onClicked: toggle.toggled()
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: toggle.icon
                    fill: toggle.checked ? 1 : 0
                    color: toggle.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: toggle.label
                    font: Tokens.font.label.small
                    color: toggle.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
