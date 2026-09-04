pragma Singleton

import Quickshell
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    // Panels (launcher / dashboard / session / sidebar / utilities) open on the
    // MAIN screen -- where the island/bar actually lives (see BarWrapper.qml) --
    // so the panel animates out of the pill and never opens on a screen with no
    // island. Falls back to the focused monitor if main is somehow unset.
    function getForActive(): DrawerVisibilities {
        const main = Screens.mainScreen;
        const mon = main ? Hypr.monitorFor(main) : null;
        return screens.get(mon ?? Hypr.focusedMonitor);
    }
}
