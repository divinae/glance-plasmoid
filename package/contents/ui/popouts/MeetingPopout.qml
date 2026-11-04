/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."
import "../common"

// The meeting pill's card: what it is, until when and how far in, where; Join and Event Calendar
PopoutCard {
    id: card

    required property var island
    readonly property var ev: island.meetingOn
    readonly property color tint: ev && ev.color ? ev.color : Kirigami.Theme.highlightColor
    // How far in, 0-1 (ticks with the pill's countdown)
    readonly property real fraction: {
        island.meetingCountdown; // dependency
        if (!ev) {
            return 0;
        }
        const span = ev.end.getTime() - ev.start.getTime();
        return span > 0 ? Math.max(0, Math.min(1, (Date.now() - ev.start.getTime()) / span)) : 0;
    }

    cardWidth: Kirigami.Units.gridUnit * 16

    RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Rectangle {
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            radius: 1.5
            color: card.tint
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.ev ? card.ev.summary : ""
                textFormat: Text.PlainText
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                text: card.ev ? i18nc("meeting: its times and what's left", "%1 · %2 left",
                    card.island.calendar.timeRange(card.ev), card.island.meetingCountdown) : ""
                font.features: { "tnum": 1 }
                opacity: 0.8
            }
        }
    }
    // How far in
    ProgressEdge {
        Layout.fillWidth: true
        implicitHeight: 4
        fraction: card.fraction
        color: card.tint
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: text !== ""
        text: card.ev ? [card.ev.location, card.ev.guests > 0 ? i18np("%1 guest", "%1 guests", card.ev.guests) : "", card.ev.calendar]
            .filter(t => !!t).join(" · ") : ""
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        elide: Text.ElideRight
    }
    PlasmaComponents.Label {
        visible: card.island.cfg.keepAwakeMeetings && card.island.inMeeting
        text: i18n("The screen is kept on.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    RowLayout {
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        PillButton {
            visible: !!card.ev && !!card.ev.meetingUrl
            highlighted: true
            text: card.ev && card.ev.meetingLabel ? i18n("Join %1", card.ev.meetingLabel) : i18n("Join")
            icon.source: Qt.resolvedUrl("../tiles/icons/glance-camera.svg")
            onClicked: card.island.joinMeeting(card.ev)
        }
        PillButton {
            visible: card.island.eventCalendarLinked
            text: i18n("Details")
            icon.name: "view-calendar-day-symbolic"
            onClicked: card.island.openEventCalendar(card.ev)
        }
    }
}
