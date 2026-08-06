pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Everything the greeter needs to know that it cannot read out of the user's
// home directory, because it does not run as that user.
//
// The greeter runs as `greetd`, so ~/.face, the wallpaper and the colour
// scheme are all unreadable at their original paths. Deployment copies them
// somewhere world-readable and points these at the copies. Each is overridable
// by environment variable so /etc/greetd/config.toml can retarget them without
// the QML being rebuilt or edited.
Singleton {
    id: root

    // Demo mode exists so the greeter can be run inside a live session for
    // visual work without greetd. It also deliberately weakens two things that
    // would otherwise make a test unkillable from the keyboard: focus is taken
    // on demand rather than exclusively, and Escape quits.
    readonly property bool demo: (Quickshell.env("GREETER_DEMO") ?? "") !== ""

    // Who we log in. Not a picker: this machine has one human on it, and a
    // username field is one more thing to fumble in the dark.
    readonly property string username: Quickshell.env("GREETER_USER") || "nodevortex"

    // What greetd execs once authentication succeeds.
    readonly property string session: Quickshell.env("GREETER_SESSION") || "Hyprland"
    readonly property var sessionCmd: session.split(" ").filter(s => s.length > 0)

    readonly property string assetDir: Quickshell.env("GREETER_ASSETS") || `${Quickshell.shellDir}/assets/greeter`

    readonly property string wallpaper: Quickshell.env("GREETER_WALLPAPER") || `${assetDir}/wallpaper`
    readonly property string avatar: Quickshell.env("GREETER_AVATAR") || `${assetDir}/avatar`
}
