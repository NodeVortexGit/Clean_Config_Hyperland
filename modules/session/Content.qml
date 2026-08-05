pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    required property DrawerVisibilities visibilities

    readonly property real padding: Tokens.padding.large
    readonly property real rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)

    radius: Tokens.rounding.large
    color: DarkAccent.surface
    border.width: 1
    border.color: DarkAccent.border

    implicitWidth: inner.implicitWidth + padding + rightPadding
    implicitHeight: inner.implicitHeight + padding * 2

    Column {
        id: inner

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        anchors.topMargin: root.padding
        anchors.bottomMargin: root.padding

        spacing: Tokens.spacing.large

        Group {
            label: qsTr("Log out")

            SessionButton {
                id: logout

                icon: Config.session.icons.logout
                command: Config.session.commands.logout

                KeyNavigation.down: shutdown

                Component.onCompleted: forceActiveFocus()

                Connections {
                    function onLauncherChanged(): void {
                        if (!root.visibilities.launcher)
                            logout.forceActiveFocus();
                    }

                    target: root.visibilities
                }
            }
        }

        Group {
            label: qsTr("Shut down")

            SessionButton {
                id: shutdown

                icon: Config.session.icons.shutdown
                command: Config.session.commands.shutdown

                KeyNavigation.up: logout
                KeyNavigation.down: hibernate
            }
        }

        Group {
            label: qsTr("Hibernate")

            SessionButton {
                id: hibernate

                icon: Config.session.icons.hibernate
                command: Config.session.commands.hibernate

                KeyNavigation.up: shutdown
                KeyNavigation.down: reboot
            }
        }

        Group {
            label: qsTr("Reboot")

            SessionButton {
                id: reboot

                icon: Config.session.icons.reboot
                command: Config.session.commands.reboot

                KeyNavigation.up: hibernate
            }
        }
    }

    // Groups each button with a caption underneath, without touching the
    // SessionButton's own focus/keyboard-navigation logic at all.
    component Group: Column {
        id: group

        required property string label
        default property alias content: inner.data

        spacing: Tokens.spacing.extraSmall

        Item {
            id: inner

            implicitWidth: Tokens.sizes.session.button
            implicitHeight: Tokens.sizes.session.button
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: group.label
            color: DarkAccent.textMuted
            font: Tokens.font.label.small
        }
    }

    component SessionButton: IconButton {
        id: button

        required property list<string> command

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: Tokens.sizes.session.button

        inactiveColour: activeFocus ? DarkAccent.accentContainer : DarkAccent.surfaceHigh
        inactiveOnColour: activeFocus ? DarkAccent.accentContainerText : DarkAccent.text
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        font: Tokens.font.icon.builders.large.scale(1.3).build()
        onClicked: Quickshell.execDetached(button.command)

        Keys.onEnterPressed: Quickshell.execDetached(button.command)
        Keys.onReturnPressed: Quickshell.execDetached(button.command)
        Keys.onEscapePressed: root.visibilities.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_J || event.key === Qt.Key_N) && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_P) && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }
    }
}
