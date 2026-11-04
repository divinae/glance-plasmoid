/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The next few events of today, from Event Calendar: a Join button on meetings, declined ones
// dimmed and struck through. A line opens its event in Event Calendar (eventClicked). Clipped: in the clock card it gets what is left.
Tile {
    id: tile

    required property Item calendar
    property int maxEvents: 3

    // A line clicked: that event (the card's other clicks: clicked())
    signal eventClicked(var ev)

    // Only its lines react (each opens its event): a click on the card as well fired twice
    clickable: false
    clip: true

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

    // The tooltip: the title, when (and your answer if it isn't yes), where
    function details(ev): string {
        let when = ev.allDay ? i18n("All day")
            : Qt.formatTime(ev.start, timeFormat) + " – " + Qt.formatTime(ev.end, timeFormat);
        if (ev.response === "declined") {
            when += " · " + i18n("Declined");
        } else if (ev.response === "tentative") {
            when += " · " + i18n("Maybe");
        } else if (ev.response === "needsAction") {
            when += " · " + i18n("Not answered yet");
        }
        return [ev.summary, when, ev.location].filter(t => !!t).join("\n");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: tile.events
            // A line: its hover highlight under the row of colour bar, title, time and Join
            delegate: Item {
                id: line
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + 4

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.textColor, rowHover.hovered ? 0.08 : 0)
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                RowLayout {
                    id: row
                    readonly property var modelData: line.modelData
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        radius: 1.5
                        color: row.modelData.color ? row.modelData.color : Kirigami.Theme.highlightColor
                    }
                    readonly property bool declined: modelData.response === "declined"
                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds
                        // Not on the Join icon: that one joins, and only that
                        onTapped: (point) => {
                            const p = joinIcon.mapFromItem(row, point.position);
                            if (!(joinIcon.visible && joinIcon.contains(p))) {
                                tile.eventClicked(row.modelData);
                            }
                        }
                    }
                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    // The event in full: title, when, where, which calendar, your answer
                    QQC2.ToolTip.text: tile.details(modelData)
                    QQC2.ToolTip.visible: rowHover.hovered && !joinArea.containsMouse
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    opacity: declined ? 0.5 : 1
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: row.modelData.summary
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.strikeout: row.declined
                        font.italic: row.modelData.response === "tentative"
                    }
                    PlasmaComponents.Label {
                        text: tile.when(row.modelData)
                        textFormat: Text.PlainText
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    // Join: the meeting's own link (Meet, Zoom, Teams...), a small icon in the line
                    Kirigami.Icon {
                        id: joinIcon
                        visible: !!row.modelData.meetingUrl && !row.declined
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: Qt.resolvedUrl("icons/glance-camera.svg")
                        isMask: true
                        color: Kirigami.Theme.textColor
                        active: joinArea.containsMouse
                        MouseArea {
                            id: joinArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tile.calendar.join(row.modelData)
                        }
                        QQC2.ToolTip.text: row.modelData.meetingLabel ? i18n("Join (%1)", row.modelData.meetingLabel) : i18n("Join")
                        QQC2.ToolTip.visible: joinArea.containsMouse
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
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
