pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "island" as Island_
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    required property int compactHeight

    readonly property int hPadding: Tokens.padding.large
    readonly property string mode: Island.mode
    readonly property bool fullyExpanded: Island.fullyExpanded

    function closeTray(): void {}

    function checkPopout(x: real): void {}

    function handleWheel(x: real, angleDelta: point): void {
        if (!Config.bar.scrollActions.workspaces)
            return;
        const specialWs = Hypr.focusedMonitor?.lastIpcObject.specialWorkspace.name;
        if (specialWs?.length > 0)
            Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
        else if (angleDelta.y < 0 || Hypr.activeWsId > 1)
            Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
    }

    function fmtMmSs(secs: int): string {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    function onPillClicked(): void {
        if (root.fullyExpanded) {
            Island.collapse();
        } else if (mode === "notification") {
            root.visibilities.sidebar = true;
            Island.dismissTransient();
        } else if (mode === "workspace" || mode === "volume" || mode === "brightness") {
            // let it revert on its own
        } else {
            Island.toggleFullyExpanded();
        }
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledClippingRect {
        id: pill

        anchors.centerIn: parent

        readonly property real compactWidth: Math.max(root.compactHeight, compactContent.implicitWidth + root.hPadding * 2)
        readonly property real compactHeight: compactContent.implicitHeight + Tokens.padding.small * 2
        readonly property real expandedWidth: root.screen.width - Tokens.padding.extraLargeIncreased * 4
        readonly property real expandedHeight: root.screen.height - Tokens.padding.extraLargeIncreased * 4

        implicitWidth: root.fullyExpanded ? expandedWidth : compactWidth
        implicitHeight: root.fullyExpanded ? expandedHeight : compactHeight
        radius: Math.min(height / 2, Tokens.rounding.extraLarge)

        color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

        Behavior on implicitWidth {
            Anim {
                type: Anim.ExpressiveDefaultSpatial
            }
        }

        Behavior on implicitHeight {
            Anim {
                type: Anim.ExpressiveDefaultSpatial
            }
        }

        Behavior on radius {
            Anim {}
        }

        // Subtle top glass sheen
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height / 2
            radius: parent.height / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.06)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.onPillClicked()
        }

        RowLayout {
            id: compactContent

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            visible: opacity > 0
            opacity: root.fullyExpanded ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            Loader {
                asynchronous: false
                active: !root.fullyExpanded
                sourceComponent: {
                    if (root.mode === "notification")
                        return notificationView;
                    if (root.mode === "workspace")
                        return workspaceView;
                    if (root.mode === "volume")
                        return volumeView;
                    if (root.mode === "brightness")
                        return brightnessView;
                    if (root.mode === "timer")
                        return timerView;
                    if (root.mode === "music")
                        return musicView;
                    return idleView;
                }
            }
        }

        Loader {
            id: expandedContent

            anchors.fill: parent
            anchors.margins: Tokens.padding.large

            active: root.fullyExpanded
            asynchronous: false
            opacity: root.fullyExpanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            sourceComponent: Island_.FullScreen {
                visibilities: root.visibilities
            }
        }
    }

    Component {
        id: idleView

        StyledText {
            text: Time.timeStr
            font: Tokens.font.body.medium
        }
    }

    Component {
        id: notificationView

        RowLayout {
            spacing: Tokens.spacing.small

            readonly property var notif: Notifs.popups[0] ?? null

            MaterialIcon {
                text: notif ? Icons.getNotifIcon(notif.summary, notif.urgency) : "notifications"
            }

            StyledText {
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                text: notif ? `${notif.appName ? notif.appName + ": " : ""}${notif.summary}` : ""
                font: Tokens.font.body.small
            }
        }
    }

    Component {
        id: workspaceView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "grid_view"
            }

            StyledText {
                text: `${qsTr("Workspace")} ${Hypr.activeWsId}`
                font: Tokens.font.body.medium
            }
        }
    }

    Component {
        id: volumeView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            }

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 4
                radius: 2
                color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(1, Audio.volume)
                    radius: parent.radius
                    color: Colours.palette.m3primary

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }
    }

    Component {
        id: brightnessView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "brightness_medium"
            }

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 4
                radius: 2
                color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(1, Island.brightnessMonitor?.brightness ?? 0)
                    radius: parent.radius
                    color: Colours.palette.m3primary

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }
    }

    Component {
        id: timerView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "timer"
            }

            StyledText {
                text: Timers.active ? root.fmtMmSs(Timers.active.remaining) : "0:00"
                font: Tokens.font.mono.medium
            }

            StyledText {
                visible: !!Timers.active?.label
                text: Timers.active?.label ?? ""
                font: Tokens.font.body.small
            }
        }
    }

    Component {
        id: musicView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: (Players.active?.isPlaying ?? false) ? "music_note" : "pause"
            }

            StyledText {
                Layout.maximumWidth: 220
                elide: Text.ElideRight
                text: Players.active ? `${Players.active.trackArtist} - ${Players.active.trackTitle}` : ""
                font: Tokens.font.body.small
            }
        }
    }
}
