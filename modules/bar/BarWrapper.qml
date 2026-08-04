pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int compactHeight: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property real clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property real clampedHeight: Math.max(Config.border.minThickness, implicitHeight)
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(x: real): void {
        (content.item as Bar)?.checkPopout(x);
    }

    function handleWheel(x: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(x, angleDelta);
    }

    clip: false
    visible: implicitWidth > 0 && implicitHeight > 0
    implicitWidth: shouldBeVisible ? (content.item?.implicitWidth ?? compactHeight) : 0
    implicitHeight: shouldBeVisible ? (content.item?.implicitHeight ?? compactHeight) : 0

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Loader {
        id: content

        anchors.centerIn: parent

        active: root.shouldBeVisible

        sourceComponent: Bar {
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
            compactHeight: root.compactHeight
        }
    }
}
