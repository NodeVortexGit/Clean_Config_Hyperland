pragma Singleton

import Quickshell
import Caelestia.Config

Singleton {
    id: root

    readonly property list<ShellScreen> screens: Quickshell.screens.filter(s => GlobalConfig.forScreen(s.name).enabled)

    // The single "main" screen the island/bar lives on: the built-in laptop panel
    // (eDP/LVDS/DSI) whenever present, else the first enabled screen. Single
    // source of truth shared by the bar (which renders ONLY here -- see
    // modules/bar/BarWrapper.qml) and by keybind/IPC panel toggles (Visibilities
    // .getForActive), so panels always open where the island is and the
    // pill->panel animation stays intact.
    readonly property ShellScreen mainScreen: {
        const list = screens;
        return list.find(s => /^(eDP|LVDS|DSI)/i.test(s.name)) ?? list[0] ?? null;
    }

    function isExcluded(screen: ShellScreen): bool {
        return !GlobalConfig.forScreen(screen.name).enabled;
    }
}
