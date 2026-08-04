pragma ComponentBehavior: Bound

import "../components" as BarComponents
import "../popouts" as BarPopouts
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.widgets as Widgets
import qs.modules.dashboard.dash as DashCards
import qs.modules.dashboard.media as DashMedia
import qs.services
import qs.utils

Item {
    id: root

    anchors.fill: parent

    required property DrawerVisibilities visibilities

    readonly property bool showMedia: (Players.active?.isPlaying ?? false) && !Island.forceSettingsPage

    // Shared with the embedded Network/Bluetooth popout panels, which need one
    // to run at all but don't need the full old bar popout-stack machinery.
    readonly property BarPopouts.PopoutState popoutState: BarPopouts.PopoutState {}
    readonly property DashboardState dashState: DashboardState {}

    Component.onCompleted: GalaxyBuds.polling = true
    Component.onDestruction: GalaxyBuds.polling = false

    Loader {
        anchors.fill: parent
        active: root.showMedia
        visible: active
        sourceComponent: ColumnLayout {
            anchors.fill: parent
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
                    Layout.preferredWidth: 460
                    Layout.minimumWidth: 460
                    Layout.maximumWidth: 460
                    Layout.fillWidth: false
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            value: Audio.volume
                            interactionOnMove: true
                            onInteraction: v => Audio.setVolume(v)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                DashMedia.LyricsAndSelector {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 200
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.showMedia
        visible: active
        sourceComponent: GridLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            columns: 3
            rowSpacing: Tokens.spacing.large
            columnSpacing: Tokens.spacing.large

            StyledRect {
                Layout.row: 0
                Layout.column: 0
                Layout.fillWidth: true
                implicitHeight: 140
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                DashCards.DateTime {
                    anchors.fill: parent
                }
            }

            Card {
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                DashCards.SmallWeather {}
            }

            Card {
                Layout.row: 0
                Layout.column: 2
                Layout.fillWidth: true
                BarPopouts.Battery {}
            }

            FixedCard {
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                BarPopouts.Network {
                    popouts: root.popoutState
                    view: "wireless"
                }
            }

            FixedCard {
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true

                BarPopouts.Bluetooth {
                    popouts: root.popoutState
                }
            }

            Card {
                Layout.row: 1
                Layout.column: 2
                Layout.fillWidth: true

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
                Layout.row: 2
                Layout.column: 2
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    spacing: Tokens.spacing.extraLarge

                    BarComponents.IslandWorkspaces {}

                    BarComponents.IslandTimerControls {}
                }
            }

            StyledRect {
                id: calendarCard

                Layout.row: 3
                Layout.column: 0
                Layout.fillWidth: true
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
                Layout.row: 3
                Layout.column: 1
                Layout.fillWidth: true
                active: GalaxyBuds.connected
                visible: active

                sourceComponent: Card {
                    ColumnLayout {
                        spacing: Tokens.spacing.small

                        RowLayout {
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "headset"
                            }

                            StyledText {
                                text: qsTr("Galaxy Buds connected")
                                font: Tokens.font.body.small
                            }
                        }

                        Flow {
                            Layout.preferredWidth: 400
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: GalaxyBuds.actions

                                Item {
                                    id: actionBtn

                                    required property var modelData

                                    implicitWidth: label.implicitWidth + Tokens.padding.medium
                                    implicitHeight: label.implicitHeight + Tokens.padding.small

                                    StateLayer {
                                        anchors.fill: undefined
                                        anchors.centerIn: parent
                                        implicitWidth: parent.implicitWidth
                                        implicitHeight: parent.implicitHeight
                                        radius: Tokens.rounding.full
                                        onClicked: GalaxyBuds.execute(actionBtn.modelData.id)
                                    }

                                    StyledText {
                                        id: label
                                        anchors.centerIn: parent
                                        text: actionBtn.modelData.name
                                        font: Tokens.font.body.small
                                    }
                                }
                            }
                        }
                    }
                }
            }

            BarComponents.Power {
                Layout.row: 3
                Layout.column: 2
                Layout.alignment: Qt.AlignHCenter
                visibilities: root.visibilities
            }
        }
    }

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

    // Like Card, but clips to whatever height the Layout actually gives it
    // instead of growing to fit content - used for the Network/Bluetooth
    // device lists, which can otherwise get tall enough to force the whole
    // grid to need scrolling.
    component FixedCard: StyledRect {
        default property alias content: inner.data

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh
        clip: true

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
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
