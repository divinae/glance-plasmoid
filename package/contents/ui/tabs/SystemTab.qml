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
import "../Format.js" as Format

// The system after Caelestia's Performance tab: the processor large in the middle (its usage
// around, its temperature inside), the graphics card and memory smaller either side; the disk
// and the network below, each with a minute of history.
ColumnLayout {
    id: tab

    required property Item monitor

    spacing: Kirigami.Units.largeSpacing

    readonly property real cpu: monitor.number(monitor.cpu)
    readonly property bool hasTemp: monitor.ready(monitor.cpuTemp)
    readonly property real temp: monitor.number(monitor.cpuTemp)
    readonly property bool hasGpu: monitor.ready(monitor.gpu)
    readonly property real gpu: monitor.number(monitor.gpu)
    readonly property real mem: monitor.number(monitor.memPercent)
    readonly property real disk: monitor.number(monitor.disk)
    readonly property color readColor: Kirigami.Theme.highlightColor
    readonly property color writeColor: Kirigami.Theme.positiveTextColor

    // ---- gauges: small, large, small ---------------------------------------------------
    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Gauge {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: parent.height * 0.7
                Layout.alignment: Qt.AlignVCenter
                visible: tab.hasGpu
                fraction: tab.gpu / 100
                value: Math.round(tab.gpu) + "%"
                label: i18n("Graphics")
            }
            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.5
                fraction: tab.cpu / 100
                innerFraction: tab.hasTemp ? Math.min(1, tab.temp / 100) : -1
                // Usage the figure and the outer ring, as on the others; the temperature the inner
                // ring, in a warm colour, red when hot, named below by a dot of its colour
                innerColor: tab.temp > 85 ? Kirigami.Theme.negativeTextColor : "#ff9f0a"
                value: Math.round(tab.cpu) + "%"
                label: i18n("Processor")
                detail: tab.hasTemp ? i18nc("temperature", "%1 °C", Math.round(tab.temp)) : ""
                detailDot: tab.hasTemp
            }
            Gauge {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: parent.height * 0.7
                Layout.alignment: Qt.AlignVCenter
                fraction: tab.mem / 100
                value: Format.bytes(tab.monitor.number(tab.monitor.memUsed))
                label: i18n("Memory")
                detail: i18nc("of total memory", "of %1", Format.bytes(tab.monitor.number(tab.monitor.memTotal)))
            }
        }
    }

    // ---- disk and network ---------------------------------------------------------------
    // Its height fixed: a nested layout takes "fill" from its cards and took all of it
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        Layout.maximumHeight: Kirigami.Units.gridUnit * 5
        spacing: Kirigami.Units.largeSpacing

        // A card: icon, title and a figure on top, two speeds, and their history behind
        component Activity: Tile {
            id: card
            property string icon
            property string title
            property string figure
            property string firstLabel
            property string secondLabel
            property var firstHistory: []
            property var secondHistory: []
            property real fraction: -1
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            Item {
                id: chart
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.55
                readonly property real peak: Math.max(1, ...card.firstHistory, ...card.secondHistory)
                Sparkline {
                    anchors.fill: parent
                    values: card.firstHistory
                    capacity: tab.monitor.historyLength
                    maximum: chart.peak
                    color: tab.readColor
                }
                Sparkline {
                    anchors.fill: parent
                    values: card.secondHistory
                    capacity: tab.monitor.historyLength
                    maximum: chart.peak
                    color: tab.writeColor
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
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
                        visible: text !== ""
                        text: card.figure
                        font.weight: Font.Bold
                    }
                }
                // How full, for the disk
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    visible: card.fraction >= 0
                    radius: 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.fraction))
                        height: parent.height
                        radius: parent.radius
                        color: card.fraction > 0.9 ? Kirigami.Theme.negativeTextColor
                            : card.fraction > 0.75 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    AccentLabel {
                        text: card.firstLabel
                        font: Kirigami.Theme.smallFont
                    }
                    PlasmaComponents.Label {
                        text: card.secondLabel
                        color: Kirigami.ColorUtils.linearInterpolation(tab.writeColor, Kirigami.Theme.textColor, 0.4)
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        Activity {
            icon: "drive-harddisk"
            title: i18n("Disk")
            figure: Math.round(tab.disk) + "%"
            fraction: tab.disk / 100
            firstLabel: i18nc("disk read speed", "read %1/s", Format.bytes(tab.monitor.number(tab.monitor.diskRead)))
            secondLabel: i18nc("disk write speed", "write %1/s", Format.bytes(tab.monitor.number(tab.monitor.diskWrite)))
            firstHistory: tab.monitor.diskReadHistory
            secondHistory: tab.monitor.diskWriteHistory
        }
        Activity {
            icon: "network-wired"
            title: i18n("Network")
            firstLabel: "↓ " + Format.bytes(tab.monitor.number(tab.monitor.down)) + "/s"
            secondLabel: "↑ " + Format.bytes(tab.monitor.number(tab.monitor.up)) + "/s"
            firstHistory: tab.monitor.downHistory
            secondHistory: tab.monitor.upHistory
        }
    }
}
