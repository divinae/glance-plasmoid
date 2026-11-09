/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."
import "../common"
import "../tiles"

// The Controls tab, a card for each kind of thing:
//   Quick settings: Wi-Fi, Do Not Disturb, keep awake,  | Bluetooth: on / off, pair,
//     the mic, the power profile                        |   connected, paired
//   Display: the screens' brightness, the keyboard's    | USB receiver: batteries not over
//     light, dark mode, Night Light                     |   Bluetooth (a receiver's mouse…)
//   Sound output: where sound goes                      |
GridLayout {
    id: tab

    required property var island

    // The list itself is main.qml's (DeviceList.qml), shared with the dashboard's card
    readonly property var bluetoothConnected: island.devices.connected.filter(d => !!d.device)
    readonly property var otherDevices: island.devices.connected.filter(d => !d.device)
    readonly property var notConnected: island.devices.notConnected
    readonly property bool bluetoothOn: island.devices.bluetoothOn
    readonly property bool hasAdapter: island.devices.hasAdapter

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    // A device: its icon in a ring of its battery (on a plain disc without one), its name, the level or
    // its state; one over Bluetooth can be let go (on hover)
    component DeviceCard: Rectangle {
        id: card
        required property var modelData
        // Letting it go: the card stays until BlueZ is done, a spinner in the button's place
        property bool working: false
        function disconnect() {
            card.working = true;
            const call = card.modelData.device.disconnectFromDevice();
            if (call) {
                call.finished.connect(() => card.working = false);
            } else {
                card.working = false;
            }
        }
        readonly property bool low: modelData.percent >= 0 && modelData.percent <= tab.island.peripherals.lowAt
            && !modelData.charging
        readonly property color ringColor: low ? Kirigami.Theme.negativeTextColor
            : modelData.charging ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
        Layout.fillWidth: true
        implicitHeight: cardRow.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.alpha(Kirigami.Theme.textColor, cardHover.hovered ? 0.09 : 0.05)
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
        HoverHandler {
            id: cardHover
        }
        RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium + 8
                Layout.preferredHeight: Layout.preferredWidth
                // No battery (a desk, a speaker on mains): the icon on a plain disc, no ring
                Rectangle {
                    anchors.fill: parent
                    visible: card.modelData.percent < 0
                    radius: width / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                }
                ProgressCircle {
                    anchors.centerIn: parent
                    visible: card.modelData.percent >= 0
                    size: parent.width
                    lineWidth: 3
                    arcBegin: 0
                    arcEnd: Math.round(Math.max(0, card.modelData.percent) * 3.6)
                    showBackground: true
                    colorCircle: card.ringColor
                    colorBackground: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: card.modelData.icon
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.working ? i18n("Disconnecting…")
                        : card.modelData.percent < 0 ? i18n("Connected")
                        : card.modelData.charging ? i18nc("a battery charging, its level", "Charging · %1%", card.modelData.percent)
                        : i18nc("a battery's level", "%1%", card.modelData.percent)
                    font: Kirigami.Theme.smallFont
                    color: card.low && !card.working ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    opacity: card.low && !card.working ? 1 : 0.65
                    elide: Text.ElideRight
                }
            }
            // Disconnect (on hover), and a spinner in its place, the same size, while it works
            Item {
                visible: !!card.modelData.device
                implicitWidth: disconnectButton.implicitWidth
                implicitHeight: disconnectButton.implicitHeight
                PillButton {
                    id: disconnectButton
                    anchors.centerIn: parent
                    visible: !card.working
                    opacity: cardHover.hovered ? 1 : 0
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Disconnect")
                    icon.name: "network-disconnect-symbolic"
                    onClicked: card.disconnect()
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }
                PlasmaComponents.BusyIndicator {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    padding: 0
                    visible: card.working
                    running: card.working
                }
            }
        }
    }
    // A small heading inside a card
    component SubHeading: PlasmaComponents.Label {
        Layout.topMargin: Kirigami.Units.smallSpacing
        font: Kirigami.Theme.smallFont
        opacity: 0.6
    }

    // ---- left: quick settings, the display, the sound output (one under the other, whatever the
    // Bluetooth card's height) ---------------------------------------------------------------
    ColumnLayout {
        Layout.row: 0
        Layout.column: 0
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Kirigami.Units.largeSpacing

        QuickSettingsTile {
            Layout.fillWidth: true
            island: tab.island
        }
        DisplayTile {
            Layout.fillWidth: true
        }
        SoundOutputTile {
            Layout.fillWidth: true
            island: tab.island
        }

    }

    // ---- right: Bluetooth, then devices on a USB receiver --------------------------------
    // -----------------------------------------------------------------------------------
    ColumnLayout {
        Layout.row: 0
        Layout.column: 1
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Kirigami.Units.largeSpacing

        Tile {
            Layout.fillWidth: true
            implicitHeight: btColumn.implicitHeight + padding * 2

            ColumnLayout {
                id: btColumn
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                // Bluetooth, on or off, a new one paired, Plasma's settings
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "network-bluetooth-symbolic"
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: i18n("Bluetooth")
                        font.weight: Font.DemiBold
                    }
                    // A new one: Plasma's own pairing wizard (finding it, the PIN, the rest)
                    PillButton {
                        visible: tab.hasAdapter && tab.bluetoothOn
                        // Never squeezed by the title
                        Layout.minimumWidth: implicitWidth
                        text: i18nc("pair a new Bluetooth device", "Pair")
                        icon.name: "list-add-symbolic"
                        onClicked: {
                            pairExec.exec("bluedevil-wizard");
                            tab.island.setOpen(false);
                        }
                        ExecUtil {
                            id: pairExec
                        }
                    }
                    PlasmaComponents.Switch {
                        visible: tab.hasAdapter
                        checked: tab.bluetoothOn
                        onToggled: tab.island.devices.setBluetooth(checked)
                        PlasmaComponents.ToolTip.text: tab.bluetoothOn ? i18n("Turn Bluetooth off") : i18n("Turn Bluetooth on")
                        PlasmaComponents.ToolTip.visible: hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    PillButton {
                        bare: true
                        display: PlasmaComponents.AbstractButton.IconOnly
                        text: i18n("Bluetooth settings")
                        icon.name: "configure"
                        onClicked: {
                            Qt.openUrlExternally("systemsettings://kcm_bluetooth");
                            tab.island.setOpen(false);
                        }
                    }
                }
                PlasmaComponents.Label {
                    visible: !tab.hasAdapter || !tab.bluetoothOn
                    Layout.fillWidth: true
                    text: !tab.hasAdapter ? i18n("No Bluetooth on this computer.") : i18n("Bluetooth is off.")
                    opacity: 0.6
                }

                // Connected
                SubHeading {
                    visible: tab.bluetoothOn
                    text: i18n("Connected")
                }
                PlasmaComponents.Label {
                    visible: tab.bluetoothOn && tab.bluetoothConnected.length === 0
                    text: i18n("Nothing connected.")
                    opacity: 0.6
                }
                GridLayout {
                    Layout.fillWidth: true
                    visible: tab.bluetoothOn && tab.bluetoothConnected.length > 0
                    columns: Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 8.5)))
                    rowSpacing: Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: tab.bluetoothConnected
                        delegate: DeviceCard {}
                    }
                }

                // Paired, not connected: a click connects
                SubHeading {
                    visible: tab.bluetoothOn && tab.notConnected.length > 0
                    text: i18n("Paired")
                }
                Repeater {
                    model: tab.bluetoothOn ? tab.notConnected : []
                    delegate: Item {
                        id: other
                        required property var modelData
                        property bool working: false
                        Layout.fillWidth: true
                        implicitHeight: otherRow.implicitHeight + 4

                        function connect() {
                            other.working = true;
                            const call = other.modelData.connectToDevice();
                            if (call) {
                                call.finished.connect(() => other.working = false);
                            } else {
                                other.working = false;
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: Qt.alpha(Kirigami.Theme.textColor, otherHover.hovered ? 0.08 : 0)
                        }
                        RowLayout {
                            id: otherRow
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: Kirigami.Units.largeSpacing
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: tab.island.devices.iconOf(other.modelData)
                                isMask: true
                                color: Kirigami.Theme.textColor
                                opacity: 0.6
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: other.modelData.name || other.modelData.address
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                opacity: 0.8
                            }
                            // Connect, a button proper on the row under the pointer (the row's click
                            // does the same), and "Connecting…" in its place while it works. One
                            // slot the button's size either way: the label alone is shorter, and
                            // swapping them made the row, and the whole card, jump.
                            Item {
                                implicitWidth: Math.max(connectButton.implicitWidth, connectingLabel.implicitWidth)
                                implicitHeight: Math.max(connectButton.implicitHeight, connectingLabel.implicitHeight)
                                PillButton {
                                    id: connectButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !other.working
                                    opacity: otherHover.hovered ? 1 : 0
                                    highlighted: true
                                    text: i18n("Connect")
                                    icon.name: "network-connect-symbolic"
                                    onClicked: other.connect()
                                    Behavior on opacity {
                                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                                    }
                                }
                                // A spinner beside the words, the text's own height so the row
                                // keeps its size; running only while shown
                                RowLayout {
                                    id: connectingLabel
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: other.working
                                    spacing: Kirigami.Units.smallSpacing
                                    PlasmaComponents.BusyIndicator {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        padding: 0
                                        running: other.working
                                    }
                                    PlasmaComponents.Label {
                                        text: i18n("Connecting…")
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.6
                                    }
                                }
                            }
                        }
                        HoverHandler {
                            id: otherHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            enabled: !other.working
                            onTapped: other.connect()
                        }
                    }
                }
            }
        }

        // Batteries not over Bluetooth: a mouse or keyboard on its USB receiver (Logitech's…)
        Tile {
            Layout.fillWidth: true
            visible: tab.otherDevices.length > 0
            implicitHeight: otherColumn.implicitHeight + padding * 2

            ColumnLayout {
                id: otherColumn
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    text: i18n("USB receiver")
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: tab.otherDevices
                    delegate: DeviceCard {}
                }
            }
        }
    }

    Item {
        Layout.row: 1
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.fillHeight: true
    }
}
