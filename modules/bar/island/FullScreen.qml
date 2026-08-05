pragma ComponentBehavior: Bound

import "../components" as BarComponents
import "../popouts" as BarPopouts

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Widgets
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

    // Decided once when the panel opens instead of tracking isPlaying live -
    // pausing from inside the sphere used to flip this reactively, tearing
    // down the very Loader (and StateLayer) mid-click and misfiring the
    // background close handler. Only the settings/tune button should switch
    // views now.
    property bool mediaViewLatched: false
    readonly property bool showMedia: root.mediaViewLatched && !Island.forceSettingsPage

    // Shared with the embedded Network/Bluetooth popout panels, which need one
    // to run at all but don't need the full old bar popout-stack machinery.
    readonly property BarPopouts.PopoutState popoutState: BarPopouts.PopoutState {}
    readonly property DashboardState dashState: DashboardState {}

    // GalaxyBudsClient exposes ~23 raw actions; only surface the handful that
    // are actually useful as quick-toggle buttons (modes/voice detection/
    // gestures), not the full raw CLI action list.
    readonly property var curatedBudsActionIds: ["AncToggle", "AmbientToggle", "SwitchAncSensitivity", "ToggleConversationDetect", "ToggleDoubleEdgeTouch", "LockTouchpadToggle", "StartStopFind"]
    readonly property var curatedBudsActions: GalaxyBuds.actions.filter(a => root.curatedBudsActionIds.includes(a.id))

    focus: true
    Keys.onEscapePressed: Island.collapse()

    Component.onCompleted: {
        GalaxyBuds.polling = true;
        forceActiveFocus();
        mediaViewLatched = (Players.active?.isPlaying ?? false) && !Island.forceSettingsPage;
    }
    Component.onDestruction: GalaxyBuds.polling = false

    // The power button opens the session panel (visibilities.session), which
    // has its own Keys.onEscapePressed and fights this item for active focus.
    // Collapsing immediately hands off cleanly instead of leaving two things
    // competing for Escape, which otherwise left Escape dead after Power.
    Connections {
        function onSessionChanged(): void {
            if (root.visibilities.session)
                Island.collapse();
        }

        target: root.visibilities
    }

    // Background fallback: tapping anywhere that isn't a card/button closes
    // the panel, same as Escape - sits behind everything else so a click on
    // an actual control still reaches that control first.
    MouseArea {
        anchors.fill: parent
        onClicked: Island.collapse()
    }

    Loader {
        anchors.fill: parent
        active: root.showMedia
        visible: active
        sourceComponent: ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                // Sits top-left - top-right is reserved for the persistent
                // close button added in Bar.qml, which sits on top of
                // whatever this view shows.
                Item {
                    implicitWidth: settingsIcon.implicitHeight + Tokens.padding.small
                    implicitHeight: settingsIcon.implicitHeight + Tokens.padding.small

                    StateLayer {
                        anchors.fill: undefined
                        anchors.centerIn: parent
                        implicitWidth: parent.implicitWidth
                        implicitHeight: parent.implicitHeight
                        radius: Tokens.rounding.full
                        onClicked: Island.showSettingsPage()
                    }

                    MaterialIcon {
                        id: settingsIcon
                        anchors.centerIn: parent
                        text: "tune"
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraLarge

                ColumnLayout {
                    id: mediaColumn

                    readonly property int sphereSize: 300

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.large

                    Item {
                        Layout.fillHeight: true
                    }

                    // Cover + track name sit above the sphere.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: mediaColumn.sphereSize
                        spacing: Tokens.spacing.medium

                        Widgets.CoverArt {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: Players.active?.trackTitle ?? ""
                                font: Tokens.font.title.medium
                                color: DarkAccent.text
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Players.active?.trackArtist || qsTr("Unknown artist")
                                font: Tokens.font.body.medium
                                color: DarkAccent.textMuted
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MusicSphere {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: mediaColumn.sphereSize
                        Layout.preferredHeight: mediaColumn.sphereSize
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: mediaColumn.sphereSize
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                            color: DarkAccent.text
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            value: Audio.volume
                            interactionOnMove: true
                            fgColour: DarkAccent.accent
                            bgColour: DarkAccent.surfaceHigh
                            onInteraction: v => Audio.setVolume(v)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                DashMedia.LyricsAndSelector {
                    Layout.preferredWidth: 300
                    Layout.maximumWidth: 300
                    Layout.fillWidth: false
                    Layout.fillHeight: true
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
                color: DarkAccent.surface

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Time.hourStr}:${Time.minuteStr}${Time.amPmStr ? " " + Time.amPmStr : ""}`
                        color: DarkAccent.accent
                        font: Tokens.font.clock.size(46).weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Time.date.toLocaleDateString(Qt.locale(), "ddd, d MMM")
                        color: DarkAccent.textMuted
                        font: Tokens.font.body.medium
                    }
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
                id: networkCard

                Layout.row: 1
                Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 340

                property string networkView: "wireless"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.small

                    RowLayout {
                        spacing: Tokens.spacing.small

                        NetworkTab {
                            label: qsTr("WiFi")
                            active: networkCard.networkView === "wireless"
                            onClicked: networkCard.networkView = "wireless"
                        }

                        NetworkTab {
                            label: qsTr("Wired")
                            active: networkCard.networkView === "ethernet"
                            onClicked: networkCard.networkView = "ethernet"
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        BarPopouts.Network {
                            popouts: root.popoutState
                            view: networkCard.networkView
                        }
                    }
                }
            }

            FixedCard {
                id: bluetoothCard

                Layout.row: 1
                Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 340

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    BarPopouts.Bluetooth {
                        popouts: root.popoutState
                    }
                }
            }

            Card {
                Layout.row: 1
                Layout.column: 2
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    spacing: Tokens.spacing.large

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
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

                    // Output switcher - one row per sink, current one
                    // highlighted. Speakers ending up muted while everything
                    // routed to the buds is exactly the case this makes
                    // visible and fixable without a terminal.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.padding.small
                        Layout.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: qsTr("Output")
                            color: DarkAccent.textMuted
                            font: Tokens.font.body.small
                        }

                        Repeater {
                            // Only real, usable outputs: the built-in
                            // speakers plus whatever's actually connected.
                            // The HDMI/DisplayPort sinks exist permanently
                            // whether or not anything is plugged into them,
                            // so they're hidden unless currently selected.
                            model: Audio.sinks.filter(s => {
                                if (s === Audio.sink)
                                    return true;
                                const d = (s?.description ?? "").toLowerCase();
                                return !d.includes("hdmi") && !d.includes("displayport");
                            })

                            Item {
                                id: sinkRow

                                required property var modelData
                                readonly property bool current: modelData === Audio.sink

                                Layout.fillWidth: true
                                implicitHeight: sinkLabel.implicitHeight + Tokens.padding.small * 2

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.full
                                    color: sinkRow.current ? DarkAccent.accentContainer : "transparent"

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    StateLayer {
                                        radius: Tokens.rounding.full
                                        onClicked: Audio.setAudioSink(sinkRow.modelData)
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.padding.medium
                                    anchors.rightMargin: Tokens.padding.medium
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: {
                                            const n = (sinkRow.modelData?.description ?? "").toLowerCase();
                                            if (n.includes("buds") || n.includes("headset") || n.includes("headphone"))
                                                return "headphones";
                                            if (n.includes("hdmi") || n.includes("displayport"))
                                                return "tv";
                                            return "speaker";
                                        }
                                        color: sinkRow.current ? DarkAccent.accentContainerText : DarkAccent.textMuted
                                        fontStyle: Tokens.font.icon.builders.small.build()
                                    }

                                    StyledText {
                                        id: sinkLabel

                                        Layout.fillWidth: true
                                        // PipeWire descriptions are long
                                        // ("Alder Lake PCH-P High Definition
                                        // Audio Controller Speaker") - keep
                                        // the meaningful tail.
                                        text: {
                                            const d = sinkRow.modelData?.description ?? "";
                                            return d.length > 34 ? "…" + d.slice(-33) : d;
                                        }
                                        elide: Text.ElideRight
                                        color: sinkRow.current ? DarkAccent.accentContainerText : DarkAccent.text
                                        font: Tokens.font.body.small
                                    }

                                    MaterialIcon {
                                        visible: sinkRow.modelData?.audio?.muted ?? false
                                        text: "volume_off"
                                        color: Colours.palette.m3error
                                        fontStyle: Tokens.font.icon.builders.small.build()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.extraLarge

                        BarComponents.IslandWorkspaces {}

                        BarComponents.IslandTimerControls {}
                    }
                }
            }

            StyledRect {
                id: calendarCard

                Layout.row: 2
                Layout.column: 0
                Layout.fillWidth: true
                implicitHeight: calendar.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.large
                color: DarkAccent.surface

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
                Layout.row: 2
                Layout.column: 1
                Layout.fillWidth: true
                active: GalaxyBuds.connected && root.curatedBudsActions.length > 0
                visible: active

                sourceComponent: FixedCard {
                    ColumnLayout {
                        spacing: Tokens.spacing.small

                        RowLayout {
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "headset"
                            }

                            StyledText {
                                text: qsTr("Galaxy Buds")
                                font: Tokens.font.body.small
                            }
                        }

                        Flow {
                            Layout.preferredWidth: 300
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root.curatedBudsActions

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

            // Fills all the dead space across the bottom-right of the grid.
            // Click it to pick which pictures appear (see PicturePicker) -
            // more than one and it cross-fades every 5s, a single one just
            // sits there. Falls back to the wallpaper if nothing is picked.
            StyledRect {
                id: frameCard

                property bool picking: false

                Layout.row: 2
                Layout.column: 1
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius: Tokens.rounding.large
                color: DarkAccent.surface

                PicturePicker {
                    id: picker

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    visible: opacity > 0
                    opacity: frameCard.picking ? 1 : 0
                    z: 3

                    onSelectionChanged: slideshow.paths = selected

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                QtObject {
                    id: slideshow

                    property var paths: []
                    property int index: 0
                    // Which of the two stacked Images is currently on top -
                    // they swap so the outgoing one can fade out underneath.
                    property bool showA: true

                    readonly property int count: paths.length
                    readonly property string currentPath: count > 0 ? paths[Math.min(index, count - 1)] : Wallpapers.current

                    // 0 fade, 1 zoom, 2 slide, 3 shred (rotate + squeeze).
                    property int mode: 0

                    function advance(): void {
                        if (count < 2)
                            return;
                        mode = Math.floor(Math.random() * 4);
                        index = (index + 1) % count;
                        showA = !showA;
                    }
                }

                Timer {
                    id: slideTimer

                    interval: 5000
                    running: slideshow.count > 1
                    repeat: true
                    onTriggered: slideshow.advance()
                }

                // The saved selection arrives asynchronously after the panel
                // is already built, so the timer's running binding could
                // settle before there was anything to cycle - reopening the
                // island then showed a static picture. Kick it explicitly
                // whenever the list changes.
                Connections {
                    function onPathsChanged(): void {
                        slideshow.index = 0;
                        if (slideshow.count > 1)
                            slideTimer.restart();
                    }

                    target: slideshow
                }

                ClippingRectangle {
                    id: frame

                    anchors.centerIn: parent
                    // Largest 16:9 box that fits the (now much wider) cell.
                    readonly property real availW: parent.width - Tokens.padding.large * 2
                    readonly property real availH: parent.height - Tokens.padding.large * 2

                    width: Math.max(0, Math.min(availW, availH * (16 / 9)))
                    height: Math.max(0, width * (9 / 16))
                    radius: Tokens.rounding.medium
                    color: DarkAccent.surfaceHigh

                    FrameImage {
                        id: imgA
                        active: slideshow.showA
                    }

                    FrameImage {
                        id: imgB
                        active: !slideshow.showA
                    }

                    // Tap the picture to choose which ones show here.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: frameCard.picking = true
                    }
                }

                // Doubles as the picker's close button once it's open.
                StyledRect {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.large
                    z: 4

                    implicitWidth: implicitHeight
                    implicitHeight: pickIcon.implicitHeight + Tokens.padding.small
                    radius: Tokens.rounding.full
                    color: frameCard.picking ? DarkAccent.accentContainer : "transparent"

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: Tokens.rounding.full
                        onClicked: frameCard.picking = !frameCard.picking
                    }

                    MaterialIcon {
                        id: pickIcon

                        anchors.centerIn: parent
                        text: frameCard.picking ? "close" : "photo_library"
                        color: frameCard.picking ? DarkAccent.accentContainerText : DarkAccent.textMuted
                    }
                }

                BarComponents.Power {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.large
                    z: 4
                    visibilities: root.visibilities
                }
            }
        }
    }

    // One layer of the slideshow cross-fade. Only the active layer updates
    // its source, so the outgoing image stays put while it fades away, and a
    // slow drift/zoom keeps a static single picture from feeling dead.
    component FrameImage: Image {
        id: frameImg

        required property bool active

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: width * 2
        // The transition varies per swap (slideshow.mode) so it isn't the
        // same cross-fade every five seconds: fade, zoom, slide, or a
        // rotate-and-squeeze "shred".
        readonly property int mode: slideshow.mode

        opacity: active ? 1 : 0
        scale: {
            if (active)
                return mode === 1 ? 1.0 : 1.06;
            return mode === 1 ? 1.35 : (mode === 3 ? 0.82 : 1);
        }
        rotation: active ? 0 : (mode === 3 ? 7 : 0)

        transform: Translate {
            x: frameImg.active ? 0 : (frameImg.mode === 2 ? -frameImg.width * 0.35 : 0)

            Behavior on x {
                NumberAnimation {
                    duration: 850
                    easing.type: Easing.InOutCubic
                }
            }
        }

        onActiveChanged: if (active)
            source = Qt.resolvedUrl(slideshow.currentPath)

        Component.onCompleted: if (active)
            source = Qt.resolvedUrl(slideshow.currentPath)

        Behavior on opacity {
            NumberAnimation {
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on rotation {
            NumberAnimation {
                duration: 850
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                // Slow drift while it sits, quicker when it's transitioning.
                duration: frameImg.active ? 5400 : 850
                easing.type: Easing.InOutQuad
            }
        }
    }

    component NetworkTab: Item {
        id: tab

        required property string label
        required property bool active
        signal clicked

        implicitWidth: tabLabel.implicitWidth + Tokens.padding.medium
        implicitHeight: tabLabel.implicitHeight + Tokens.padding.small

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: tab.active ? DarkAccent.accentContainer : "transparent"

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                radius: Tokens.rounding.full
                onClicked: tab.clicked()
            }
        }

        StyledText {
            id: tabLabel
            anchors.centerIn: parent
            text: tab.label
            font: Tokens.font.label.small
            color: tab.active ? DarkAccent.accentContainerText : DarkAccent.textMuted
        }
    }

    component Card: StyledRect {
        default property alias content: inner.data

        Layout.alignment: Qt.AlignTop
        implicitWidth: inner.implicitWidth + Tokens.padding.large * 2
        implicitHeight: inner.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: DarkAccent.surface

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
        color: DarkAccent.surface
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
            color: toggle.checked ? DarkAccent.accentContainer : DarkAccent.surfaceHigh

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
                    color: toggle.checked ? DarkAccent.accentContainerText : DarkAccent.text
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: toggle.label
                    font: Tokens.font.label.small
                    color: toggle.checked ? DarkAccent.accentContainerText : DarkAccent.textMuted
                }
            }
        }
    }
}
