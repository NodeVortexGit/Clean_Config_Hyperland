pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import qs.services

Singleton {
    id: root

    // Resting "Live Activity" state: what the island shows when nothing transient is happening
    readonly property bool hasTimer: Timers.active !== null
    readonly property bool hasMusic: (Players.active?.isPlaying ?? false)
    readonly property string restingMode: hasTimer ? "timer" : hasMusic ? "music" : "idle"

    readonly property Brightness.Monitor brightnessMonitor: Brightness.getMonitor("active")

    property bool lowBatteryWarned: false

    // Transient overlays win over the resting mode, then time out back to it
    property string transientMode: ""
    // Full-screen quick-settings / media takeover, toggled by tapping the pill
    property bool fullyExpanded: false
    // While fullyExpanded and music is playing, the default page is "media";
    // this lets the user explicitly ask for the quick-settings grid instead.
    property bool forceSettingsPage: false

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

    function flashCharging(): void {
        transientMode = "charging";
        transientTimer.interval = 3000;
        transientTimer.restart();
    }

    function flashUnplugged(): void {
        transientMode = "unplugged";
        transientTimer.interval = 3000;
        transientTimer.restart();
    }

    function flashLowBattery(): void {
        transientMode = "lowbattery";
        transientTimer.interval = 4000;
        transientTimer.restart();
    }

    function toggleFullyExpanded(): void {
        // A tap always means "I want to interact now" - drop whatever transient
        // is showing (a stuck/repeating transient must never make the island
        // permanently untappable) and open/close the full expansion.
        transientTimer.stop();
        transientMode = "";
        if (fullyExpanded) {
            fullyExpanded = false;
        } else {
            forceSettingsPage = false;
            fullyExpanded = true;
        }
    }

    function showSettingsPage(): void {
        forceSettingsPage = true;
    }

    function collapse(): void {
        fullyExpanded = false;
        forceSettingsPage = false;
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

    Connections {
        function onOnBatteryChanged(): void {
            if (UPower.onBattery)
                root.flashUnplugged();
            else
                root.flashCharging();
        }

        target: UPower
    }

    Connections {
        function onPercentageChanged(): void {
            const pct = UPower.displayDevice.percentage;
            if (UPower.onBattery && pct <= 0.2 && !root.lowBatteryWarned) {
                root.lowBatteryWarned = true;
                root.flashLowBattery();
            } else if (pct > 0.3 || !UPower.onBattery) {
                root.lowBatteryWarned = false;
            }
        }

        target: UPower.displayDevice
    }

    IpcHandler {
        function toggle(): void {
            root.toggleFullyExpanded();
        }

        function collapse(): void {
            root.collapse();
        }

        target: "island"
    }
}
