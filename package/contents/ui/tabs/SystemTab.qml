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

// A simple system monitor after Caelestia's Performance tab: round gauges for the processor (its
// temperature below), the graphics card when known, memory and disk; the network along the
// bottom with a minute of history.
ColumnLayout {
    id: tab

    required property Item monitor

    spacing: Kirigami.Units.largeSpacing

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
    readonly property real cpu: monitor.number(monitor.cpu)
    readonly property real mem: monitor.number(monitor.memPercent)
    readonly property real disk: monitor.number(monitor.disk)

    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fraction: tab.cpu / 100
                value: Math.round(tab.cpu) + "%"
                label: i18n("Processor")
                detail: tab.monitor.ready(tab.monitor.cpuTemp)
                    ? i18nc("temperature", "%1 °C", Math.round(tab.monitor.number(tab.monitor.cpuTemp))) : ""
            }
            Gauge {
                visible: tab.monitor.ready(tab.monitor.gpu)
                Layout.fillWidth: true
                Layout.fillHeight: true
                fraction: tab.monitor.number(tab.monitor.gpu) / 100
                value: Math.round(tab.monitor.number(tab.monitor.gpu)) + "%"
                label: i18n("Graphics")
            }
            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fraction: tab.mem / 100
                value: tab.bytes(tab.monitor.number(tab.monitor.memUsed))
                label: i18n("Memory")
                detail: i18nc("of total memory", "of %1", tab.bytes(tab.monitor.number(tab.monitor.memTotal)))
            }
            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                fraction: tab.disk / 100
                value: Math.round(tab.disk) + "%"
                label: i18n("Disk")
                detail: i18nc("disk read and write speed", "↓ %1/s ↑ %2/s",
                    tab.bytes(tab.monitor.number(tab.monitor.diskRead)), tab.bytes(tab.monitor.number(tab.monitor.diskWrite)))
            }
        }
    }

    // The network: speeds and a minute of history
    Tile {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 4

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing
            ColumnLayout {
                spacing: 0
                RowLayout {
                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        source: "network-wired"
                    }
                    PlasmaComponents.Label {
                        text: i18n("Network")
                        font.weight: Font.DemiBold
                    }
                }
                PlasmaComponents.Label {
                    text: "↓ " + tab.bytes(tab.monitor.number(tab.monitor.down)) + "/s"
                    color: Kirigami.Theme.highlightColor
                }
                PlasmaComponents.Label {
                    text: "↑ " + tab.bytes(tab.monitor.number(tab.monitor.up)) + "/s"
                    color: Kirigami.Theme.positiveTextColor
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property real peak: Math.max(1, ...tab.monitor.downHistory, ...tab.monitor.upHistory)
                Sparkline {
                    anchors.fill: parent
                    values: tab.monitor.downHistory
                    capacity: tab.monitor.historyLength
                    maximum: parent.peak
                }
                Sparkline {
                    anchors.fill: parent
                    values: tab.monitor.upHistory
                    capacity: tab.monitor.historyLength
                    maximum: parent.peak
                    color: Kirigami.Theme.positiveTextColor
                }
            }
        }
    }
}
