/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents

import ".."

// Unread count, the latest two notifications, and Do Not Disturb. A click opens the tab.
Tile {
    id: tile

    required property Item watcher

    clickable: true

    // The model's rows are read by role; recount when it changes
    readonly property var latest: {
        tile.watcher.count; // dependency
        const out = [];
        for (let i = 0; i < Math.min(2, tile.watcher.count); ++i) {
            out.push({
                summary: tile.watcher.role(i, NotificationManager.Notifications.SummaryRole) || "",
                app: tile.watcher.role(i, NotificationManager.Notifications.ApplicationNameRole) || "",
                icon: tile.watcher.role(i, NotificationManager.Notifications.ApplicationIconNameRole) || "",
            });
        }
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: tile.watcher.doNotDisturb ? "notifications-disabled-symbolic" : "notification-inactive-symbolic"
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: tile.watcher.unreadCount > 0
                    ? i18np("%1 unread", "%1 unread", tile.watcher.unreadCount)
                    : i18n("Notifications")
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents.ToolButton {
                visible: tile.watcher.count > 0
                icon.name: "edit-clear-history"
                text: i18n("Clear All")
                display: PlasmaComponents.AbstractButton.IconOnly
                onClicked: tile.watcher.clearHistory()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            DndButton {
                watcher: tile.watcher
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: tile.watcher.doNotDisturb
            text: i18n("Do not disturb: %1", tile.watcher.dndText)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
        }

        Repeater {
            model: tile.latest
            delegate: RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
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

        PlasmaComponents.Label {
            visible: tile.watcher.count === 0
            text: i18n("All caught up")
            opacity: 0.6
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
