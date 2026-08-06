pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The sessions the greeter can launch, read from the same .desktop files a
// conventional display manager uses, so anything installed shows up without
// this being edited.
//
// The selection is what ends up in greetd's start_session cmd, which is why
// GreeterInfo.session is now only a fallback for the very first boot.
Singleton {
    id: root

    // [{ name, exec, type }]
    property var sessions: []
    property int index: 0

    readonly property var current: sessions.length > 0 ? sessions[Math.min(index, sessions.length - 1)] : null
    readonly property string currentName: current?.name ?? "Default"
    // greetd wants argv, not a shell string.
    readonly property var currentCmd: current ? current.exec.split(" ").filter(s => s.length > 0) : []

    function cycle(): void {
        if (sessions.length > 1)
            index = (index + 1) % sessions.length;
    }

    onIndexChanged: {
        // Deliberately NOT `current`: that is a binding, and inside this
        // handler it can still hold the value from before index changed. Doing
        // so persisted the previously selected session on every switch, which
        // is why this kept coming back as GNOME Classic after being set to
        // Hyprland. Index into the array directly instead.
        const s = sessions[index];
        if (s)
            lastSession.setText(s.name);
    }

    function selectByName(name: string): void {
        const i = sessions.findIndex(s => s.name === name);
        if (i >= 0)
            index = i;
    }

    // Remembers what you logged into last time, the way every other greeter
    // does - picking your WM again on every boot would be worse than not
    // offering the choice.
    FileView {
        id: lastSession

        printErrors: false
        // Synchronous, so text() is reliable by the time the session scan
        // finishes. Loading lazily meant the scan could read an empty string,
        // fall through to the default branch, and persist the wrong session -
        // which is how this ended up remembering GNOME Classic.
        blockLoading: true
        path: `${Quickshell.env("XDG_STATE_HOME") || "/var/lib/greetd/.local/state"}/greeter-session`
        onLoaded: root.selectByName(text().trim())
    }

    Process {
        running: true
        command: ["sh", "-c", `
            for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
                [ -e "$f" ] || continue
                grep -q '^Hidden=true' "$f" && continue
                name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
                cmd=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
                case "$f" in */wayland-sessions/*) t=wayland ;; *) t=x11 ;; esac
                [ -n "$name" ] && [ -n "$cmd" ] && printf '%s\\t%s\\t%s\\n' "$name" "$cmd" "$t"
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n").filter(l => l.length > 0).map(line => {
                    const [name, exec, type] = line.split("\t");
                    return {
                        name,
                        // Strip .desktop field codes (%U, %f, ...) - they mean
                        // nothing here and greetd would pass them through as
                        // literal arguments.
                        exec: exec.replace(/%[a-zA-Z]/g, "").trim(),
                        type
                    };
                });

                if (found.length === 0)
                    return;

                root.sessions = found;

                // Re-apply the remembered choice: the file may well have loaded
                // before the scan finished, when there was nothing to match.
                const remembered = lastSession.text()?.trim();
                if (remembered) {
                    root.selectByName(remembered);
                    return;
                }

                // No history yet, so fall back to the configured session rather
                // than to found[0] - that is whatever sorts first in the glob
                // (GNOME Classic here), which is nobody's intended default.
                const want = GreeterInfo.session.split(" ")[0];
                const i = found.findIndex(s => s.exec.split(" ")[0] === want);
                root.index = i >= 0 ? i : 0;
            }
        }
    }
}
