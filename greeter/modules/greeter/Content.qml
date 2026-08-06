import "center"
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.greeter
import qs.services
import qs.utils

// Brightness left, volume right, clock/user/password down the middle.
//
// A wrong password shakes the screen and then drops everything on the floor
// with a small rigid-body sim (gravity, restitution, wall/floor collisions,
// angular velocity). Physics runs purely on each item's transform, never on
// its layout position, so every control stays exactly as interactive while
// it's tumbling - you can still type the password into a box lying on its
// side and drag the sliders where they land.
Item {
    id: root

    required property var lock

    // Hard boundary: nothing may render outside the black card, so even a
    // body caught mid-rotation can't poke out past the panel edge.
    clip: true

    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    // The lock screen asked Island for the *focused* monitor, which resolves
    // through Hyprland's IPC. Bind to this surface's own screen instead - it's
    // deterministic, correct per-surface on multi-monitor, and keeps the
    // greeter from depending on a compositor socket it may not be able to read.
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(lock.screen)

    // Registered rigid bodies (see PhysicsBody).
    property var bodies: []
    property bool dropped: false
    // True from the moment things are knocked loose until they have finished
    // drifting home. `dropped` goes false as soon as the return animation
    // starts, which would yank everything back to its layout slot mid-flight.
    readonly property bool displaced: dropped || returnAnim.running

    readonly property real gravity: 2800
    readonly property real restitution: 0.42
    readonly property real friction: 0.74

    function registerBody(b): void {
        // Register unconditionally. Filtering on `visible` here ran at
        // Component.onCompleted, before the session and user scans had
        // returned - so those pills were still hidden, never got registered,
        // and sat frozen while everything else fell. Visibility is checked at
        // simulation time instead, where it is actually current.
        bodies.push(b);
    }

    // Every failed attempt adds another impulse - the first knocks everything
    // loose, later ones kick the pile again wherever it has come to rest.
    function jolt(): void {
        if (!dropped) {
            dropped = true;
            for (const b of bodies) {
                if (!b.visible)
                    continue;
                const p = b.mapToItem(root, 0, 0);
                b.restX = p.x - b.ox;
                b.restY = p.y - b.oy;
            }
        }

        for (const b of bodies) {
            if (!b.visible)
                continue;
            // Direction used to be derived from which half of the screen the
            // body sat in, which meant the centre stack always got thrown the
            // same way and everything piled up bottom-right. Now it's a
            // random sign per body per hit, so it scatters differently every
            // time. Additive, so repeat hits keep launching it.
            const dir = Math.random() < 0.5 ? -1 : 1;
            b.vx += dir * (120 + Math.random() * 320);
            b.vy -= 300 + Math.random() * 380;
            b.vr += (Math.random() - 0.5) * 700;
        }
    }

    function reset(): void {
        dropped = false;
        returnAnim.stop();
        returnProgress = 0;
        for (const b of bodies) {
            b.ox = 0;
            b.oy = 0;
            b.rot = 0;
            b.vx = 0;
            b.vy = 0;
            b.vr = 0;
        }
    }

    // Right password: physics off, everything drifts home, then unlock.
    property real returnProgress: 0

    onReturnProgressChanged: {
        const t = returnProgress;
        for (const b of bodies) {
            b.ox = b.startOx * (1 - t);
            b.oy = b.startOy * (1 - t);
            b.rot = b.startRot * (1 - t);
        }
    }

    function floatBack(): void {
        // Nothing ever fell (no failed attempt), so there's nothing to settle
        // - going through the full 850ms return animation here just added a
        // dead pause between the right password and the pill animation.
        if (!dropped) {
            root.lock.lock.unlock();
            return;
        }

        dropped = false;
        for (const b of bodies) {
            b.startOx = b.ox;
            b.startOy = b.oy;
            b.startRot = b.rot;
            b.vx = 0;
            b.vy = 0;
            b.vr = 0;
        }
        returnProgress = 0;
        returnAnim.restart();
    }

    NumberAnimation {
        id: returnAnim

        target: root
        property: "returnProgress"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.InOutQuad
        onFinished: root.lock.lock.unlock()
    }

    Connections {
        function onSucceeded(): void {
            root.floatBack();
        }

        target: root.lock.pam
    }

    FrameAnimation {
        running: root.dropped
        onTriggered: {
            const dt = Math.min(0.033, frameTime);
            for (const b of root.bodies) {
                if (!b.visible)
                    continue;
                b.vy += root.gravity * dt;
                b.ox += b.vx * dt;
                b.oy += b.vy * dt;
                b.rot += b.vr * dt;

                // A rotated rectangle needs more room than its own width and
                // height, so the collision box is inset by how far its
                // corners can swing out. Without this they were bouncing off
                // the correct line but still visibly hanging over the edge.
                const rad = Math.abs(b.rot) * Math.PI / 180;
                const c = Math.abs(Math.cos(rad));
                const s = Math.abs(Math.sin(rad));
                const spanW = b.width * c + b.height * s;
                const spanH = b.width * s + b.height * c;
                // Only half the rotated overhang, and a hairline edge - using
                // the full span plus a 10px margin put the walls noticeably
                // inside the card, so things stopped short of the real edge
                // (and the left side felt like it wasn't there at all).
                const padX = (spanW - b.width) / 4;
                const padY = (spanH - b.height) / 4;
                const edge = 2;

                // Floor (and ceiling, so a hard upward kick can't launch it
                // out of the top of the card either)
                const floorOy = root.height - b.restY - b.height - padY - edge;
                const ceilOy = -b.restY + padY + edge;
                if (b.oy > floorOy) {
                    b.oy = floorOy;
                    b.vy = -b.vy * root.restitution;
                    b.vx *= root.friction;
                    b.vr *= 0.55;
                    // Settle instead of jittering forever.
                    if (Math.abs(b.vy) < 55) {
                        b.vy = 0;
                        b.vr *= 0.25;
                    }
                }
                if (b.oy < ceilOy) {
                    b.oy = ceilOy;
                    b.vy = -b.vy * root.restitution;
                    b.vr *= 0.7;
                }

                // Walls
                const leftOx = -b.restX + padX + edge;
                const rightOx = root.width - b.restX - b.width - padX - edge;
                if (b.ox < leftOx) {
                    b.ox = leftOx;
                    b.vx = -b.vx * 0.5;
                    b.vr *= 0.7;
                }
                if (b.ox > rightOx) {
                    b.ox = rightOx;
                    b.vx = -b.vx * 0.5;
                    b.vr *= 0.7;
                }
            }
        }
    }

    // Wrong password: shake, then everything falls.
    Connections {
        function onFlashMsg(): void {
            // Falls on the same frame as the jolt, not after the shake has
            // finished playing out.
            root.jolt();
            quake.restart();
            quakeX.restart();
        }

        target: root.lock.pam
    }

    // Unlocking (or a fresh lock) puts it all back.
    Connections {
        function onLockedChanged(): void {
            if (!root.lock.lock.locked)
                root.reset();
        }

        target: root.lock.lock
    }

    SequentialAnimation {
        id: quake

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: shakeShift
                    property: "y"
                    to: -9
                    duration: 45
                }
                NumberAnimation {
                    target: shakeShift
                    property: "y"
                    to: 0
                    duration: 420
                    easing.type: Easing.OutElastic
                    easing.amplitude: 2.4
                    easing.period: 0.18
                }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: shakeRot
                    property: "angle"
                    to: 1.6
                    duration: 45
                }
                NumberAnimation {
                    target: shakeRot
                    property: "angle"
                    to: 0
                    duration: 420
                    easing.type: Easing.OutElastic
                    easing.amplitude: 2.2
                    easing.period: 0.16
                }
            }
        }
    }

    SequentialAnimation {
        id: quakeX

        NumberAnimation {
            target: shakeShift
            property: "x"
            to: 26
            duration: 45
        }
        NumberAnimation {
            target: shakeShift
            property: "x"
            to: 0
            duration: 420
            easing.type: Easing.OutElastic
            easing.amplitude: 2.8
            easing.period: 0.14
        }
    }

    Item {
        id: shaken

        anchors.fill: parent

        transform: [
            Rotation {
                id: shakeRot

                origin.x: shaken.width / 2
                origin.y: shaken.height / 2
                angle: 0
            },
            Translate {
                id: shakeShift

                x: 0
                y: 0
            }
        ]

        PhysicsBody {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.extraLargeIncreased * 2
            // Once everything is on the floor it lands in one heap. Controls
            // you can actually operate have to end up on top of the clock,
            // avatar and password box, or the click goes to whatever decorative
            // body happens to be covering them.
            dropZ: 50

            VerticalSlider {
                icon: "brightness_medium"
                value: root.brightnessMonitor?.brightness ?? 0
                onMoved: v => root.brightnessMonitor?.setBrightness(v)
            }
        }

        // Volume goes through ALSA here, not PipeWire: there is no sound server
        // running for the greetd user. See Alsa.qml.
        PhysicsBody {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Tokens.padding.extraLargeIncreased * 2
            dropZ: 50

            visible: Alsa.available

            VerticalSlider {
                icon: Icons.getVolumeIcon(Alsa.volume, Alsa.muted)
                value: Alsa.volume
                onMoved: v => Alsa.setVolume(v)
                onIconClicked: Alsa.toggleMute()
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: root.centerWidth
            // Tightened from largeIncreased: the session pill and the power row
            // are now part of this stack, and at the old spacing the total ran
            // past the top of the card and clipped the clock.
            spacing: Tokens.spacing.large

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter

                Clock {
                    centerScale: root.centerScale
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: Time.format("dddd • d MMM").toUpperCase()
                    color: DarkAccent.textMuted
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.extraLarge * root.centerScale

                ProfilePic {
                    centerWidth: root.centerWidth
                    avatar: Users.currentAvatar
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter
                // Only while open, for the same reason as the session pill.
                dropZ: 60
                z: userPill.open ? 100 : 0

                // One account: just the name, as before. More than one: the
                // same pill/dropdown the session picker uses, so switching
                // user reads identically to switching WM.
                UserPill {
                    id: userPill
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.large * root.centerScale
                dropZ: 40

                PasswordInput {
                    centerScale: Math.max(0.8, root.centerScale)
                    centerWidth: root.centerWidth
                    lock: root.lock
                }
            }

            StateMessage {
                Layout.fillWidth: true
                pam: root.lock.pam
            }

            // Power actions above, session picker below.
            //
            // Both ride in the same column rather than being pinned to the
            // card's bottom edge. Anchoring them to the bottom while the rest
            // of the content was centred is what made them collide: the centred
            // stack grew downwards into a row that never moved.
            // Each button is its own rigid body, so a wrong password scatters
            // them individually instead of toppling the row as one slab.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.small

                PhysicsBody {
                    dropZ: 60

                    PowerButton {
                        icon: "power_settings_new"
                        action: ["/usr/bin/systemctl", "poweroff"]
                        danger: true
                    }
                }

                PhysicsBody {
                    dropZ: 60

                    PowerButton {
                        icon: "restart_alt"
                        action: ["/usr/bin/systemctl", "reboot"]
                        danger: true
                    }
                }

                PhysicsBody {
                    dropZ: 60

                    PowerButton {
                        icon: "downloading"
                        action: ["/usr/bin/systemctl", "hibernate"]
                        danger: true
                    }
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter
                visible: Sessions.sessions.length > 1
                // Float above the rest only while the menu is actually open.
                // Sitting permanently at z:100 meant that after a drop this
                // pill covered whatever it landed on and ate its clicks.
                dropZ: 60
                z: sessionPill.open ? 100 : 0

                SessionPill {
                    id: sessionPill
                }
            }
        }
    }



    // A rigid body. Sizes itself to its single child and moves that child by
    // transform only - the layout slot never moves, so nothing reflows and
    // the child stays fully interactive while it tumbles.
    component PhysicsBody: Item {
        id: body

        default property alias content: holder.data
        // The moving visual. Exposed because it reparents away from this item
        // while displaced, so body.children no longer finds it.
        readonly property alias visual: holder

        property real ox: 0
        property real oy: 0
        property real rot: 0
        property real vx: 0
        property real vy: 0
        property real vr: 0
        property real restX: 0
        property real restY: 0
        // Captured when the float-back starts, so each body can lerp home
        // from wherever it happened to land.
        property real startOx: 0
        property real startOy: 0
        property real startRot: 0
        // Stacking once everything is heaped together: controls you can
        // actually operate must end up above the decorative bodies.
        property int dropZ: 0

        implicitWidth: holder.implicitWidth
        implicitHeight: holder.implicitHeight

        Component.onCompleted: root.registerBody(body)

        Item {
            id: holder

            // While displaced, this reparents onto the card itself and takes an
            // absolute position; the rest of the time it sits inside its body
            // at the layout slot.
            //
            // Moving it *within* the body - by transform or by x/y - drew in
            // the right place but could not be clicked. Qt only descends into a
            // parent that contains the point, and the body never leaves its
            // layout slot, so a button lying at the bottom of the pile still
            // had its hit area up in the row. Reparenting makes the position
            // real, and the layout still never reflows because the body itself
            // never moves or changes size.
            parent: root.displaced ? shaken : body

            width: body.width
            height: body.height
            x: root.displaced ? body.restX + body.ox : 0
            y: root.displaced ? body.restY + body.oy : 0
            z: root.displaced ? body.dropZ : 0
            rotation: body.rot
            transformOrigin: Item.Center

            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }

    // Account picker. Degrades to a plain label on a single-user machine,
    // because a dropdown with one entry is just a worse label.
    //
    // Opens downwards - it sits mid-card, and opening upwards would cover the
    // avatar you just used to identify the account.
    component UserPill: Item {
        id: upill

        readonly property bool multi: Users.users.length > 1
        property bool open: false

        implicitWidth: multi ? bg.implicitWidth : plain.implicitWidth
        implicitHeight: multi ? bg.implicitHeight : plain.implicitHeight

        StyledText {
            id: plain

            anchors.centerIn: parent
            visible: !upill.multi
            text: Users.currentLabel
            color: DarkAccent.text
            font: Tokens.font.title.medium
        }

        StyledRect {
            id: bg

            anchors.centerIn: parent
            visible: upill.multi

            implicitWidth: uRow.implicitWidth + Tokens.padding.large * 2
            implicitHeight: uRow.implicitHeight + Tokens.padding.small * 2

            color: uMouse.containsMouse || upill.open ? DarkAccent.surfaceHigh : "transparent"
            radius: Tokens.rounding.full

            Behavior on color {
                CAnim {}
            }

            RowLayout {
                id: uRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: Users.currentLabel
                    color: DarkAccent.text
                    font: Tokens.font.title.medium
                }

                MaterialIcon {
                    text: upill.open ? "expand_less" : "unfold_more"
                    color: DarkAccent.textMuted
                    fontStyle: Tokens.font.icon.builders.small.build()
                }
            }

            MouseArea {
                id: uMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: upill.open = !upill.open
            }

            Connections {
                function onDroppedChanged(): void {
                    if (root.dropped)
                        upill.open = false;
                }

                target: root
            }
        }

        StyledRect {
            id: uMenu

            visible: upill.open
            anchors.top: bg.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: Math.max(bg.implicitWidth, 260 * root.centerScale)
            implicitHeight: Math.min(uList.contentHeight, 190 * root.centerScale) + Tokens.padding.small * 2

            color: DarkAccent.bg
            radius: Tokens.rounding.large

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 18
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.8)
            }

            ListView {
                id: uList

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                clip: true
                model: Users.users
                currentIndex: Users.index
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: uList.contentHeight > uList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                delegate: StyledRect {
                    required property int index
                    required property var modelData

                    width: uList.width - (uList.ScrollBar.vertical.visible ? uList.ScrollBar.vertical.width : 0)
                    implicitHeight: uItemRow.implicitHeight + Tokens.padding.small * 2

                    color: index === Users.index ? DarkAccent.surfaceHigh : uItemMouse.containsMouse ? DarkAccent.surface : "transparent"
                    radius: Tokens.rounding.small

                    Behavior on color {
                        CAnim {}
                    }

                    RowLayout {
                        id: uItemRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            text: "person"
                            color: DarkAccent.textMuted
                            fontStyle: Tokens.font.icon.builders.small.build()
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: DarkAccent.text
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            visible: index === Users.index
                            text: "check"
                            color: DarkAccent.accent
                            fontStyle: Tokens.font.icon.builders.small.build()
                        }
                    }

                    MouseArea {
                        id: uItemMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Users.index = index;
                            upill.open = false;
                        }
                    }
                }
            }
        }
    }

    // Session picker: a real dropdown. Pick your WM once and it stays picked -
    // logging in is then just typing the password, with no button to press.
    //
    // The list opens *upwards*, because this sits near the bottom of the card
    // and Content clips to the card edge; opening downwards would put it
    // outside the box. It scrolls once there are more entries than fit.
    component SessionPill: StyledRect {
        id: pill

        property bool open: false

        implicitWidth: pillRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: pillRow.implicitHeight + Tokens.padding.small * 2

        color: pillMouse.containsMouse || open ? DarkAccent.surfaceHigh : DarkAccent.surface
        radius: Tokens.rounding.full

        Behavior on color {
            CAnim {}
        }

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: Sessions.current?.type === "x11" ? "desktop_windows" : "monitor"
                color: DarkAccent.textMuted
                fontStyle: Tokens.font.icon.builders.small.build()
            }

            StyledText {
                text: Sessions.currentName
                color: DarkAccent.text
                font: Tokens.font.body.small
            }

            MaterialIcon {
                text: pill.open ? "expand_more" : "unfold_more"
                color: DarkAccent.textMuted
                fontStyle: Tokens.font.icon.builders.small.build()
            }
        }

        MouseArea {
            id: pillMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.open = !pill.open
        }

        // A menu left hanging open over a tumbling pile would sit on top of
        // everything and swallow clicks meant for whatever landed under it.
        Connections {
            function onDroppedChanged(): void {
                if (root.dropped)
                    pill.open = false;
            }

            target: root
        }

        StyledRect {
            id: menu

            visible: pill.open
            anchors.bottom: pill.top
            anchors.bottomMargin: Tokens.spacing.small
            anchors.horizontalCenter: pill.horizontalCenter

            implicitWidth: Math.max(pill.implicitWidth, 260 * root.centerScale)
            // Cap the height so a long session list scrolls instead of growing
            // up through the rest of the card.
            implicitHeight: Math.min(list.contentHeight, 190 * root.centerScale) + Tokens.padding.small * 2

            color: DarkAccent.bg
            radius: Tokens.rounding.large

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 18
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.8)
            }

            ListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                clip: true
                model: Sessions.sessions
                currentIndex: Sessions.index
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                delegate: StyledRect {
                    required property int index
                    required property var modelData

                    width: list.width - (list.ScrollBar.vertical.visible ? list.ScrollBar.vertical.width : 0)
                    implicitHeight: itemRow.implicitHeight + Tokens.padding.small * 2

                    color: index === Sessions.index ? DarkAccent.surfaceHigh : itemMouse.containsMouse ? DarkAccent.surface : "transparent"
                    radius: Tokens.rounding.small

                    Behavior on color {
                        CAnim {}
                    }

                    RowLayout {
                        id: itemRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            text: modelData.type === "x11" ? "desktop_windows" : "monitor"
                            color: DarkAccent.textMuted
                            fontStyle: Tokens.font.icon.builders.small.build()
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: DarkAccent.text
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            visible: index === Sessions.index
                            text: "check"
                            color: DarkAccent.accent
                            fontStyle: Tokens.font.icon.builders.small.build()
                        }
                    }

                    MouseArea {
                        id: itemMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sessions.index = index;
                            pill.open = false;
                        }
                    }
                }
            }
        }
    }


    // Commands are absolute: greetd hands the greeter an environment with no
    // PATH, so a bare "systemctl" simply fails to resolve and the button
    // appears to do nothing at all.
    //
    // Two-step: the first press arms, the second commits. Everything else on
    // this screen is recoverable; powering the machine off from under someone
    // mid-password is not.
    component PowerButton: StyledRect {
        id: pb

        required property string icon
        // Either run a command, or emit activated() for callers that just want
        // a handler. Optional so the session switch can use the latter.
        property var action: []
        property bool danger: false
        property bool armed: false
        // Skips the arm/confirm step, for actions that aren't destructive.
        property bool instant: false

        signal activated

        implicitWidth: 40
        implicitHeight: 40
        radius: Tokens.rounding.full

        color: armed ? (danger ? Colours.palette.m3error : DarkAccent.accent) : pbMouse.containsMouse ? DarkAccent.surfaceHigh : DarkAccent.surface

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: pb.icon
            color: pb.armed ? DarkAccent.bg : DarkAccent.textMuted
            fontStyle: Tokens.font.icon.builders.small.build()

            Behavior on color {
                CAnim {}
            }
        }

        Timer {
            id: disarm

            interval: 2500
            onTriggered: pb.armed = false
        }

        MouseArea {
            id: pbMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pb.instant) {
                    pb.activated();
                    return;
                }

                if (pb.armed) {
                    disarm.stop();
                    if (pb.action.length > 0)
                        Quickshell.execDetached(pb.action);
                    else
                        pb.activated();
                } else {
                    pb.armed = true;
                    disarm.restart();
                }
            }
        }
    }

    // StyledSlider is built horizontal only (everything inside anchors to
    // verticalCenter), so it gets rotated rather than rewritten.
    component VerticalSlider: Item {
        id: vs

        required property string icon
        property real value: 0
        signal moved(real v)
        signal iconClicked

        implicitWidth: 48
        implicitHeight: 320

        StyledSlider {
            anchors.centerIn: parent

            width: vs.height - vs.implicitWidth
            rotation: -90

            value: vs.value
            interactionOnMove: true
            fgColour: DarkAccent.accent
            bgColour: DarkAccent.surfaceHigh
            onInteraction: v => vs.moved(v)
        }

        MaterialIcon {
            id: vsIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: vs.icon
            color: vsMouse.containsMouse ? DarkAccent.accent : DarkAccent.textMuted

            Behavior on color {
                CAnim {}
            }

            MouseArea {
                id: vsMouse

                anchors.fill: parent
                anchors.margins: -Tokens.padding.small
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: vs.iconClicked()
            }
        }
    }
}
