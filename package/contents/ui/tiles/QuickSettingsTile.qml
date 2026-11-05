/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"

// The Controls tab's quick settings: Wi-Fi, Do Not Disturb, keep awake, the microphone's mute,
// and the power profile. Each only where the system has it.
Tile {
    id: tile

    required property var island
    readonly property Item wifi: island.controls.wifi
    readonly property Item audio: island.controls.audio
    readonly property Item power: island.controls.power

    implicitHeight: column.implicitHeight + padding * 2

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing * 2

        // The title, and the power profile at its end: three icons, as the battery widget's
        // three choices (the name as a tooltip)
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Quick settings")
                font.weight: Font.DemiBold
            }
            SegmentedControl {
                visible: !!tile.power && tile.power.available
                Repeater {
                    // Plasma's order, whatever the daemon's
                    model: ["power-saver", "balanced", "performance"].filter(p => !!tile.power && tile.power.profiles.indexOf(p) >= 0)
                    delegate: PillButton {
                        required property string modelData
                        bare: true
                        display: PlasmaComponents.AbstractButton.IconOnly
                        checked: !!tile.power && tile.power.active === modelData
                        text: modelData === "power-saver" ? i18n("Power saver")
                            : modelData === "performance" ? i18n("Performance") : i18n("Balanced")
                        icon.name: modelData === "power-saver" ? "battery-profile-powersave-symbolic"
                            : modelData === "performance" ? "battery-profile-performance-symbolic" : "battery-profile-balanced-symbolic"
                        onClicked: tile.power.set(modelData)
                    }
                }
            }
        }
        // Two by two
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing
            QuickToggle {
                visible: !!tile.wifi && tile.wifi.available
                on: !!tile.wifi && tile.wifi.on
                iconName: "network-wireless-symbolic"
                label: i18n("Wi-Fi")
                tip: on ? i18n("Turn Wi-Fi off") : i18n("Turn Wi-Fi on")
                onToggled: tile.wifi.setOn(!on)
            }
            QuickToggle {
                visible: tile.island.cfg.showNotifications
                on: tile.island.doNotDisturb
                iconName: "notifications-disabled-symbolic"
                label: i18n("Do Not Disturb")
                onToggled: tile.island.toggleDoNotDisturb()
            }
            QuickToggle {
                on: tile.island.keepAwake
                iconName: "visibility-symbolic"
                label: i18n("Keep awake")
                // On for Focus or a meeting too; the toggle only holds it on by hand
                tip: tile.island.keepAwake && !tile.island.keepAwakeManual
                    ? i18n("Kept awake for Focus or a meeting; click to hold it on after them")
                    : tile.island.keepAwakeManual ? i18n("Let the screen sleep again")
                    : i18n("Don't let the screen sleep or lock")
                onToggled: tile.island.keepAwakeManual = !tile.island.keepAwakeManual
            }
            QuickToggle {
                visible: !!tile.audio && tile.audio.hasMic
                on: !!tile.audio && tile.audio.micMuted
                alert: true
                iconName: "audio-input-microphone-symbolic"
                label: on ? i18n("Mic muted") : i18n("Microphone")
                tip: on ? i18n("Unmute the microphone") : i18n("Mute the microphone")
                onToggled: tile.audio.toggleMic()
            }
        }
    }
}
