pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.images
import qs.modules.greeter
import qs.services
import qs.utils

Item {
    id: root

    required property int centerWidth
    // Per-account picture. Falls back to the deployed copy when the selected
    // user has no AccountsService icon.
    property string avatar: GreeterInfo.avatar
    readonly property color bgColour: DarkAccent.surfaceHigh

    implicitWidth: Math.round(centerWidth * 0.7)
    implicitHeight: {
        shape.height; // Force update when shape height changes
        return shape.pathBounds().height;
    }

    MaterialShape {
        id: shape

        anchors.centerIn: parent
        implicitSize: root.implicitWidth

        shape: MaterialShape.ClamShell
        color: Qt.alpha(root.bgColour, 1)
        opacity: root.bgColour.a
        layer.enabled: true
    }

    MaterialIcon {
        anchors.centerIn: parent

        text: "person"
        color: DarkAccent.textMuted
        fontStyle: Tokens.font.icon.size(root.centerWidth / 4).build()
        visible: pfp.status !== Image.Ready
    }

    CachingImage {
        id: pfp

        anchors.fill: shape
        // Paths.home is /var/lib/greetd here, not the user's home, so the
        // avatar comes from the deployed copy instead. Falls back to the
        // "person" glyph above whenever the image isn't Ready.
        path: root.avatar

        layer.enabled: true
        layer.effect: Mask {
            maskSource: shape
        }
    }
}
