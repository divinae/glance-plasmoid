/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"
import "./lib/timer.js" as TimerLogic

// The Focus pill's card, shown on hovering it (in place of its tooltip): the wedge large, what's
// running and how long is left, the session and today's total, the meeting warning, and the
// buttons — without opening the drawer.
PopoutCard {
    id: card

    required property Item timer
    // The screen held on for this session (its keep-awake setting)
    property bool keptAwake: false

    readonly property bool flow: timer.flowmodoroModeEnabled && !timer.isBreak()

    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        IndicatorIcon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            style: IndicatorIcon.Style.Pie
            running: card.timer.active
            paused: card.timer.sessionPaused
            progress: card.timer.progressFraction()
            indeterminate: card.timer.progressIndeterminate
            tint: Kirigami.Theme.textColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                text: card.timer.phaseTitle()
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                text: card.timer.phaseTime()
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                font.features: { "tnum": 1 }
            }
            PlasmaComponents.Label {
                visible: !card.flow && !card.timer.isBreak() && card.timer.numberOfSessions > 1
                text: i18n("Session %1 of %2", TimerLogic.sessionNumber(card.timer.stateVal), card.timer.numberOfSessions)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: card.timer.doneTodayText()
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        wrapMode: Text.Wrap
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: text !== ""
        text: card.timer.meetingWarning
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.neutralTextColor
        wrapMode: Text.Wrap
    }
    PlasmaComponents.Label {
        visible: card.keptAwake
        text: i18n("The screen is kept on.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    // The Focus tab's buttons (their words too), the main one lit
    RowLayout {
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        PillButton {
            highlighted: true
            text: card.timer.sessionBtnText
            icon.name: card.timer.sessionBtnIconSource
            onClicked: card.timer.toggleSession()
        }
        PillButton {
            visible: !card.timer.flowmodoroModeEnabled
            display: PlasmaComponents.AbstractButton.IconOnly
            text: card.timer.isBreak() ? i18n("Skip Break") : i18n("Skip to Break")
            icon.name: "chronometer-lap"
            onClicked: card.timer.skip()
        }
        PillButton {
            display: PlasmaComponents.AbstractButton.IconOnly
            text: (card.timer.isBreak() || card.timer.breakOvertime) ? i18n("&End for today") : i18n("St&op")
            icon.name: "chronometer-reset"
            onClicked: card.timer.endForToday()
        }
    }
}
