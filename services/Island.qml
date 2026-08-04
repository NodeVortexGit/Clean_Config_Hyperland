pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    // Resting "Live Activity" state: what the island shows when nothing transient is happening
    readonly property bool hasTimer: Timers.active !== null
    readonly property bool hasMusic: (Players.active?.isPlaying ?? false)
    readonly property string restingMode: hasTimer ? "timer" : hasMusic ? "music" : "idle"

    // Transient overlays win over the resting mode, then time out back to it
    property string transientMode: ""
    // User-opened overlay (workspaces/tray/status/power), toggled by clicking the pill
    property bool menuOpen: false

    readonly property string mode: transientMode !== "" ? transientMode : (menuOpen ? "menu" : restingMode)
    readonly property bool expanded: transientMode !== "" || menuOpen

    function notify(): void {
        transientMode = "notification";
        menuOpen = false;
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

    function toggleMenu(): void {
        if (transientMode !== "")
            return;
        menuOpen = !menuOpen;
    }

    function closeMenu(): void {
        menuOpen = false;
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
}
