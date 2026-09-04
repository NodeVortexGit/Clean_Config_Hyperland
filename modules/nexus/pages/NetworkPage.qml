pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    signal networkSelected(ap: Nmcli.AccessPoint)

    // Password prompt state for connecting to a secured, unsaved network.
    property var pendingNetwork: null
    property bool passwordActive: false

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        ToggleRow {
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        // --- Password prompt for a secured, unsaved network ------------------
        // Animates open (height + fade) when a tapped network needs a password.
        StyledRect {
            id: pwPanel

            property bool connecting: false
            property bool hasError: false

            function doConnect(): void {
                if (!root.pendingNetwork || connecting)
                    return;
                const pw = pwField.text;
                if (!pw || pw.length === 0)
                    return;
                hasError = false;
                connecting = true;
                NetworkConnection.connectWithPassword(root.pendingNetwork, pw, result => {
                    if (result && !result.success && !result.needsPassword)
                        pwPanel.fail();
                });
                pwTimeout.restart();
            }

            function fail(): void {
                pwTimeout.stop();
                connecting = false;
                hasError = true;
                pwField.text = "";
                pwField.forceActiveFocus();
                if (root.pendingNetwork && root.pendingNetwork.ssid)
                    Nmcli.forgetNetwork(root.pendingNetwork.ssid);
            }

            function close(): void {
                pwTimeout.stop();
                connecting = false;
                hasError = false;
                pwField.text = "";
                root.passwordActive = false;
                root.pendingNetwork = null;
                root.networkSelected(null); // clear row highlights
            }

            Layout.fillWidth: true
            clip: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            visible: implicitHeight > 0
            implicitHeight: root.passwordActive ? pwContent.implicitHeight + Tokens.padding.large * 2 : 0
            opacity: root.passwordActive ? 1 : 0

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Connections {
                function onPasswordActiveChanged(): void {
                    if (root.passwordActive)
                        pwFocus.restart();
                }

                target: root
            }

            Timer {
                id: pwFocus

                interval: 120
                onTriggered: pwField.forceActiveFocus()
            }

            Timer {
                id: pwTimeout

                interval: 15000
                onTriggered: if (pwPanel.connecting)
                    pwPanel.fail()
            }

            Connections {
                function onActiveChanged(): void {
                    if (root.passwordActive && root.pendingNetwork && Nmcli.active && Nmcli.active.ssid && Nmcli.active.ssid.toLowerCase().trim() === root.pendingNetwork.ssid.toLowerCase().trim())
                        pwPanel.close();
                }

                function onConnectionFailed(ssid: string): void {
                    if (root.passwordActive && pwPanel.connecting && root.pendingNetwork && root.pendingNetwork.ssid === ssid)
                        pwPanel.fail();
                }

                target: Nmcli
            }

            ColumnLayout {
                id: pwContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large
                anchors.rightMargin: Tokens.padding.large
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "lock"
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Enter password")
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.pendingNetwork ? root.pendingNetwork.ssid : ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: pwField.implicitHeight + Tokens.padding.medium
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3surfaceContainerHigh
                    border.width: pwPanel.hasError || pwField.activeFocus ? 2 : 1
                    border.color: pwPanel.hasError ? Colours.palette.m3error : pwField.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outline

                    Behavior on border.color {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on border.width {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    StyledTextField {
                        id: pwField

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        placeholderText: qsTr("Password")
                        onTextChanged: pwPanel.hasError = false
                        onAccepted: pwPanel.doConnect()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: pwPanel.connecting || pwPanel.hasError
                    text: pwPanel.hasError ? qsTr("Couldn't connect — check the password") : qsTr("Connecting…")
                    color: pwPanel.hasError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.medium

                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        inactiveColour: Colours.palette.m3secondaryContainer
                        inactiveOnColour: Colours.palette.m3onSecondaryContainer
                        onClicked: pwPanel.close()
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: pwPanel.connecting ? qsTr("Connecting…") : qsTr("Connect")
                        enabled: pwField.text.length > 0 && !pwPanel.connecting
                        inactiveColour: Colours.palette.m3primary
                        inactiveOnColour: Colours.palette.m3onPrimary
                        onClicked: pwPanel.doConnect()
                    }
                }
            }
        }

        ItemList {
            id: networkList

            showList: Nmcli.wifiEnabled
            placeholderIcon: Nmcli.wifiEnabled ? "wifi_find" : "signal_wifi_off"
            placeholderText: Nmcli.wifiEnabled ? qsTr("No networks found") : qsTr("Wi-Fi disabled")
            extraHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0 // Inline so it isn't affected by anim
            list.anchors.top: scanningIndicator.bottom

            model: ScriptModel {
                values: {
                    const connecting = Nmcli.connectingSsid();
                    // Lower rank sorts higher in the list
                    const rank = n => n.active ? 0 : n.ssid === connecting ? 1 : Nmcli.hasSavedProfile(n.ssid) ? 2 : 3;
                    return [...Nmcli.networks].sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
                }
            }

            delegate: StateLayer {
                id: network

                required property Nmcli.AccessPoint modelData
                property bool currentSelected
                property real textOpacity: disabled ? 0.5 : 1

                disabled: currentSelected || Nmcli.connectingSsid() === modelData.ssid

                anchors.left: networkList.list.contentItem.left
                anchors.right: networkList.list.contentItem.right
                implicitHeight: networkLayout.implicitHeight + networkLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                anchors.fill: undefined

                onClicked: {
                    if (!modelData.active) {
                        // handleConnect tries saved secrets first; the callback only
                        // fires when a password is actually required.
                        NetworkConnection.handleConnect(modelData, null, net => {
                            root.pendingNetwork = net;
                            root.passwordActive = true;
                        });
                        currentSelected = true;
                        root.networkSelected(modelData);
                    }
                }

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Connections {
                    function onActiveChanged(): void {
                        if (network.modelData.active)
                            network.currentSelected = false;
                    }

                    target: network.modelData
                }

                Connections {
                    function onNetworkSelected(ap: Nmcli.AccessPoint): void {
                        if (ap !== network.modelData)
                            network.currentSelected = false;
                    }

                    target: root
                }

                RowLayout {
                    id: networkLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: Icons.getNetworkIcon(network.modelData.strength)
                        color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        opacity: network.textOpacity
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: network.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: network.modelData.ssid
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Security: %1%2").arg(network.modelData.security).arg(network.modelData.active ? qsTr(" • Connected") : Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" • Saved") : "")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    AnimLoader {
                        sourceComp: Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp

                        Component {
                            id: iconComp

                            MaterialIcon {
                                text: network.modelData.active ? "settings" : "lock"
                                color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                                opacity: network.textOpacity
                            }
                        }

                        Component {
                            id: loadingComp

                            LoadingIndicator {
                                implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                            }
                        }
                    }
                }
            }

            StyledProgressBar {
                id: scanningIndicator

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                implicitHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0
                indeterminate: true

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addNetworkLayout.implicitHeight + addNetworkLayout.anchors.margins * 2
            last: true

            StateLayer {}

            RowLayout {
                id: addNetworkLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add network")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
