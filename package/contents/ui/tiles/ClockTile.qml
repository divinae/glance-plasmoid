/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The time stacked, hours over minutes with three dots between (Caelestia's), and the date.
Tile {
    id: tile

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: tile.visible
        triggeredOnStart: true
        onTriggered: tile.now = new Date()
    }

    readonly property real digitSize: Kirigami.Theme.defaultFont.pointSize * 2.6

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(tile.now, "hh")
            font.pointSize: tile.digitSize
            font.weight: Font.Bold
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Kirigami.Units.smallSpacing
            Layout.bottomMargin: -Kirigami.Units.smallSpacing
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Kirigami.Theme.highlightColor
                }
            }
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(tile.now, "mm")
            font.pointSize: tile.digitSize
            font.weight: Font.Bold
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: tile.now.toLocaleDateString(Qt.locale(), "ddd, d")
            textFormat: Text.PlainText
            color: Kirigami.Theme.highlightColor
            font.weight: Font.DemiBold
        }
    }
}
