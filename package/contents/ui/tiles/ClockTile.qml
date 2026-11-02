/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The time, large, and the date; with the system monitor on, CPU and memory below.
Tile {
    id: tile

    property Item monitor: null

    property date now: new Date()
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
            Layout.fillHeight: true
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: Qt.formatTime(tile.now, Qt.locale().timeFormat(Locale.ShortFormat))
            textFormat: Text.PlainText
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.8
            font.weight: Font.Bold
            fontSizeMode: Text.HorizontalFit
            minimumPointSize: Kirigami.Theme.defaultFont.pointSize
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tile.now.toLocaleDateString(Qt.locale(), "dddd")
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            color: Kirigami.Theme.highlightColor
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

        // CPU and memory at a glance
        Repeater {
            model: tile.monitor ? [
                {label: i18nc("processor, short", "CPU"), value: tile.monitor.number(tile.monitor.cpu)},
                {label: i18nc("memory, short", "RAM"), value: tile.monitor.number(tile.monitor.memPercent)},
            ] : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                    text: modelData.label
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.value / 100))
                        height: parent.height
                        radius: parent.radius
                        color: Kirigami.Theme.highlightColor
                        Behavior on width {
                            NumberAnimation { duration: Kirigami.Units.longDuration }
                        }
                    }
                }
                PlasmaComponents.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(modelData.value) + "%"
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }
    }
}
