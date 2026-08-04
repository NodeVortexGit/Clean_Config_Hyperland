pragma ComponentBehavior: Bound

import "../components" as BarComponents
import "../popouts" as BarPopouts
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.widgets as Widgets
import qs.modules.dashboard.dash as DashCards
import qs.modules.dashboard.media as DashMedia
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool showMedia: (Players.active?.isPlaying ?? false) && !Island.forceSettingsPage

    // Shared with the embedded Network/Bluetooth popout panels, which need one
    // to run at all but don't need the full old bar popout-stack machinery.
    readonly property BarPopouts.PopoutState popoutState: BarPopouts.PopoutState {}
    readonly property DashboardState dashState: DashboardState {}

    Loader {
        anchors.fill: parent
        active: root.showMedia
        visible: active
        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                StateLayer {
                    implicitWidth: implicitHeight
                    implicitHeight: settingsIcon.implicitHeight + Tokens.padding.small
                    radius: Tokens.rounding.full
                    onClicked: Island.showSettingsPage()

                    MaterialIcon {
                        id: settingsIcon
                        anchors.centerIn: parent
                        text: "tune"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraLarge

                ColumnLayout {
                    Layout.preferredWidth: parent.width * 0.32
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.large

                    Item {
                        Layout.fillHeight: true
                    }

                    Widgets.CoverArt {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 220
                    }

                    DashMedia.Details {
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                DashMedia.LyricsAndSelector {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.showMedia
        visible: active
        sourceComponent: Flickable {
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true

            ColumnLayout {
                id: grid

                width: parent.width
                spacing: Tokens.spacing.large

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.large

                    StyledRect {
                        implicitWidth: Tokens.sizes.dashboard.dateTimeWidth + Tokens.padding.large * 2
                        implicitHeight: 140
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainerHigh

                        DashCards.DateTime {
                            anchors.fill: parent
                        }
                    }

                    Card {
                        DashCards.SmallWeather {}
                    }

                    Card {
                        BarPopouts.Battery {}
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.large

                    Card {
                        BarPopouts.Network {
                            popouts: root.popoutState
                            view: "wireless"
                        }
                    }

                    Card {
                        BarPopouts.Bluetooth {
                            popouts: root.popoutState
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.large

                    Card {
                        RowLayout {
                            spacing: Tokens.spacing.large

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
                    }

                    Card {
                        RowLayout {
                            spacing: Tokens.spacing.extraLarge

                            BarComponents.IslandWorkspaces {}

                            BarComponents.IslandTimerControls {}
                        }
                    }
                }

                StyledRect {
                    id: calendarCard

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 400 + Tokens.padding.large * 2
                    implicitHeight: calendar.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    DashCards.Calendar {
                        id: calendar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.large
                        dashState: root.dashState
                    }
                }

                Loader {
                    Layout.alignment: Qt.AlignHCenter
                    active: GalaxyBuds.connected
                    visible: active

                    sourceComponent: Card {
                        RowLayout {
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
                }

                BarComponents.Power {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.medium
                    Layout.bottomMargin: Tokens.spacing.medium
                    visibilities: root.visibilities
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: Island.collapse()
    Component.onCompleted: forceActiveFocus()

    component Card: StyledRect {
        default property alias content: inner.data

        Layout.alignment: Qt.AlignTop
        implicitWidth: inner.implicitWidth + Tokens.padding.large * 2
        implicitHeight: inner.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh

        Item {
            id: inner
            anchors.centerIn: parent
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
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
            color: toggle.checked ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest

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
