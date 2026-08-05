pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

// Literal battery shape whose inner fill grows/shrinks with the real charge
// level, instead of relying on discrete Material battery glyphs. Colours are
// all overridable so callers can go colourful (the pill) or stay muted to
// match a surrounding dark card (the quick-settings widget). All internal
// metrics scale off the item's own size so it stays proportional whether
// it's drawn tiny (the pill) or larger (the grid widget).
Item {
    id: root

    readonly property real pct: UPower.displayDevice.percentage
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)

    property color bodyColour: DarkAccent.text
    property color normalFillColour: DarkAccent.accent
    property color chargingFillColour: DarkAccent.accent
    property color lowFillColour: Colours.palette.m3error
    property color boltColour: DarkAccent.bg

    readonly property color fillColour: charging ? chargingFillColour : (pct <= 0.2 ? lowFillColour : normalFillColour)
    readonly property real nubWidth: Math.max(2, height * 0.18)

    implicitWidth: 46
    implicitHeight: 22

    Rectangle {
        id: body

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - root.nubWidth - 2
        radius: Math.max(1, height * 0.18)
        color: "transparent"
        border.width: Math.max(1, height * 0.09)
        border.color: root.bodyColour

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Math.max(1, parent.height * 0.14)
            width: Math.max(0, (body.width - anchors.margins * 2) * Math.max(0, Math.min(1, root.pct)))
            radius: Math.max(1, height * 0.1)
            color: root.fillColour

            Behavior on width {
                Anim {}
            }
        }

        MaterialIcon {
            visible: root.charging
            anchors.centerIn: parent
            text: "bolt"
            color: root.boltColour
            fontStyle: Tokens.font.icon.builders.small.build()
        }
    }

    Rectangle {
        id: nub

        anchors.left: body.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.nubWidth
        height: parent.height * 0.4
        radius: width / 2
        color: root.bodyColour
    }
}
