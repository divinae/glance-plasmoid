/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import org.kde.plasma.private.brightnesscontrolplugin as Brightness

import "../common"

// The dashboard's controls: Bluetooth, Wi-Fi, Do Not Disturb, dark mode, Night Light and
// microphone toggles, the screen's
// brightness, and what's connected with a battery (its icon in a ring of it, the name, the level).
// A click opens the Controls tab.
Tile {
    id: tile

    required property var island
    // Only those with a battery: the rest (a desk, a speaker) say nothing here (the tab has them)
    readonly property var devices: island.devices.connected.filter(d => d.percent >= 0)
    readonly property Item wifi: island.controls.wifi
    readonly property Item audio: island.controls.audio

    clickable: true

    // The quick ones, as the Controls tab has them: Bluetooth, dark mode, Night Light, and the
    // first screen's brightness
    Brightness.ScreenBrightnessControl {
        id: screens
        isSilent: false
    }
    ColorMode {
        id: colorMode
    }
    readonly property QtObject nightLight: Brightness.NightLightInhibitor
    Instantiator {
        id: firstScreen
        model: screens.displays
        delegate: QtObject {
            required property var model
            readonly property string displayName: model.displayName ?? ""
            readonly property real brightness: model.brightness ?? 0
            readonly property real maxBrightness: model.maxBrightness ?? 100
        }
    }
    readonly property QtObject screen: screens.isBrightnessAvailable && firstScreen.count > 0 ? firstScreen.objectAt(0) : null

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing * 2

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18n("Controls")
            font.weight: Font.DemiBold
        }
        // Bluetooth · Wi-Fi · Do Not Disturb, then dark mode · Night Light · the microphone
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing
            QuickToggle {
                visible: tile.island.devices.hasAdapter
                on: tile.island.devices.bluetoothOn
                iconName: "bluetooth-active-symbolic"
                fallbackIcon: "network-bluetooth-symbolic"
                tip: on ? i18n("Turn Bluetooth off") : i18n("Turn Bluetooth on")
                onToggled: tile.island.devices.setBluetooth(!on)
            }
            QuickToggle {
                visible: !!tile.wifi && tile.wifi.available
                on: !!tile.wifi && tile.wifi.on
                iconName: "network-wireless-symbolic"
                tip: on ? i18n("Turn Wi-Fi off") : i18n("Turn Wi-Fi on")
                onToggled: tile.wifi.setOn(!on)
            }
            QuickToggle {
                visible: tile.island.cfg.showNotifications
                on: tile.island.doNotDisturb
                iconName: "notifications-disabled-symbolic"
                tip: on ? i18n("Turn Do Not Disturb off") : i18n("Do Not Disturb")
                onToggled: tile.island.toggleDoNotDisturb()
            }
            QuickToggle {
                // Lit while dark; the icon says light, dark or automatic. A click goes on to the next.
                on: colorMode.dark
                iconName: colorMode.iconName
                tip: i18n("Appearance: %1 (click for %2)", colorMode.label(colorMode.mode),
                          colorMode.label(colorMode.next))
                onToggled: colorMode.cycle()
            }
            QuickToggle {
                // On while Night Light works, off while it's held off
                on: !tile.nightLight.inhibited
                iconName: "night-light-symbolic"
                fallbackIcon: "redshift-status-on-symbolic"
                tip: on ? i18n("Suspend Night Light") : i18n("Resume Night Light")
                onToggled: tile.nightLight.toggleInhibition()
            }
            QuickToggle {
                visible: !!tile.audio && tile.audio.hasMic
                on: !!tile.audio && tile.audio.micMuted
                alert: true
                iconName: "audio-input-microphone-symbolic"
                tip: on ? i18n("Unmute the microphone") : i18n("Mute the microphone")
                onToggled: tile.audio.toggleMic()
            }
        }
        // The screen's brightness
        RowLayout {
            Layout.fillWidth: true
            visible: tile.screen !== null
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "brightness-high-symbolic"
                fallback: "video-display-brightness-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }
            ThinSlider {
                Layout.fillWidth: true
                from: 0
                to: tile.screen ? Math.max(1, tile.screen.maxBrightness) : 1
                value: tile.screen ? tile.screen.brightness : 0
                wheelStep: tile.screen ? Math.max(1, tile.screen.maxBrightness / 20) : 1
                onMoved: value => screens.setBrightness(tile.screen.displayName, Math.round(value))
            }
            PlasmaComponents.Label {
                Layout.minimumWidth: pctMetrics.advanceWidth
                horizontalAlignment: Text.AlignRight
                text: tile.screen ? i18nc("a level, in percent", "%1%", Math.round(tile.screen.brightness / Math.max(1, tile.screen.maxBrightness) * 100)) : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.7
                TextMetrics {
                    id: pctMetrics
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: "100%"
                }
            }
        }
        PlasmaComponents.Label {
            visible: tile.devices.length === 0
            text: i18n("No batteries to show")
            opacity: 0.6
            font: Kirigami.Theme.smallFont
        }
        // The batteries: each device's icon in a ring of its level, the level under it, the
        // name on hover (a narrow card has no room for names)
        // A Flow, not a GridLayout: its column count from its own width looped to one column
        Flow {
            id: rings
            readonly property real ringSize: Kirigami.Units.iconSizes.medium + 4
            // As many as fit across, spread evenly
            readonly property int perRow: Math.max(1, Math.floor(width / (ringSize + Kirigami.Units.smallSpacing)))
            readonly property real cellWidth: Math.floor(width / perRow)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            clip: true
            Repeater {
                model: tile.devices
                delegate: ColumnLayout {
                    id: device
                    required property var modelData
                    readonly property bool low: modelData.percent <= tile.island.peripherals.lowAt && !modelData.charging
                    width: rings.cellWidth
                    spacing: 2
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: rings.ringSize
                        Layout.preferredHeight: rings.ringSize
                        ProgressCircle {
                            anchors.centerIn: parent
                            size: parent.width
                            lineWidth: 3
                            arcBegin: 0
                            arcEnd: Math.round(Math.max(0, device.modelData.percent) * 3.6)
                            showBackground: true
                            colorCircle: device.low ? Kirigami.Theme.negativeTextColor
                                : device.modelData.charging ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
                            colorBackground: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: device.modelData.icon
                            isMask: true
                            color: Kirigami.Theme.textColor
                        }
                        HoverHandler {
                            id: ringHover
                        }
                        PlasmaComponents.ToolTip.text: device.modelData.name
                        PlasmaComponents.ToolTip.visible: ringHover.hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18nc("a battery's level", "%1%", device.modelData.percent)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.features: { "tnum": 1 }
                        color: device.low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: device.low ? 1 : 0.7
                    }
                }
            }
        }
    }
}
