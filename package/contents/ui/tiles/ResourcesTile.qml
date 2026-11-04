/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// CPU, memory and disk as three upright bars with their icons below (Caelestia's). A click opens
// the System tab.
Tile {
    id: tile

    required property Item monitor

    clickable: true

    component Bar: ColumnLayout {
        id: bar
        property real value: 0
        property string icon
        property string label
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.preferredWidth: 8
            radius: 4
            color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * Math.max(0, Math.min(1, bar.value / 100)))
                radius: parent.radius
                color: bar.value > 90 ? Kirigami.Theme.negativeTextColor
                    : bar.value > 75 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                Behavior on height {
                    NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                }
            }
        }
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: Qt.resolvedUrl("icons/glance-" + bar.icon + ".svg")
            // Drawn for this card, line icons in the text colour, alike
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.8
        }
        PlasmaComponents.ToolTip.text: bar.label + ": " + Math.round(bar.value) + "%"
        PlasmaComponents.ToolTip.visible: hover.hovered
        HoverHandler {
            id: hover
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        Bar {
            icon: "cpu"
            label: i18n("Processor")
            value: tile.monitor.number(tile.monitor.cpu)
        }
        Bar {
            icon: "memory"
            label: i18n("Memory")
            value: tile.monitor.number(tile.monitor.memPercent)
        }
        Bar {
            icon: "disk"
            label: i18n("Disk")
            value: tile.monitor.number(tile.monitor.disk)
        }
    }
}
