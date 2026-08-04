pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    spacing: Tokens.spacing.small

    Repeater {
        model: Config.bar.workspaces.shown

        Rectangle {
            id: dot

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === Hypr.activeWsId
            readonly property bool occupied: Hypr.workspaces.values.some(w => w.id === wsId && w.lastIpcObject.windows > 0)

            Layout.alignment: Qt.AlignVCenter

            implicitWidth: active ? 18 : 8
            implicitHeight: 8
            radius: 4
            color: active ? Colours.palette.m3primary : (occupied ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outlineVariant)

            Behavior on implicitWidth {
                Anim {}
            }

            Behavior on color {
                CAnim {}
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: Hypr.dispatch(`workspace ${dot.wsId}`)
            }
        }
    }
}
