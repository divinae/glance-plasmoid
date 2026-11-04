/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"

// The unread pill's card: the latest few, in short; open them all, or clear
PopoutCard {
    id: card

    required property var island
    required property Item watcher

    cardWidth: Kirigami.Units.gridUnit * 17

    PlasmaComponents.Label {
        text: i18np("%1 unread", "%1 unread", card.watcher.unreadCount)
        font.weight: Font.DemiBold
    }
    Repeater {
        model: card.watcher.latest(3)
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: row.modelData.icon || "preferences-desktop-notification"
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: row.modelData.summary || row.modelData.app
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
        }
    }
    RowLayout {
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        PillButton {
            highlighted: true
            text: i18n("Open")
            icon.name: "notifications-symbolic"
            onClicked: card.island.openOn("notifications", true)
        }
        PillButton {
            text: i18n("Clear All")
            icon.name: "edit-clear-history"
            onClicked: card.watcher.clearHistory()
        }
    }
}
