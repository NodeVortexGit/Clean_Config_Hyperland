// pragma-env QS_NO_RELOAD_POPUP=1
// pragma-env QS_DROP_EXPENSIVE_FONTS=1
// pragma-env QSG_RENDER_LOOP=threaded

// Greeter root.
//
// Deliberately minimal next to the session shell.qml: no bar, no island, no
// background daemon, no notification handling. The greeter's entire job is to
// take a password and hand it to greetd, and every extra service is one more
// thing that can fail as the `greetd` user - which has no session bus, no
// pipewire, and no access to the user's home.
import "modules/greeter"
import Quickshell

ShellRoot {
    // Nothing to hot-reload against pre-login, and a reload popup on a login
    // screen would be both useless and un-dismissable.
    settings.watchFiles: false

    Greeter {}
}
