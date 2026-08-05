pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
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
    // Notifications (and the reply box) still come through over a fullscreen
    // window - otherwise the pill is the only place they're shown and they'd
    // be silently swallowed. Everything else still hides in fullscreen.
    readonly property bool islandDemandsAttention: Island.mode === "notification" || Island.mode === "reply" || Island.fullyExpanded
    readonly property bool shouldBeVisible: (!fullscreen || islandDemandsAttention) && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
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
    // No Behavior here: the pill inside Bar.qml already animates its own
    // implicitWidth/Height smoothly. Animating this too would double up
    // (two independent animations chasing each other on the same value),
    // and on a big compact-to-expanded jump the compounded easing could
    // transiently produce a non-positive size here, which - since `visible`
    // below gates on implicitWidth/Height > 0 - would blank out the entire
    // bar including the pill until it settled.
    implicitWidth: shouldBeVisible ? (content.item?.implicitWidth ?? compactHeight) : 0
    implicitHeight: shouldBeVisible ? (content.item?.implicitHeight ?? compactHeight) : 0

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
