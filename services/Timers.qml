pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property var list: []
    readonly property var active: list.length > 0 ? list.reduce((a, b) => a.remaining <= b.remaining ? a : b) : null

    function start(durationSecs: int, label: string): void {
        list = [...list, {
            id: Date.now(),
            label: label || qsTr("Timer"),
            duration: durationSecs,
            remaining: durationSecs,
            paused: false
        }];
    }

    function pause(id: real): void {
        list = list.map(t => t.id === id ? Object.assign({}, t, { paused: true }) : t);
    }

    function resume(id: real): void {
        list = list.map(t => t.id === id ? Object.assign({}, t, { paused: false }) : t);
    }

    function cancel(id: real): void {
        list = list.filter(t => t.id !== id);
    }

    function addTime(id: real, secs: int): void {
        list = list.map(t => t.id === id ? Object.assign({}, t, { duration: t.duration + secs, remaining: t.remaining + secs }) : t);
    }

    Timer {
        interval: 1000
        running: root.list.length > 0
        repeat: true
        onTriggered: {
            const finished = [];
            root.list = root.list.map(t => {
                if (t.paused)
                    return t;
                const remaining = t.remaining - 1;
                if (remaining <= 0) {
                    finished.push(t);
                    return null;
                }
                return Object.assign({}, t, { remaining });
            }).filter(t => t !== null);

            for (const t of finished)
                Quickshell.execDetached(["notify-send", "-a", "caelestia", t.label, qsTr("Timer finished")]);
        }
    }
}
