pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Singleton {
    id: root

    // Resting "Live Activity" state: what the island shows when nothing transient is happening
    readonly property bool hasTimer: Timers.active !== null
    readonly property bool hasMusic: (Players.active?.isPlaying ?? false)
    readonly property string restingMode: hasTimer ? "timer" : hasMusic ? "music" : "idle"

    readonly property Brightness.Monitor brightnessMonitor: Brightness.getMonitor("active")

    // Transient overlays win over the resting mode, then time out back to it
    property string transientMode: ""
    // Full-screen quick-settings / media takeover, toggled by tapping the pill
    property bool fullyExpanded: false

    readonly property string mode: transientMode !== "" ? transientMode : restingMode
    readonly property bool expanded: transientMode !== "" || fullyExpanded

    function notify(): void {
        transientMode = "notification";
        transientTimer.interval = 5000;
        transientTimer.restart();
    }

    function flashWorkspace(): void {
        if (transientMode === "notification")
            return;
        transientMode = "workspace";
        transientTimer.interval = 1500;
        transientTimer.restart();
    }

    function flashVolume(): void {
        if (transientMode === "notification")
            return;
        transientMode = "volume";
        transientTimer.interval = Config.osd.hideDelay;
        transientTimer.restart();
    }

    function flashBrightness(): void {
        if (transientMode === "notification")
            return;
        transientMode = "brightness";
        transientTimer.interval = Config.osd.hideDelay;
        transientTimer.restart();
    }

    function toggleFullyExpanded(): void {
        if (transientMode !== "")
            return;
        fullyExpanded = !fullyExpanded;
    }

    function collapse(): void {
        fullyExpanded = false;
    }

    function dismissTransient(): void {
        transientTimer.stop();
        transientMode = "";
    }

    Timer {
        id: transientTimer

        repeat: false
        onTriggered: root.transientMode = ""
    }

    Connections {
        function onPopupsChanged() {
            if (Notifs.popups.length > 0)
                root.notify();
        }

        target: Notifs
    }

    Connections {
        function onActiveWsIdChanged() {
            root.flashWorkspace();
        }

        target: Hypr
    }

    Connections {
        function onMutedChanged(): void {
            root.flashVolume();
        }

        function onVolumeChanged(): void {
            root.flashVolume();
        }

        function onSourceMutedChanged(): void {
            if (Config.osd.enableMicrophone)
                root.flashVolume();
        }

        function onSourceVolumeChanged(): void {
            if (Config.osd.enableMicrophone)
                root.flashVolume();
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            root.flashBrightness();
        }

        target: root.brightnessMonitor
    }
}
