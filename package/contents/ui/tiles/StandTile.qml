/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../stand"
import "../stand/lib/cycle.js" as Cycle

// Stand at a glance: the posture in its ring, what it is and what's next. A click opens the
// Stand tab; when a switch is due, the card says so in its colour.
Tile {
    id: tile

    required property var stand

    clickable: true
    border.width: stand.switchDue ? 2 : 0
    border.color: "#c9a227"

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillHeight: true
        }
        ProgressCircle {
            Layout.alignment: Qt.AlignHCenter
            size: Kirigami.Units.gridUnit * 3
            lineWidth: Kirigami.Units.smallSpacing
            arcBegin: 0
            arcEnd: 360 * Cycle.progress(tile.stand.cycle, tile.stand.cfg)
            showBackground: true
            colorCircle: tile.stand.switchDue ? "#c9a227" : tile.stand.ringColor
            colorBackground: tile.stand.themeTrackColor
            indeterminate: tile.stand.deskDriver.moving

            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.45
                height: width
                source: tile.stand.postureIcon
                isMask: true
                color: tile.stand.themeTextColor
                opacity: tile.stand.idle ? 0.5 : 1
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: tile.stand.statusText()
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: tile.stand.countdownText()
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
