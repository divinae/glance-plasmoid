/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."
import "../tiles"

// A simple system monitor: CPU (with its temperature and the GPU when known), memory, disk and
// network, each on a card, with a minute of history for the CPU and the network.
GridLayout {
    id: tab

    required property Item monitor

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    function bytes(b: real): string {
        if (!(b > 0)) {
            return "0 B";
        }
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            ++i;
        }
        return (i === 0 ? Math.round(b) : b.toFixed(b < 10 ? 1 : 0)) + " " + units[i];
    }
    function percent(v: real): string {
        return Math.round(v) + "%";
    }

    // A card: an icon and a title, the main figure large, a second line, and a chart or bar below
    component Card: Tile {
        id: card
        property string icon
        property string title
        property string value
        property string detail
        default property alias extra: below.data

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.minimumHeight: Kirigami.Units.gridUnit * 5

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing / 2

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: card.icon
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    text: card.value
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    font.weight: Font.Bold
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.detail
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            Item {
                id: below
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    // A slim bar for a share of something
    component Meter: Rectangle {
        property real fraction: 0
        height: 6
        radius: 3
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraction))
            height: parent.height
            radius: parent.radius
            color: parent.fraction > 0.9 ? Kirigami.Theme.negativeTextColor
                : parent.fraction > 0.75 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
            Behavior on width {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }
        }
    }

    Card {
        icon: "cpu"
        title: i18n("Processor")
        value: tab.percent(tab.monitor.number(tab.monitor.cpu))
        detail: {
            const parts = [];
            if (tab.monitor.ready(tab.monitor.cpuTemp)) {
                parts.push(i18nc("temperature", "%1 °C", Math.round(tab.monitor.number(tab.monitor.cpuTemp))));
            }
            if (tab.monitor.ready(tab.monitor.gpu)) {
                parts.push(i18nc("graphics card usage", "GPU %1", tab.percent(tab.monitor.number(tab.monitor.gpu))));
            }
            return parts.join(" · ");
        }
        Sparkline {
            anchors.fill: parent
            values: tab.monitor.cpuHistory
            maximum: 100
            capacity: tab.monitor.historyLength
        }
    }
    Card {
        icon: "memory"
        title: i18n("Memory")
        value: tab.percent(tab.monitor.number(tab.monitor.memPercent))
        detail: i18nc("memory used of total", "%1 of %2",
            tab.bytes(tab.monitor.number(tab.monitor.memUsed)), tab.bytes(tab.monitor.number(tab.monitor.memTotal)))
        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            fraction: tab.monitor.number(tab.monitor.memPercent) / 100
        }
    }
    Card {
        icon: "drive-harddisk"
        title: i18n("Disk")
        value: tab.percent(tab.monitor.number(tab.monitor.disk))
        detail: i18nc("disk read and write speed", "↓ %1/s · ↑ %2/s",
            tab.bytes(tab.monitor.number(tab.monitor.diskRead)), tab.bytes(tab.monitor.number(tab.monitor.diskWrite)))
        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            fraction: tab.monitor.number(tab.monitor.disk) / 100
        }
    }
    Card {
        icon: "network-wired"
        title: i18n("Network")
        value: ""
        detail: i18nc("network download and upload speed", "↓ %1/s · ↑ %2/s",
            tab.bytes(tab.monitor.number(tab.monitor.down)), tab.bytes(tab.monitor.number(tab.monitor.up)))
        Sparkline {
            anchors.fill: parent
            values: tab.monitor.downHistory
            capacity: tab.monitor.historyLength
        }
        Sparkline {
            anchors.fill: parent
            values: tab.monitor.upHistory
            capacity: tab.monitor.historyLength
            color: Kirigami.Theme.positiveTextColor
            maximum: Math.max(1, ...tab.monitor.downHistory, ...tab.monitor.upHistory)
        }
    }
}
