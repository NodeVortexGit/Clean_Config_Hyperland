pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    required property int compactHeight

    readonly property int hPadding: Tokens.padding.large

    function closeTray(): void {}

    function checkPopout(x: real): void {}

    function handleWheel(x: real, angleDelta: point): void {}

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledClippingRect {
        id: pill

        anchors.centerIn: parent

        implicitWidth: layout.implicitWidth + root.hPadding * 2
        implicitHeight: root.compactHeight
        radius: height / 2

        color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)

        Behavior on implicitWidth {
            Anim {}
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledText {
                text: Time.timeStr
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }
        }
    }
}
