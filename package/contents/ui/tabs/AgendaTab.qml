/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: tab

    required property Item calendar

    spacing: Kirigami.Units.smallSpacing

    readonly property string timeFormat: Qt.locale().timeFormat(Locale.ShortFormat)

    PlasmaExtras.Heading {
        level: 5
        text: i18n("Today")
        opacity: 0.7
    }

    Repeater {
        model: tab.calendar.todayEvents
        delegate: eventRow
    }

    PlasmaComponents.Label {
        visible: tab.calendar.todayEvents.length === 0
        text: i18n("Nothing else today.")
        opacity: 0.6
    }

    PlasmaExtras.Heading {
        visible: tab.calendar.tomorrowFirst !== null
        level: 5
        text: i18n("Tomorrow")
        opacity: 0.7
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
    Loader {
        Layout.fillWidth: true
        active: tab.calendar.tomorrowFirst !== null
        sourceComponent: eventRow
        property var modelData: tab.calendar.tomorrowFirst
    }

    Component {
        id: eventRow

        PlasmaComponents.ItemDelegate {
            id: row
            required property var modelData
            readonly property var ev: modelData
            readonly property int minutes: ev && !ev.allDay ? tab.calendar.minutesUntil(ev) : 0
            readonly property bool now: ev && !ev.allDay && minutes <= 0 && ev.end > tab.calendar.now

            Layout.fillWidth: true
            enabled: ev && ev.link !== ""
            onClicked: Qt.openUrlExternally(ev.link)

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.fillHeight: true
                    radius: 2
                    color: row.ev && row.ev.color ? row.ev.color : Kirigami.Theme.highlightColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: row.ev ? row.ev.summary : ""
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.bold: row.now
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: !row.ev ? "" : row.ev.allDay ? i18n("All day")
                            : Qt.formatTime(row.ev.start, tab.timeFormat) + " – " + Qt.formatTime(row.ev.end, tab.timeFormat)
                                + (row.ev.location ? "  ·  " + row.ev.location : "")
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
                PlasmaComponents.Label {
                    visible: row.ev && !row.ev.allDay && (row.now || (row.minutes > 0 && row.minutes < 120))
                    text: row.now ? i18n("now") : i18n("in %1 min", row.minutes)
                    font: Kirigami.Theme.smallFont
                    color: row.now ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
