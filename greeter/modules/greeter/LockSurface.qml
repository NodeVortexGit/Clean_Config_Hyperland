pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.modules.greeter
import qs.services

// The lock surface, re-hosted for the greeter.
//
// Two things change versus the lock screen and nothing else does:
//
//  1. WlSessionLockSurface -> PanelWindow on the overlay layer with exclusive
//     keyboard focus. ext-session-lock locks a session that already exists;
//     before login there is no session to lock, so we take the screen as a
//     layershell window instead.
//
//  2. The blurred backdrop was a ScreencopyView of the live desktop. There is
//     no desktop to capture pre-login, so it becomes a wallpaper image blurred
//     the same way, which lands on the same look.
//
// The whole animation chain - pill drop, bolt, explode-open, and the reverse
// on unlock - is untouched.
PanelWindow {
    id: root

    required property var lock
    required property var pam

    readonly property alias unlocking: unlockAnim.running

    WlrLayershell.namespace: "caelestia-greeter"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive is what makes this a login screen rather than a window: no
    // other client can receive a keystroke. In demo mode that would make a
    // test session unrecoverable from the keyboard, so it's downgraded.
    WlrLayershell.keyboardFocus: GreeterInfo.demo ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "transparent"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        // Strictly one step at a time - doing these together (as it used to)
        // meant the panel faded out while it shrank, so you never actually
        // saw it get sucked back into the pill.

        // 1. everything fades out
        ParallelAnimation {
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: content
                property: "scale"
                to: 0
            }
        }

        // 2. the panel sucks back down into the pill shape
        ParallelAnimation {
            Anim {
                target: lockContent
                property: "implicitWidth"
                to: lockContent.pillWidth
            }
            Anim {
                target: lockContent
                property: "implicitHeight"
                to: lockContent.pillHeight
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
        }

        // 3. the bolt springs open again
        ScriptAction {
            script: lockIcon.shut = false
        }
        PauseAnimation {
            duration: 180
        }

        // 4. and the pill travels back up to where the island lives
        NumberAnimation {
            target: lockContent
            property: "dropY"
            to: -(root.height / 2) - lockContent.size
            duration: 300
            easing.type: Easing.InBack
            easing.overshoot: 1.1
        }

        // 5. only then does the backdrop clear...
        ParallelAnimation {
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                type: Anim.Standard
                target: lockContent
                property: "opacity"
                to: 0
            }
        }

        // 6. ...and only then do we hand off to greetd. Starting the session
        // any earlier means greetd execs the compositor while this animation
        // is still playing and the whole thing is cut off mid-frame.
        ScriptAction {
            script: root.pam.startSession()
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: background
            property: "opacity"
            to: 1
            type: Anim.StandardLarge
        }
        SequentialAnimation {
            // 1. the pill drops from the top into the middle
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.standardAccel
                }
                NumberAnimation {
                    target: lockContent
                    property: "dropY"
                    to: 0
                    duration: 480
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }
            // 2. it lands and throws the bolt
            ScriptAction {
                script: lockIcon.shut = true
            }
            PauseAnimation {
                duration: 420
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: content
                    property: "opacity"
                    to: 1
                }
                Anim {
                    target: content
                    property: "scale"
                    to: 1
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: lockContent.Tokens.rounding.extraLarge * 1.5
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult * lockContent.Tokens.sizes.lock.ratio
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: background.opacity
    }

    Image {
        id: background

        anchors.fill: parent
        source: GreeterInfo.wallpaper ? `file://${GreeterInfo.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: 0

        // Match the resolution we actually draw at; the source is often far
        // larger and would otherwise be decoded at full size for no gain.
        sourceSize.width: root.screen?.width ?? 1920
        sourceSize.height: root.screen?.height ?? 1080

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        // A capsule, matching the island pill it's meant to have come from -
        // it used to be a rounded square, which is why it never read as "the
        // pill travelled down here".
        readonly property int pillWidth: size * 1.9
        readonly property int pillHeight: size
        readonly property int radius: pillHeight / 2

        anchors.centerIn: parent
        implicitWidth: pillWidth
        implicitHeight: pillHeight

        rotation: 180
        scale: 0

        // Starts up where the island pill sits and falls to the middle before
        // exploding open (see initAnim), so the handoff from the pill reads as
        // one continuous movement. Reversed on unlock.
        property real dropY: -(parent.height / 2) - size

        transform: Translate {
            y: lockContent.dropY
        }

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: DarkAccent.bg
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            // Arrives open (nothing has been unlocked yet), snaps shut once it
            // lands, and springs back open once greetd accepts the password.
            property bool shut: false

            anchors.centerIn: parent
            text: shut ? "lock" : "lock_open"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            rotation: 180

            // A little clunk as it throws the bolt.
            Behavior on shut {
                SequentialAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "scale"
                        to: 0.72
                        duration: 90
                        easing.type: Easing.OutQuad
                    }
                    PropertyAction {}
                    NumberAnimation {
                        target: lockIcon
                        property: "scale"
                        to: 1
                        duration: 420
                        easing.type: Easing.OutElastic
                        easing.amplitude: 1.3
                        easing.period: 0.34
                    }
                }
            }
        }

        Content {
            id: content

            anchors.centerIn: parent
            width: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased
            height: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased

            lock: root
            opacity: 0
            scale: 0
        }
    }
}
