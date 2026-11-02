/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// This month: weekday names, the days (other months' faint), today in an accent circle, a dot
// under days with events (from Event Calendar's cache). A click opens the Agenda tab.
Tile {
    id: tile

    required property Item calendar

    clickable: true

    property date now: new Date()
    Timer {
        interval: 60000
        repeat: true
        running: tile.visible
        onTriggered: tile.now = new Date()
    }

    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek // 0 Sunday … 6 Saturday
    readonly property date monthStart: new Date(now.getFullYear(), now.getMonth(), 1)
    // The grid starts on the week's first day on or before the 1st
    readonly property date gridStart: {
        const lead = (monthStart.getDay() - firstDayOfWeek + 7) % 7;
        return new Date(now.getFullYear(), now.getMonth(), 1 - lead);
    }
    readonly property int weeks: {
        const days = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const lead = (monthStart.getDay() - firstDayOfWeek + 7) % 7;
        return Math.ceil((lead + days) / 7);
    }
    // "y-m-d" of the days with events in the grid
    readonly property var eventDays: {
        const out = {};
        const from = gridStart.getTime();
        const to = from + weeks * 7 * 86400000;
        for (const ev of calendar._events || []) {
            for (let t = Math.max(from, new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate()).getTime());
                    t < Math.min(to, ev.end.getTime() + (ev.allDay ? 0 : 1)); t += 86400000) {
                const d = new Date(t);
                out[d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()] = true;
            }
        }
        return out;
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tile.now.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: 7
                PlasmaComponents.Label {
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((tile.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
            }
            Repeater {
                model: tile.weeks * 7
                Item {
                    id: day
                    required property int index
                    readonly property date date: new Date(tile.gridStart.getFullYear(), tile.gridStart.getMonth(), tile.gridStart.getDate() + index)
                    readonly property bool inMonth: date.getMonth() === tile.now.getMonth()
                    readonly property bool today: date.getFullYear() === tile.now.getFullYear()
                        && date.getMonth() === tile.now.getMonth() && date.getDate() === tile.now.getDate()
                    readonly property bool busy: !!tile.eventDays[date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate()]
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: label.implicitHeight + 4

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: width / 2
                        visible: day.today
                        color: Kirigami.Theme.highlightColor
                    }
                    PlasmaComponents.Label {
                        id: label
                        anchors.centerIn: parent
                        text: day.date.getDate()
                        font: Kirigami.Theme.smallFont
                        color: day.today ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        opacity: day.inMonth ? 1 : 0.35
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: label.bottom
                        width: 3
                        height: 3
                        radius: 1.5
                        visible: day.busy && !day.today
                        color: Kirigami.Theme.highlightColor
                    }
                }
            }
        }
    }
}
