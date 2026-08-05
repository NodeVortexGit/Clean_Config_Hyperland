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

    // Right-clicking the idle pill cycles between whichever of timer/music/idle
    // are currently available, overriding the automatic priority below. Falls
    // back to auto the moment the overridden state stops being available.
    property string restingOverride: ""

    readonly property string restingMode: {
        if (restingOverride === "timer" && hasTimer)
            return "timer";
        if (restingOverride === "music" && hasMusic)
            return "music";
        if (restingOverride === "idle")
            return "idle";
        return hasTimer ? "timer" : hasMusic ? "music" : "idle";
    }

    function cycleRestingMode(): void {
        const available = ["timer", "music", "idle"].filter(m => m === "timer" ? hasTimer : m === "music" ? hasMusic : true);
        if (available.length <= 1)
            return;
        const idx = available.indexOf(restingOverride || restingMode);
        restingOverride = available[(idx + 1) % available.length];
    }

    onHasTimerChanged: {
        if (restingOverride === "timer" && !hasTimer)
            restingOverride = "";
    }

    onHasMusicChanged: {
        if (restingOverride === "music" && !hasMusic)
            restingOverride = "";
    }

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

    // The notification currently offering an inline reply, if any. The island
    // expands into a reply box for it instead of the plain notification strip.
    property var replyNotif: null
    // Set by the reply box while there's text in it - holds the fade off so a
    // half-typed reply can't vanish mid-sentence. Empty box still fades on the
    // normal notification timeout.
    property bool replyHeld: false

    function notify(): void {
        const n = Notifs.popups[0] ?? null;
        if (n?.hasInlineReply) {
            replyNotif = n;
            replyHeld = false;
            transientMode = "reply";
        } else {
            transientMode = "notification";
        }
        transientTimer.interval = 5000;
        transientTimer.restart();
    }

    function holdReply(held: bool): void {
        if (transientMode !== "reply")
            return;
        replyHeld = held;
        if (held)
            transientTimer.stop();
        else
            transientTimer.restart();
    }

    function sendReply(text: string): void {
        if (text.length > 0)
            replyNotif?.sendInlineReply(text);
        dismissReply();
    }

    function dismissReply(): void {
        replyHeld = false;
        replyNotif = null;
        transientTimer.stop();
        transientMode = "";
    }

    function flashWorkspace(): void {
        if (transientMode === "notification" || transientMode === "reply")
            return;
        transientMode = "workspace";
        transientTimer.interval = 1500;
        transientTimer.restart();
    }

    function flashVolume(): void {
        if (transientMode === "notification" || transientMode === "reply")
            return;
        transientMode = "volume";
        transientTimer.interval = Config.osd.hideDelay;
        transientTimer.restart();
    }

    function flashBrightness(): void {
        if (transientMode === "notification" || transientMode === "reply")
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

    property string hotplugMessage: ""

    function flashHotplug(message: string): void {
        if (transientMode === "notification" || transientMode === "reply")
            return;
        hotplugMessage = message;
        transientMode = "hotplug";
        transientTimer.interval = 3000;
        transientTimer.restart();
    }

    property bool budsLowBatteryWarned: false

    function flashBudsLowBattery(): void {
        if (transientMode === "notification" || transientMode === "reply")
            return;
        transientMode = "budslowbattery";
        transientTimer.interval = 4000;
        transientTimer.restart();
    }

    // GalaxyBudsClient only exposes battery/device info over DBus, not the
    // current ANC/Transparency mode - there's nothing to poll for that, so
    // this is just battery level, checked both reactively and once whenever
    // a fresh reading comes in (mirrors the laptop's own low-battery check).
    function checkBudsLowBattery(): void {
        if (!GalaxyBuds.connected || !GalaxyBuds.device) {
            root.budsLowBatteryWarned = false;
            return;
        }
        const left = GalaxyBuds.device.BatteryLeft ?? 100;
        const right = GalaxyBuds.device.BatteryRight ?? 100;
        const min = Math.min(left >= 0 ? left : 100, right >= 0 ? right : 100);
        if (min <= 20 && !root.budsLowBatteryWarned) {
            root.budsLowBatteryWarned = true;
            root.flashBudsLowBattery();
        } else if (min > 30) {
            root.budsLowBatteryWarned = false;
        }
    }

    Connections {
        function onDeviceChanged(): void {
            root.checkBudsLowBattery();
        }

        target: GalaxyBuds
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

    // Always opens straight to the settings grid regardless of what's
    // currently playing/showing, and closes on a second call - used by both
    // the Meta-key shortcut and a normal pill tap, so the quick panel is
    // reachable the same way whether or not something's playing.
    function toggleQuickPanel(): void {
        if (fullyExpanded) {
            collapse();
        } else {
            transientTimer.stop();
            transientMode = "";
            forceSettingsPage = true;
            fullyExpanded = true;
        }
    }

    function collapse(): void {
        fullyExpanded = false;
        forceSettingsPage = false;
        // Closing the pill is what releases the "stay on whatever I was
        // listening to" latch - until then a paused browser tab keeps the
        // island instead of it flipping back to Spotify.
        Players.clearSticky();
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

    // Checked both reactively (battery draining further) and once on startup,
    // since a shell restart while already under 20% would otherwise never see
    // a percentageChanged signal to trigger off of.
    function checkLowBattery(): void {
        const pct = UPower.displayDevice.percentage;
        if (UPower.onBattery && pct <= 0.2 && !root.lowBatteryWarned) {
            root.lowBatteryWarned = true;
            root.flashLowBattery();
        } else if (pct > 0.3 || !UPower.onBattery) {
            root.lowBatteryWarned = false;
        }
    }

    Component.onCompleted: root.checkLowBattery()

    Connections {
        function onPercentageChanged(): void {
            root.checkLowBattery();
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

        function state(): string {
            return `mode=${root.mode} fullyExpanded=${root.fullyExpanded} forceSettingsPage=${root.forceSettingsPage} transientMode=${root.transientMode}`;
        }

        function cycle(): void {
            root.cycleRestingMode();
        }

        function settings(): void {
            transientTimer.stop();
            root.transientMode = "";
            root.forceSettingsPage = true;
            root.fullyExpanded = true;
        }

        // Bound to a Meta-alone tap: opens straight to the settings grid
        // regardless of what the pill is currently showing, and closes it
        // again on a second tap instead of just re-forcing it open.
        function toggleSettings(): void {
            root.toggleQuickPanel();
        }

        target: "island"
    }
}
