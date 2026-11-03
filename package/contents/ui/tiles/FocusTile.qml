/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../focus" as Focus

// Focus at a glance: the session's ring and time, the task or its kind, and start/pause. A click
// elsewhere opens the Focus tab.
Tile {
    id: tile

    required property var timer

    clickable: true

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillHeight: true
        }
        Focus.ProgressCircle {
            Layout.alignment: Qt.AlignHCenter
            size: Kirigami.Units.gridUnit * 3
            lineWidth: Kirigami.Units.smallSpacing
            arcBegin: 0
            arcEnd: 360 * tile.timer.progressFraction()
            showBackground: true
            colorCircle: tile.timer.getCircleColor()

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: tile.timer.panelTimeText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: tile.timer.settings.focus_task_label && !tile.timer.isBreak()
                ? tile.timer.settings.focus_task_label : tile.timer.statusText
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlasmaComponents.ToolButton {
            Layout.alignment: Qt.AlignHCenter
            icon.name: tile.timer.sessionBtnIconSource
            text: tile.timer.sessionBtnText.replace("&", "")
            display: PlasmaComponents.AbstractButton.TextBesideIcon
            onClicked: tile.timer.toggleSession()
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
