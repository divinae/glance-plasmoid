/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."

// The time, large, the weekday in the accent colour and the date.
Tile {
    id: tile

    property date now: new Date()
    // Top-aligned rather than centred, for a card that has more below it
    property bool alignTop: false
    // The time's size, in multiples of the default font
    property real timeScale: 2.8
    Timer {
        interval: 1000
        repeat: true
        running: tile.visible
        triggeredOnStart: true
        onTriggered: tile.now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            visible: !tile.alignTop
            Layout.fillHeight: true
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: Qt.formatTime(tile.now, Qt.locale().timeFormat(Locale.ShortFormat))
            textFormat: Text.PlainText
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * tile.timeScale
            font.weight: Font.Bold
            fontSizeMode: Text.HorizontalFit
            minimumPointSize: Kirigami.Theme.defaultFont.pointSize
        }
        AccentLabel {
            Layout.fillWidth: true
            text: tile.now.toLocaleDateString(Qt.locale(), "dddd")
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tile.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy")
            textFormat: Text.PlainText
            opacity: 0.7
            elide: Text.ElideRight
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
