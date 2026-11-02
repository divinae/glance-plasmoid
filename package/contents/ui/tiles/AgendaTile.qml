/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The next few events of today (from Event Calendar's cache). A click opens the Agenda tab.
Tile {
    id: tile

    required property Item calendar
    property int maxEvents: 3

    clickable: true

    readonly property var events: calendar.todayEvents.slice(0, maxEvents)
    readonly property string timeFormat: Qt.locale().timeFormat(Locale.ShortFormat)

    function when(ev): string {
        if (ev.allDay) {
            return i18n("All day");
        }
        const m = calendar.minutesUntil(ev);
        if (m <= 0) {
            return i18nc("event happening now", "Now");
        }
        if (m < 60) {
            return i18nc("event starts in N minutes", "in %1 min", m);
        }
        return Qt.formatTime(ev.start, timeFormat);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: "view-calendar-day"
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Today")
                font.weight: Font.DemiBold
            }
        }

        Repeater {
            model: tile.events
            delegate: RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.fillHeight: true
                    radius: 2
                    color: row.modelData.color ? row.modelData.color : Kirigami.Theme.highlightColor
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: row.modelData.summary
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    text: tile.when(row.modelData)
                    textFormat: Text.PlainText
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: tile.events.length === 0
            text: tile.calendar.tomorrowFirst
                ? i18n("Nothing else today. Tomorrow: %1", tile.calendar.tomorrowFirst.summary)
                : i18n("Nothing else today.")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            opacity: 0.6
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
