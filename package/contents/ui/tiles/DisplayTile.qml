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

// What Plasma's Brightness and Color widget offers, as a card: each screen's brightness (where it
// can be set: a laptop's panel, a monitor over DDC), the keyboard's backlight, dark mode, and
// Night Light suspended for a while. Through Plasma's own brightness module.
Tile {
    id: tile

    readonly property bool hasScreens: screens.isBrightnessAvailable && displayRows.count > 0
    readonly property bool hasKeyboard: keyboard.isBrightnessAvailable && keyboard.brightnessMax > 0

    implicitHeight: column.implicitHeight + padding * 2

    Brightness.ScreenBrightnessControl {
        id: screens
        isSilent: false
    }
    Brightness.KeyboardBrightnessControl {
        id: keyboard
        isSilent: false
    }
    // Plasma's own, one each (singletons)
    ColorMode {
        id: colorMode
    }
    readonly property QtObject nightLight: Brightness.NightLightInhibitor

    // A slider row: an icon, a name, the slider, the percent
    component LevelRow: RowLayout {
        id: levelRow
        property string icon
        property string label
        property real value: 0
        property real maximum: 100
        signal moved(real value)
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: levelRow.icon
            isMask: true
            color: Kirigami.Theme.textColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: levelRow.label
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    text: i18nc("a level, in percent", "%1%", levelRow.maximum > 0 ? Math.round(levelRow.value / levelRow.maximum * 100) : 0)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                }
            }
            ThinSlider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, levelRow.maximum)
                value: levelRow.value
                wheelStep: Math.max(1, levelRow.maximum / 20)
                onMoved: value => levelRow.moved(value)
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Display")
                font.weight: Font.DemiBold
            }
        }
        PlasmaComponents.Label {
            visible: !tile.hasScreens && !tile.hasKeyboard
            Layout.fillWidth: true
            text: i18n("These screens don't let their brightness be set from here.")
            wrapMode: Text.Wrap
            opacity: 0.6
        }
        // Each screen whose brightness can be set
        Repeater {
            id: displayRows
            model: screens.displays
            delegate: LevelRow {
                required property var model
                icon: model.isInternal ? "computer-laptop-symbolic" : "video-display-brightness-symbolic"
                label: model.label || model.displayName || i18n("Screen")
                value: model.brightness ?? 0
                maximum: model.maxBrightness ?? 100
                onMoved: value => screens.setBrightness(model.displayName, Math.round(value))
            }
        }
        LevelRow {
            visible: tile.hasKeyboard
            icon: "input-keyboard-symbolic"
            label: i18n("Keyboard backlight")
            value: keyboard.brightness
            maximum: keyboard.brightnessMax
            onMoved: value => keyboard.brightness = Math.round(value)
        }
        // Appearance: light, dark, or switching by itself at sunrise and sunset. Its name on one
        // line with Night Light (held off for now, as Plasma's widget has it) at the end, then the
        // three choices across the card's width: side by side they squeezed the name.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: colorMode.iconName
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }
            PlasmaComponents.Label {
                text: i18n("Appearance")
            }
            // Automatic: which of the two is on now
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: colorMode.mode !== "auto" ? ""
                    : colorMode.dark ? i18nc("appearance, automatic", "dark now") : i18nc("appearance, automatic", "light now")
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                elide: Text.ElideRight
            }
            PillButton {
                checked: tile.nightLight.inhibited
                text: tile.nightLight.inhibited ? i18n("Night Light off") : i18n("Night Light")
                icon.name: tile.nightLight.inhibited ? "redshift-status-off-symbolic" : "redshift-status-on-symbolic"
                onClicked: tile.nightLight.toggleInhibition()
            }
        }
        SegmentedControl {
            Layout.fillWidth: true
            Repeater {
                model: colorMode.modes
                delegate: PillButton {
                    required property string modelData
                    // Equal thirds of the card
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    bare: true
                    checked: colorMode.mode === modelData
                    text: colorMode.label(modelData)
                    icon.name: colorMode.iconFor(modelData)
                    onClicked: colorMode.set(modelData)
                }
            }
        }
    }
}
