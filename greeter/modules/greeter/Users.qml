pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The accounts the greeter will offer to log in.
//
// Read from passwd rather than a hardcoded list, so adding a second account to
// the machine makes it appear here with no change to the greeter. Filtered to
// real humans: uid >= 1000, below the nobody sentinel, and with a shell you can
// actually log in to.
Singleton {
    id: root

    // [{ name, realName, avatar }]
    property var users: []
    property int index: 0

    readonly property var current: users.length > 0 ? users[Math.min(index, users.length - 1)] : null
    readonly property string currentName: current?.name ?? GreeterInfo.username
    // The login name, which is what the lock screen has always shown. Using
    // the GECOS full name here silently changed "nodevortex" to "Ivelin".
    readonly property string currentLabel: current?.name ?? GreeterInfo.username
    // The primary account's real photo is deployed from its ~/.face, which the
    // greeter cannot read directly. Prefer that over the AccountsService icon,
    // which for this user is GNOME's generated initial-on-a-colour tile and
    // would otherwise replace the actual picture. Other accounts fall back to
    // their AccountsService icon, then to the person glyph.
    readonly property string currentAvatar: current?.name === GreeterInfo.username ? GreeterInfo.avatar : (current?.avatar || "")

    function selectByName(name: string): void {
        const i = users.findIndex(u => u.name === name);
        if (i >= 0)
            index = i;
    }

    onIndexChanged: {
        // Same trap as Sessions.qml: `current` is a binding and may still be
        // stale inside this handler, which would persist the previously
        // selected account. Read the array directly.
        const u = users[index];
        if (u)
            lastUser.setText(u.name);
    }

    // Remembers who logged in last, same as the session picker.
    FileView {
        id: lastUser

        printErrors: false
        blockLoading: true
        path: `${Quickshell.env("XDG_STATE_HOME") || "/var/lib/greetd/.local/state"}/greeter-user`
        onLoaded: root.selectByName(text().trim())
    }

    Process {
        running: true
        command: ["sh", "-c", `
            getent passwd | awk -F: '$3>=1000 && $3<65534 && $7 !~ /(nologin|false|sync)$/ {
                split($5, gecos, ",")
                icon = "/var/lib/AccountsService/icons/" $1
                if ((getline line < icon) < 0) icon = ""
                close(icon)
                printf "%s\\t%s\\t%s\\n", $1, gecos[1], icon
            }'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n").filter(l => l.length > 0).map(line => {
                    const [name, realName, avatar] = line.split("\t");
                    return {
                        name,
                        realName: realName ?? "",
                        avatar: avatar ?? ""
                    };
                });

                if (found.length === 0)
                    return;

                root.users = found;

                const remembered = lastUser.text()?.trim();
                if (remembered && found.some(u => u.name === remembered)) {
                    root.selectByName(remembered);
                    return;
                }

                // Otherwise start on the configured account rather than
                // whichever one passwd happened to list first.
                const i = found.findIndex(u => u.name === GreeterInfo.username);
                root.index = i >= 0 ? i : 0;
            }
        }
    }
}
