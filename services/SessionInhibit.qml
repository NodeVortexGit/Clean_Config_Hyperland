pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the session awake while it is obviously in use, in the two cases the
// compositor cannot see for itself.
//
// Gamepads: Wayland resets the idle timer on keyboard, pointer and touch only.
// A controller is just another evdev device, so an hour of gaming looks
// identical to an hour of sitting still - the screen dims and then locks
// mid-game. assets/gamepad-watch.py reports genuine controller activity.
//
// Audio: the shell already inhibits while an MPRIS player is playing, but games
// and Proton titles publish no MPRIS player at all, so that check misses
// precisely the thing most likely to be running for hours without a keypress.
// Counting uncorked PipeWire streams catches anything actually producing sound,
// and correctly ignores a paused player.
Singleton {
    id: root

    // How long after the last controller event the session stays held awake.
    // Long enough to sit through a cutscene or a loading screen without the
    // screen dying, short enough that walking away still eventually locks.
    property int gamepadGraceSec: 180
    // Audio is polled; it has no event source worth subscribing to here.
    property int audioPollSec: 10

    readonly property bool inhibited: gamepadActive || audioPlaying

    property bool gamepadActive: false
    property bool audioPlaying: false

    Process {
        running: true
        command: ["python3", `${Quickshell.shellDir}/assets/gamepad-watch.py`]

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "active")
                    return;
                root.gamepadActive = true;
                grace.restart();
            }
        }
    }

    Timer {
        id: grace

        interval: root.gamepadGraceSec * 1000
        onTriggered: root.gamepadActive = false
    }

    Process {
        id: audioProc

        // "Corked" is PipeWire/Pulse for paused. An uncorked sink input is a
        // stream actually feeding audio out right now.
        command: ["sh", "-c", "pactl list sink-inputs 2>/dev/null | grep -c 'Corked: no'"]

        stdout: StdioCollector {
            onStreamFinished: root.audioPlaying = parseInt(text.trim() || "0", 10) > 0
        }
    }

    Timer {
        running: true
        interval: root.audioPollSec * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!audioProc.running)
            audioProc.running = true
    }
}
