pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "island" as Island_
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.components.widgets as Widgets
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

    // Two clearly separated phases per direction, instead of everything
    // moving at once:
    //   expanding  = 1. uncross (icons swap sides, still narrow)
    //                2. spread  (content appears, pill widens)
    //   collapsing = 1. collect (content goes, pill narrows)
    //                2. cross   (icons swap back)
    // "crossed" is the idle order [clock][battery]; uncrossed is the active
    // order [battery][content][clock].
    property bool crossed: root.mode === "idle"
    readonly property int phaseMs: 300

    // 0..1 slice of the content that's actually shown. The content stays
    // loaded and at full natural width while this shrinks - the holder clips
    // it - so the text visibly squishes away instead of blinking out of
    // existence (which is what made collapsing look like a teleport: the
    // width went straight from full to zero in one frame).
    property real contentReveal: root.mode === "idle" ? 0 : 1

    // True only while contentReveal is animating. The clock's x follows the
    // squishing content, so its own Behavior has to be off during that: a
    // Behavior whose target moves every frame just restarts each frame and
    // crawls nowhere (the clock sat frozen while the text collapsed). The
    // squish itself is already smooth, so the clock rides it directly.
    property bool squishing: false

    SequentialAnimation {
        id: expandSeq

        // 1. uncross - icons swap sides while still narrow
        ScriptAction {
            script: root.crossed = false
        }
        PauseAnimation {
            duration: root.phaseMs + 40
        }
        // 2. spread - load the content (still clipped to nothing), then
        //    unsquish it open
        ScriptAction {
            script: {
                modeLoader.displayMode = root.mode;
                root.squishing = true;
            }
        }
        NumberAnimation {
            target: root
            property: "contentReveal"
            to: 1
            duration: root.phaseMs
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: root.squishing = false
        }
    }

    SequentialAnimation {
        id: collapseSeq

        // 1. collect - squish the text away while it's still there
        ScriptAction {
            script: root.squishing = true
        }
        NumberAnimation {
            target: root
            property: "contentReveal"
            to: 0
            duration: root.phaseMs
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.squishing = false;
                modeLoader.displayMode = "idle";
            }
        }
        PauseAnimation {
            duration: 40
        }
        // 2. cross - icons swap back
        ScriptAction {
            script: root.crossed = true
        }
    }

    Connections {
        function onModeChanged(): void {
            const wasIdle = modeLoader.displayMode === "idle";
            const goingIdle = root.mode === "idle";
            expandSeq.stop();
            collapseSeq.stop();
            if (wasIdle && !goingIdle)
                expandSeq.start();
            else if (!wasIdle && goingIdle)
                collapseSeq.start();
            else
                modeLoader.displayMode = root.mode;
            syncGuard.restart();
        }

        target: root
    }

    // Safety net: a sequence that gets interrupted mid-way (rapid transients
    // can do that) must never leave the pill showing stale content or a
    // half-swapped order, which is exactly what broke it before.
    Timer {
        id: syncGuard

        interval: 1400
        onTriggered: {
            if (expandSeq.running || collapseSeq.running)
                return;
            modeLoader.displayMode = root.mode;
            root.crossed = root.mode === "idle";
            root.contentReveal = root.mode === "idle" ? 0 : 1;
        }
    }

    function closeTray(): void {}

    function checkPopout(x: real): void {}

    function handleWheel(x: real, angleDelta: point): void {
        // While fully expanded, scrolling anywhere on the (now much bigger)
        // pill bounds used to switch workspaces - only the workspaces widget
        // inside the panel should do that now (see IslandWorkspaces.qml).
        if (root.fullyExpanded)
            return;
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
        } else if (mode === "music") {
            // The pill is showing what's playing, so a tap opens the player.
            Island.toggleFullyExpanded();
        } else {
            // Anything else (idle/normal, timer, transients) opens the quick
            // panel, same as the Meta-key shortcut. toggleQuickPanel() also
            // drops any stuck/looping transient before opening, so the pill
            // can never become permanently untappable.
            Island.toggleQuickPanel();
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

        // The expanded quick-settings/power surface goes for a fixed blackish
        // dark-blue theme (DarkAccent) instead of the wallpaper-derived M3
        // colour; the compact idle pill keeps its original frosted glass look.
        color: root.fullyExpanded ? DarkAccent.bg : Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
        border.width: 1
        border.color: root.fullyExpanded ? DarkAccent.border : Qt.alpha(Colours.palette.m3onSurface, 0.08)

        Behavior on color {
            Anim {}
        }

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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Island.cycleRestingMode();
                else
                    root.onPillClicked();
            }
        }

        // Deliberately NOT a RowLayout: a layout reasserts its children's x
        // every layout pass, which silently overrides any Behavior on x - so
        // items always teleported to their new slot instead of sliding, no
        // matter the easing or duration. Positioning by plain bindings here
        // means Behavior on x actually animates, in every direction, with no
        // sequencing/ghosting needed.
        Item {
            id: compactContent

            readonly property real gap: Tokens.spacing.small
            readonly property real batteryW: 26
            // The visible (clipped) width, not the content's natural width -
            // this is what shrinks/grows during the squish.
            readonly property real contentW: contentHolder.width
            // Only add a second gap once there's actually content between the
            // two icons, so the "uncrossed but still empty" mid-state (phase 1
            // of expanding) stays exactly as wide as the idle state.
            readonly property real contentGap: contentW > 0 ? gap : 0

            anchors.centerIn: parent

            implicitWidth: batteryW + gap + contentW + contentGap + trailingClock.implicitWidth
            implicitHeight: Math.max(13, modeLoader.implicitHeight, trailingClock.implicitHeight)

            visible: opacity > 0
            opacity: root.fullyExpanded ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            // Persistent at-a-glance battery status - the charging/unplugged/
            // lowbattery transients already show their own icon, so this
            // stays out of the way during those specifically.
            Widgets.BatteryIcon {
                id: batteryIcon

                width: compactContent.batteryW
                height: 13
                y: (compactContent.height - height) / 2
                x: root.crossed ? (trailingClock.implicitWidth + compactContent.gap) : 0

                visible: opacity > 0
                opacity: UPower.displayDevice.isLaptopBattery && !["charging", "unplugged", "lowbattery"].includes(modeLoader.displayMode) ? 1 : 0
                bodyColour: "white"
                normalFillColour: "white"
                chargingFillColour: "#3ddc6a"
                lowFillColour: Colours.palette.m3error
                boltColour: "#ffd23d"

                Behavior on x {
                    Anim {
                        type: Anim.ExpressiveDefaultSpatial
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            // Clips the content to a fraction of its natural width so it
            // squishes closed/open instead of popping in and out.
            Item {
                id: contentHolder

                clip: true
                x: compactContent.batteryW + compactContent.gap
                y: (compactContent.height - height) / 2
                width: modeLoader.implicitWidth * root.contentReveal
                height: modeLoader.implicitHeight

                Behavior on x {
                    Anim {
                        type: Anim.ExpressiveDefaultSpatial
                    }
                }

                Loader {
                    id: modeLoader

                    property string displayMode: root.mode

                    width: implicitWidth
                    height: implicitHeight

                    asynchronous: false
                    active: !root.fullyExpanded
                    sourceComponent: {
                        if (displayMode === "idle")
                            return emptyView;
                        if (displayMode === "notification")
                            return notificationView;
                        if (displayMode === "reply")
                            return replyView;
                        if (displayMode === "workspace")
                            return workspaceView;
                        if (displayMode === "volume")
                            return volumeView;
                        if (displayMode === "brightness")
                            return brightnessView;
                        if (displayMode === "charging")
                            return chargingView;
                        if (displayMode === "unplugged")
                            return unpluggedView;
                        if (displayMode === "lowbattery")
                            return lowBatteryView;
                        if (displayMode === "hotplug")
                            return hotplugView;
                        if (displayMode === "budslowbattery")
                            return budsLowBatteryView;
                        if (displayMode === "timer")
                            return timerView;
                        return musicView;
                    }
                }
            }

            // Doubles as idle's clock (modeLoader collapses to nothing in
            // idle, see emptyView) and the trailing time on every other
            // state.
            StyledText {
                id: trailingClock

                y: (compactContent.height - implicitHeight) / 2
                x: root.crossed ? 0 : (compactContent.batteryW + compactContent.gap + compactContent.contentW + compactContent.contentGap)

                text: Time.timeStr
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small

                // Off during the squish (see root.squishing) - there the x
                // target is already moving smoothly frame by frame and the
                // clock should ride it exactly. This Behavior is only for the
                // discrete cross/uncross jump.
                Behavior on x {
                    enabled: !root.squishing

                    Anim {
                        type: Anim.ExpressiveDefaultSpatial
                    }
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

    // Idle has nothing to show in the middle - the trailing clock covers it,
    // this just collapses modeLoader to zero size instead of duplicating it.
    Component {
        id: emptyView

        Item {
            implicitWidth: 0
            implicitHeight: 0
        }
    }

    Component {
        id: notificationView

        RowLayout {
            spacing: Tokens.spacing.small

            readonly property var notif: Notifs.popups[0] ?? null
            // Best-effort: if GalaxyBudsClient sends its own notification for
            // an ANC/Transparency switch (there's no queryable mode state to
            // poll for this - see Island.qml), show it with a bud icon
            // instead of the generic one.
            readonly property bool fromBuds: (notif?.appName ?? "").toLowerCase().includes("galaxybuds") || (notif?.appName ?? "").toLowerCase().includes("buds")

            MaterialIcon {
                text: parent.fromBuds ? "headset" : (notif ? Icons.getNotifIcon(notif.summary, notif.urgency) : "notifications")
            }

            StyledText {
                // Let the pill grow to fit the whole thing (it already
                // animates width smoothly) instead of truncating - just a
                // sane cap so one pathologically long notification can't
                // stretch the pill off-screen.
                Layout.maximumWidth: root.screen.width * 0.6
                elide: Text.ElideRight
                text: notif ? `${notif.appName ? notif.appName + ": " : ""}${notif.summary}` : ""
                font: Tokens.font.body.small
            }
        }
    }

    // Notifications that support inline reply (chat apps) expand the pill into
    // a rectangle with a real input instead of a plain one-line strip.
    Component {
        id: replyView

        ColumnLayout {
            id: replyRoot

            readonly property var notif: Island.replyNotif

            spacing: Tokens.spacing.small

            Component.onCompleted: replyField.forceActiveFocus()
            Component.onDestruction: Island.holdReply(false)

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: replyRoot.notif ? Icons.getNotifIcon(replyRoot.notif.summary, replyRoot.notif.urgency) : "chat"
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 420
                    elide: Text.ElideRight
                    text: replyRoot.notif ? `${replyRoot.notif.appName ? replyRoot.notif.appName + ": " : ""}${replyRoot.notif.summary}` : ""
                    font: Tokens.font.body.small
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 460
                visible: text.length > 0
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                text: replyRoot.notif?.body ?? ""
                color: DarkAccent.textMuted
                font: Tokens.font.body.small
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 320
                    implicitHeight: replyField.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: DarkAccent.surfaceHigh

                    TextField {
                        id: replyField

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.large
                        anchors.rightMargin: Tokens.padding.large

                        background: null
                        color: DarkAccent.text
                        placeholderText: replyRoot.notif?.inlineReplyPlaceholder || qsTr("Reply…")
                        placeholderTextColor: DarkAccent.textMuted
                        font: Tokens.font.body.small
                        verticalAlignment: TextInput.AlignVCenter

                        // Typing holds the auto-dismiss off; emptying the box
                        // lets it fade again like any other notification.
                        onTextChanged: Island.holdReply(text.length > 0)
                        onAccepted: Island.sendReply(text)
                        Keys.onEscapePressed: Island.dismissReply()
                    }
                }

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: sendIcon.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: replyField.text.length > 0 ? DarkAccent.accent : DarkAccent.surfaceHigh

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: Tokens.rounding.full
                        disabled: replyField.text.length === 0
                        onClicked: Island.sendReply(replyField.text)
                    }

                    MaterialIcon {
                        id: sendIcon

                        anchors.centerIn: parent
                        text: "send"
                        color: replyField.text.length > 0 ? "black" : DarkAccent.textMuted
                    }
                }
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
                    // Mapped against the real ceiling rather than a hardcoded
                    // 1.0 - the sink can be boosted above 100%, which used to
                    // peg this bar full long before the volume actually was.
                    width: parent.width * Math.max(0, Math.min(1, Audio.volume / Math.max(0.01, GlobalConfig.services.maxVolume)))
                    radius: parent.radius
                    color: DarkAccent.accent

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
                    color: DarkAccent.accent

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }
    }

    Component {
        id: chargingView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "bolt"
                color: DarkAccent.accent
            }

            StyledText {
                text: qsTr("Charging – %1%").arg(Math.round(UPower.displayDevice.percentage * 100))
                font: Tokens.font.body.medium
            }
        }
    }

    Component {
        id: unpluggedView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "battery_std"
            }

            StyledText {
                text: qsTr("Unplugged – %1%").arg(Math.round(UPower.displayDevice.percentage * 100))
                font: Tokens.font.body.medium
            }
        }
    }

    Component {
        id: lowBatteryView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "battery_alert"
                color: Colours.palette.m3error
            }

            StyledText {
                text: qsTr("Low battery – %1%").arg(Math.round(UPower.displayDevice.percentage * 100))
                font: Tokens.font.body.medium
                color: Colours.palette.m3error
            }
        }
    }

    Component {
        id: hotplugView

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "usb"
            }

            StyledText {
                text: Island.hotplugMessage
                font: Tokens.font.body.medium
            }
        }
    }

    Component {
        id: budsLowBatteryView

        RowLayout {
            spacing: Tokens.spacing.small

            readonly property int minPct: Math.min(GalaxyBuds.device?.BatteryLeft ?? 100, GalaxyBuds.device?.BatteryRight ?? 100)

            MaterialIcon {
                text: "headset"
                color: Colours.palette.m3error
            }

            StyledText {
                text: qsTr("Buds low battery – %1%").arg(parent.minPct)
                font: Tokens.font.body.medium
                color: Colours.palette.m3error
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
                // Same reasoning as the notification view - grow to fit the
                // full track/artist instead of truncating it.
                Layout.maximumWidth: root.screen.width * 0.6
                elide: Text.ElideRight
                text: Players.active ? `${Players.active.trackArtist} - ${Players.active.trackTitle}` : ""
                font: Tokens.font.body.small
            }
        }
    }
}
