pragma Singleton

import QtQuick
import Quickshell

// Static blackish/dark-blue theme for the island's quick-settings panel and
// the power menu, independent of the wallpaper-derived Material You palette
// used everywhere else.
Singleton {
    readonly property color bg: "#0a0b10"
    readonly property color surface: "#13151d"
    readonly property color surfaceHigh: "#1a1d29"
    readonly property color border: Qt.alpha("#ffffff", 0.06)

    readonly property color accent: "#3b5bfe"
    readonly property color accentContainer: "#1c2450"
    readonly property color accentContainerText: "#c7d0ff"

    readonly property color text: "#e8eaf2"
    readonly property color textMuted: "#8b90a8"
}
