/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"
import "../tiles" as Tiles

// The sound pill's card: the outputs, the current one checked, a click switches (the Controls
// tab's list, without its card around it); the Bluetooth headphones' battery when they report it
PopoutCard {
    id: card

    required property var island
    readonly property Item audio: island.controls.audio
    // The battery of the device sound is on, not of another headset that happens to be connected
    readonly property bool showBattery: island.headphones.outputPercent >= 0

    cardWidth: Kirigami.Units.gridUnit * 17

    Tiles.SoundOutputTile {
        Layout.fillWidth: true
        island: card.island
        color: "transparent"
        padding: 0
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: card.showBattery
        text: card.showBattery ? i18n("%1: battery %2%", card.island.headphones.output.name, card.island.headphones.outputPercent) : ""
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        elide: Text.ElideRight
    }
}
