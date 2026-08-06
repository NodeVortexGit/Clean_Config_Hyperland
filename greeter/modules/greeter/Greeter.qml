pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Stands in for Lock.qml.
//
// The lock screen's root was a WlSessionLock, which is a compositor protocol
// for locking a session that already exists. Before login there is no session,
// so instead we present an object with the same shape - `locked` and an
// `unlock()` signal - and hang layershell surfaces off it ourselves.
//
// Content.qml and everything under center/ reach through `lock.lock` and
// `lock.pam`, so keeping those two names pointing at compatible objects is the
// whole of the compatibility layer.
Scope {
    id: root

    readonly property alias lock: sessionLock
    readonly property alias pam: pam

    QtObject {
        id: sessionLock

        // Always true here: the greeter has nothing to unlock *to* until
        // greetd starts the session, at which point this process is replaced.
        property bool locked: true
        // Pam.qml's original watched this to arm fingerprint; kept so the
        // shape matches, permanently true because a greeter is only ever shown
        // when credentials are actually required.
        property bool secure: true

        signal unlock
    }

    Variants {
        model: Quickshell.screens

        LockSurface {
            required property var modelData

            screen: modelData
            lock: sessionLock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: sessionLock
    }
}
