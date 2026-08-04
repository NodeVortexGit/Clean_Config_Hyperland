import QtQuick
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    // Toast popups are disabled: the island (services/Island.qml "notification"
    // transient) is now the only surface for incoming notifications, to avoid
    // showing the same notification twice. Notifs.list/popups data is untouched
    // so the island and the sidebar's notification history still work.
    visible: false
    anchors.topMargin: -5
    implicitWidth: 0
    implicitHeight: 0

    Content {
        id: content

        visible: false
        anchors.topMargin: -root.anchors.topMargin
        visibilities: root.visibilities
    }
}
