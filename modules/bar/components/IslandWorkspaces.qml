pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

RowLayout {
    id: root

    spacing: Tokens.spacing.small

    // Scoped to this widget - scrolling elsewhere on the expanded panel no
    // longer switches workspaces (see Bar.qml's handleWheel guard).
    WheelHandler {
        onWheel: event => {
            if (!Config.bar.scrollActions.workspaces)
                return;
            const specialWs = Hypr.focusedMonitor?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (event.angleDelta.y < 0 || Hypr.activeWsId > 1)
                Hypr.dispatch(`workspace r${event.angleDelta.y > 0 ? "-" : "+"}1`);
        }
    }

    Repeater {
        model: Config.bar.workspaces.shown

        Item {
            id: dot

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === Hypr.activeWsId
            readonly property var toplevel: Hypr.toplevels.values.find(t => t.workspace?.id === wsId) ?? null
            readonly property bool occupied: toplevel !== null

            Layout.alignment: Qt.AlignVCenter

            implicitWidth: active ? 22 : (occupied ? 18 : 8)
            implicitHeight: 18

            Behavior on implicitWidth {
                Anim {}
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: dot.active ? DarkAccent.accent : (dot.occupied ? DarkAccent.surfaceHigh : "transparent")
                border.width: dot.occupied && !dot.active ? 1 : 0
                border.color: DarkAccent.border

                Behavior on color {
                    CAnim {}
                }
            }

            // Empty workspace: plain dot. Occupied: a small category icon for
            // whatever's open instead of a bare dot.
            Rectangle {
                visible: !dot.occupied
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: dot.active ? DarkAccent.bg : DarkAccent.textMuted
            }

            MaterialIcon {
                visible: dot.occupied
                anchors.centerIn: parent
                text: Icons.getAppCategoryIcon(dot.toplevel?.lastIpcObject.class, "desktop_windows")
                color: dot.active ? DarkAccent.bg : DarkAccent.text
                fontStyle: Tokens.font.icon.builders.small.build()
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: Hypr.dispatch(`workspace ${dot.wsId}`)
            }
        }
    }
}
