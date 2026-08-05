pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Picture picker for the quick-panel frame: lists the images it can find on
// the system with a checkbox each. Ticked ones make up the slideshow.
// Selection is persisted as a newline-separated file so it survives restarts.
Item {
    id: root

    readonly property string stateFile: `${Quickshell.env("HOME")}/.local/state/caelestia/island-pictures.txt`

    // Everything found on disk.
    property var available: []
    // Paths the user has ticked.
    property var selected: []

    signal selectionChanged

    function isSelected(path: string): bool {
        return selected.includes(path);
    }

    function toggle(path: string): void {
        const next = selected.slice();
        const i = next.indexOf(path);
        if (i >= 0)
            next.splice(i, 1);
        else
            next.push(path);
        selected = next;
        saveProc.payload = next.join("\n") + "\n";
        saveProc.running = true;
        root.selectionChanged();
    }

    function rescan(): void {
        scanProc.running = true;
    }

    // Declarative rather than kicked off in Component.onCompleted - the panel
    // rebuilds this whole component every time it opens, and setting running
    // imperatively there meant the saved selection wasn't reliably read back,
    // so every reopen looked like nothing had been picked.
    Component.onCompleted: reload()

    function reload(): void {
        loadProc.running = true;
        scanProc.running = true;
    }

    // Searches the usual places, skipping the tiny icon/cache junk that would
    // otherwise swamp the list.
    Process {
        id: scanProc

        running: true
        command: ["sh", "-c", `find "$HOME/Pictures" "$HOME/Documents" "$HOME/Downloads" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) -size +20k 2>/dev/null | sort`]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.split("\n").map(l => l.trim()).filter(l => l.length > 0)
        }
    }

    Process {
        id: loadProc

        running: true
        command: ["sh", "-c", `cat "${root.stateFile}" 2>/dev/null || true`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selected = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                root.selectionChanged();
            }
        }
    }

    // Process has no stdin here, so the list is handed over as an argv entry
    // rather than piped in.
    Process {
        id: saveProc

        property string payload: ""

        command: ["sh", "-c", `mkdir -p "$(dirname "${root.stateFile}")" && printf '%s' "$1" > "${root.stateFile}"`, "sh", payload]
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: DarkAccent.surface
        border.width: 1
        border.color: DarkAccent.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Frame pictures — %1 selected").arg(root.selected.length)
                    color: DarkAccent.text
                    font: Tokens.font.body.medium
                }

                StyledText {
                    text: qsTr("%1 found").arg(root.available.length)
                    color: DarkAccent.textMuted
                    font: Tokens.font.body.small
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.available

                        Item {
                            id: row

                            required property string modelData
                            readonly property bool ticked: root.selected.includes(modelData)

                            Layout.fillWidth: true
                            implicitHeight: 46

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: row.ticked ? DarkAccent.accentContainer : "transparent"

                                Behavior on color {
                                    CAnim {}
                                }

                                StateLayer {
                                    radius: Tokens.rounding.medium
                                    onClicked: root.toggle(row.modelData)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.medium

                                MaterialIcon {
                                    text: row.ticked ? "check_box" : "check_box_outline_blank"
                                    color: row.ticked ? DarkAccent.accentContainerText : DarkAccent.textMuted
                                }

                                ClippingRectangle {
                                    Layout.preferredWidth: 52
                                    Layout.preferredHeight: 30
                                    radius: Tokens.rounding.small
                                    color: DarkAccent.surfaceHigh

                                    Image {
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl(row.modelData)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 110
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.split("/").pop()
                                    elide: Text.ElideMiddle
                                    color: row.ticked ? DarkAccent.accentContainerText : DarkAccent.text
                                    font: Tokens.font.body.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
