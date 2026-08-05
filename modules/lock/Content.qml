import "center"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
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

    // Registered rigid bodies (see PhysicsBody).
    property var bodies: []
    property bool dropped: false

    readonly property real gravity: 2800
    readonly property real restitution: 0.42
    readonly property real friction: 0.74

    function registerBody(b): void {
        bodies.push(b);
    }

    // Every failed attempt adds another impulse - the first knocks everything
    // loose, later ones kick the pile again wherever it has come to rest.
    function jolt(): void {
        if (!dropped) {
            dropped = true;
            for (const b of bodies) {
                const p = b.mapToItem(root, 0, 0);
                b.restX = p.x - b.ox;
                b.restY = p.y - b.oy;
            }
        }

        for (const b of bodies) {
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

            VerticalSlider {
                icon: "brightness_medium"
                value: Island.brightnessMonitor?.brightness ?? 0
                onMoved: v => Island.brightnessMonitor?.setBrightness(v)
            }
        }

        PhysicsBody {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Tokens.padding.extraLargeIncreased * 2

            VerticalSlider {
                icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: root.centerWidth
            spacing: Tokens.spacing.largeIncreased

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
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: Quickshell.env("USER") ?? ""
                    color: DarkAccent.text
                    font: Tokens.font.title.medium
                }
            }

            PhysicsBody {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.large * root.centerScale

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
        }
    }

    // A rigid body. Sizes itself to its single child and moves that child by
    // transform only - the layout slot never moves, so nothing reflows and
    // the child stays fully interactive while it tumbles.
    component PhysicsBody: Item {
        id: body

        default property alias content: holder.data

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

        implicitWidth: holder.implicitWidth
        implicitHeight: holder.implicitHeight

        Component.onCompleted: root.registerBody(body)

        Item {
            id: holder

            anchors.fill: parent
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0

            transform: [
                Rotation {
                    origin.x: holder.width / 2
                    origin.y: holder.height / 2
                    angle: body.rot
                },
                Translate {
                    x: body.ox
                    y: body.oy
                }
            ]
        }
    }

    // StyledSlider is built horizontal only (everything inside anchors to
    // verticalCenter), so it gets rotated rather than rewritten.
    component VerticalSlider: Item {
        id: vs

        required property string icon
        property real value: 0
        signal moved(real v)

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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: vs.icon
            color: DarkAccent.textMuted
        }
    }
}
