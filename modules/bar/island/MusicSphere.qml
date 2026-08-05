pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    readonly property var player: Players.active

    // ---- progress vs volume fill, swapping mechanic ----
    // Default shows how close the song is to ending; a volume change takes
    // over the same fill for 5s, then it reverts back to song progress.
    property bool showingVolume: false

    Timer {
        id: revertTimer
        interval: 5000
        onTriggered: root.showingVolume = false
    }

    Connections {
        function onVolumeChanged(): void {
            root.showingVolume = true;
            revertTimer.restart();
        }

        target: Audio
    }

    readonly property real fillFraction: {
        if (showingVolume)
            return Math.min(1, Audio.volume);
        const p = root.player;
        if (!p || !p.length || p.length <= 0)
            return 0;
        return Math.min(1, p.position / p.length);
    }

    // Scaling the circle's diameter linearly with the fraction makes it look
    // near-empty well before it actually is, since the filled AREA only grows
    // with the square of the diameter - sqrt compensates so "30% full" reads
    // as visually ~30% full instead of a barely-there dot.
    readonly property real fillDiameterFraction: Math.sqrt(root.fillFraction)

    // Position isn't push-updated by MPRIS - force a re-read while playing,
    // same mechanic used by the dashboard's media Details widget.
    Timer {
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        running: root.player?.isPlaying ?? false
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // ---- audio-reactive pulse: the louder it is, the crazier the blob ----
    ServiceRef {
        service: Audio.cava
    }

    // Cava's spectrum is ordered low-to-high frequency - split into three
    // bands so different layers of the blob react to different parts of the
    // mix instead of everything moving in lockstep.
    readonly property var cavaBands: {
        const vals = Audio.cava.values;
        if (!vals || vals.length === 0)
            return [0, 0, 0];
        const third = Math.max(1, Math.floor(vals.length / 3));
        const avg = (from, to) => {
            let sum = 0;
            for (let i = from; i < to; i++)
                sum += vals[i];
            return sum / (to - from);
        };
        return [avg(0, third), avg(third, third * 2), avg(third * 2, vals.length)];
    }

    property real bass: cavaBands[0]
    property real mid: cavaBands[1]
    property real treble: cavaBands[2]

    Behavior on bass {
        Anim {
            duration: 80
            easing.type: Easing.OutElastic
            easing.amplitude: 1.5
            easing.period: 0.35
        }
    }

    Behavior on mid {
        Anim {
            duration: 100
            easing.type: Easing.OutElastic
            easing.amplitude: 1.5
            easing.period: 0.35
        }
    }

    Behavior on treble {
        Anim {
            duration: 120
            easing.type: Easing.OutElastic
            easing.amplitude: 1.5
            easing.period: 0.35
        }
    }

    readonly property bool audioActive: (player?.isPlaying ?? false)

    // Overall loudness scales how dramatic the whole thing gets - quiet
    // passages barely move, loud ones make it swing hard.
    property real loudness: (bass + mid + treble) / 3
    Behavior on loudness {
        Anim {
            duration: 150
        }
    }

    readonly property real intensity: (audioActive ? 1 : 0) * (0.15 + loudness * 1.6)

    readonly property real pulseScaleX: 1 + bass * 0.3 * intensity
    readonly property real pulseScaleY: 1 - bass * 0.2 * intensity

    // Press physics: the dent goes IN at wherever you actually touched, like
    // pressing a finger into a slimy ball - not a uniform bounce. The squash
    // axis is rotated to the press direction, the far side bulges out to
    // compensate, and the whole thing shifts slightly away from the finger,
    // then wobbles back on an elastic curve.
    property real squish: 0
    // Direction from the sphere's centre to the press point.
    property real pokeAngle: 0
    property real pokeDirX: 0
    property real pokeDirY: 0
    // How far out the press was (0 = dead centre, 1 = edge). A centre press
    // squashes evenly; an edge press dents hard on that side.
    property real pokeReach: 0

    Behavior on squish {
        NumberAnimation {
            duration: 820
            easing.type: Easing.OutElastic
            easing.amplitude: 1.2
            easing.period: 0.4
        }
    }

    function pokeAt(px: real, py: real): void {
        const cx = sphere.width / 2;
        const cy = sphere.height / 2;
        const dx = px - cx;
        const dy = py - cy;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const radius = Math.max(1, sphere.width / 2);

        pokeReach = Math.min(1, dist / radius);
        if (dist > 0.001) {
            pokeDirX = dx / dist;
            pokeDirY = dy / dist;
            pokeAngle = Math.atan2(dy, dx) * 180 / Math.PI;
        } else {
            pokeDirX = 0;
            pokeDirY = 0;
            pokeAngle = 0;
        }

        squish = 1;
        releaseSquish.restart();
    }

    Timer {
        id: releaseSquish

        interval: 110
        onTriggered: root.squish = 0
    }

    Item {
        id: sphere

        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        transform: [
            // 1. audio pulse, unchanged
            Scale {
                origin.x: sphere.width / 2
                origin.y: sphere.height / 2
                xScale: root.pulseScaleX
                yScale: root.pulseScaleY
            },
            // 2-4. rotate the press direction onto the X axis, compress along
            // it (the dent) while bulging perpendicular (displaced volume),
            // then rotate back - so the squash always lines up with wherever
            // the finger went in.
            Rotation {
                origin.x: sphere.width / 2
                origin.y: sphere.height / 2
                angle: -root.pokeAngle
            },
            Scale {
                origin.x: sphere.width / 2
                origin.y: sphere.height / 2
                xScale: 1 - root.squish * 0.22
                yScale: 1 + root.squish * 0.13
            },
            Rotation {
                origin.x: sphere.width / 2
                origin.y: sphere.height / 2
                angle: root.pokeAngle
            },
            // 5. give slightly under the finger - more so nearer the edge.
            Translate {
                x: root.squish * root.pokeDirX * root.pokeReach * 14
                y: root.squish * root.pokeDirY * root.pokeReach * 14
            }
        ]

        Rectangle {
            id: base

            anchors.fill: parent
            radius: width / 2
            color: DarkAccent.surfaceHigh
            border.width: 1
            border.color: DarkAccent.border
        }

        // Two extra translucent layers, each driven by a different frequency
        // band and spinning at a loudness-scaled speed, overlapping the base
        // circle to read as one irregular blob instead of a clean scale.
        Rectangle {
            id: blobMid

            anchors.centerIn: parent
            width: parent.width * 0.94
            height: width
            radius: width / 2
            color: Qt.alpha(DarkAccent.accent, 0.16)
            transform: [
                Rotation {
                    id: blobMidSpin
                    origin.x: blobMid.width / 2
                    origin.y: blobMid.height / 2

                    RotationAnimation on angle {
                        running: root.audioActive
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: Math.max(600, 3200 - root.loudness * 2600)
                    }
                },
                Scale {
                    origin.x: blobMid.width / 2
                    origin.y: blobMid.height / 2
                    xScale: 1 - root.mid * 0.28 * root.intensity
                    yScale: 1 + root.mid * 0.34 * root.intensity
                }
            ]
        }

        Rectangle {
            id: blobTreble

            anchors.centerIn: parent
            width: parent.width * 0.88
            height: width
            radius: width / 2
            color: Qt.alpha(DarkAccent.accent, 0.14)
            transform: [
                Rotation {
                    id: blobTrebleSpin
                    origin.x: blobTreble.width / 2
                    origin.y: blobTreble.height / 2
                    angle: 45

                    RotationAnimation on angle {
                        running: root.audioActive
                        loops: Animation.Infinite
                        from: 45
                        to: -315
                        duration: Math.max(450, 2200 - root.loudness * 1900)
                    }
                },
                Scale {
                    origin.x: blobTreble.width / 2
                    origin.y: blobTreble.height / 2
                    xScale: 1 + root.treble * 0.4 * root.intensity
                    yScale: 1 - root.treble * 0.22 * root.intensity
                }
            ]
        }

        Rectangle {
            width: parent.width * root.fillDiameterFraction
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Qt.alpha(DarkAccent.accent, 0.55)

            Behavior on width {
                Anim {}
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
            color: DarkAccent.text
            fontStyle: Tokens.font.icon.builders.large.scale(1.8).build()
        }

        // Tap zones: left third = previous, middle third = play/pause, right
        // third = next - the whole sphere is the control surface.
        RowLayout {
            anchors.fill: parent
            spacing: 0

            StateLayer {
                anchors.fill: undefined
                Layout.fillWidth: true
                Layout.fillHeight: true
                stateOpacity: 0
                disabled: !(root.player?.canGoPrevious ?? false)
                onPressed: e => root.pokeAt(mapToItem(sphere, e.x, e.y).x, mapToItem(sphere, e.x, e.y).y)
                onClicked: root.player?.previous()
            }

            StateLayer {
                anchors.fill: undefined
                Layout.fillWidth: true
                Layout.fillHeight: true
                stateOpacity: 0
                disabled: !(root.player?.canTogglePlaying ?? false)
                onPressed: e => root.pokeAt(mapToItem(sphere, e.x, e.y).x, mapToItem(sphere, e.x, e.y).y)
                onClicked: root.player?.togglePlaying()
            }

            StateLayer {
                anchors.fill: undefined
                Layout.fillWidth: true
                Layout.fillHeight: true
                stateOpacity: 0
                disabled: !(root.player?.canGoNext ?? false)
                onPressed: e => root.pokeAt(mapToItem(sphere, e.x, e.y).x, mapToItem(sphere, e.x, e.y).y)
                onClicked: root.player?.next()
            }
        }
    }
}
