/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"

// The Shift pill's card: time to switch, how today stands; switch (or move the desk), snooze
PopoutCard {
    id: card

    required property Item stand
    readonly property bool standing: stand.cycle.position === "stand"
    // Move the desk, or Done: as the reminder offers it
    readonly property var next: stand.switchAction()
    readonly property url nextIcon: Qt.resolvedUrl(standing ? "../stand/icons/person-sit.svg" : "../stand/icons/person-stand.svg")

    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            source: card.nextIcon
            isMask: true
            color: Kirigami.Theme.textColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                text: card.stand.pendingPosition ? i18n("Did you switch?") : card.stand.statusText()
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.stand.todayText()
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.Wrap
            }
        }
    }
    RowLayout {
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: !card.stand.pendingPosition
        PillButton {
            highlighted: true
            text: card.next.label
            icon.source: card.nextIcon
            onClicked: card.next.run()
        }
        PillButton {
            text: i18n("Snooze %1 min", card.stand.settings.stand_snooze_minutes)
            icon.name: "chronometer-pause"
            onClicked: card.stand.snooze()
        }
    }
    RowLayout {
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: !!card.stand.pendingPosition
        PillButton {
            highlighted: true
            text: i18n("Yes")
            icon.name: "dialog-ok"
            onClicked: card.stand.confirmPending()
        }
        PillButton {
            text: i18n("Not yet")
            icon.name: "dialog-cancel"
            onClicked: card.stand.cancelPending()
        }
    }
}
