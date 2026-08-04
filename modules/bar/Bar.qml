pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components" as BarComponents
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
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
        if (mode === "notification") {
            root.visibilities.sidebar = true;
            Island.dismissTransient();
        } else if (mode === "workspace") {
            // let it revert on its own
        } else if (mode === "music") {
            root.visibilities.dashboard = true;
        } else {
            Island.toggleMenu();
        }
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledClippingRect {
        id: pill

        anchors.centerIn: parent

        implicitWidth: Math.max(root.compactHeight, content.implicitWidth + root.hPadding * 2)
        implicitHeight: content.implicitHeight + Tokens.padding.small * 2
        radius: height / 2

        color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

        Behavior on implicitWidth {
            Anim {}
        }

        Behavior on implicitHeight {
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
            id: content

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Loader {
                asynchronous: false
                sourceComponent: {
                    if (root.mode === "notification")
                        return notificationView;
                    if (root.mode === "workspace")
                        return workspaceView;
                    if (root.mode === "timer")
                        return timerView;
                    if (root.mode === "music")
                        return musicView;
                    if (root.mode === "menu")
                        return menuView;
                    return idleView;
                }
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

    Component {
        id: menuView

        RowLayout {
            spacing: Tokens.spacing.large

            BarComponents.IslandWorkspaces {}

            BarComponents.IslandStatus {}

            BarComponents.IslandTimerControls {}

            BarComponents.Power {
                visibilities: root.visibilities
            }
        }
    }
}
