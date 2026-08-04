pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    spacing: Tokens.spacing.small

    function fmtMmSs(secs: int): string {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    Loader {
        active: Timers.active !== null
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: "timer"
            }

            StyledText {
                text: root.fmtMmSs(Timers.active?.remaining ?? 0)
                font: Tokens.font.mono.small
            }

            Item {
                id: cancelBtn

                implicitWidth: closeIcon.implicitHeight + Tokens.padding.small
                implicitHeight: closeIcon.implicitHeight + Tokens.padding.small

                StateLayer {
                    anchors.fill: undefined
                    anchors.centerIn: parent
                    implicitWidth: parent.implicitWidth
                    implicitHeight: parent.implicitHeight
                    radius: Tokens.rounding.full
                    onClicked: Timers.active && Timers.cancel(Timers.active.id)
                }

                MaterialIcon {
                    id: closeIcon
                    anchors.centerIn: parent
                    text: "close"
                }
            }
        }
    }

    Loader {
        active: Timers.active === null
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: [{
                        label: "1m",
                        secs: 60
                    }, {
                        label: "5m",
                        secs: 300
                    }, {
                        label: "10m",
                        secs: 600
                    }]

                Item {
                    id: presetBtn

                    required property var modelData

                    implicitWidth: label.implicitWidth + Tokens.padding.medium
                    implicitHeight: label.implicitHeight + Tokens.padding.small

                    StateLayer {
                        anchors.fill: undefined
                        anchors.centerIn: parent
                        implicitWidth: parent.implicitWidth
                        implicitHeight: parent.implicitHeight
                        radius: Tokens.rounding.full
                        onClicked: Timers.start(presetBtn.modelData.secs, qsTr("Timer"))
                    }

                    StyledText {
                        id: label
                        anchors.centerIn: parent
                        text: presetBtn.modelData.label
                        font: Tokens.font.body.small
                    }
                }
            }
        }
    }
}
