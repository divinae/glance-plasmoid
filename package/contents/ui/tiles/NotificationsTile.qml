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

    // The top notification shown last (summary + app): a new one at the top fades in
    property string shownTop: ""
    // Not on the first fill (the history at startup), from then on yes
    property bool primed: false
    onLatestChanged: Qt.callLater(() => {
        tile.shownTop = tile.latest.length > 0 ? tile.latest[0].summary + tile.latest[0].app : "";
        tile.primed = true;
    })

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
            // No bell before the title: the Do Not Disturb button at the end is one, and shows it
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: tile.watcher.unreadCount > 0
                    ? i18np("%1 unread", "%1 unread", tile.watcher.unreadCount)
                    : i18n("Notifications")
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IconButton {
                visible: tile.watcher.count > 0
                icon.name: "edit-clear-history"
                text: i18n("Clear All")
                onClicked: tile.watcher.clearHistory()
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
                required property int index
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                // The newest fades in when it arrives (the rows are rebuilt on every change, so
                // only the top one, and only when it's a different notification)
                opacity: 1
                Component.onCompleted: {
                    if (index === 0 && tile.primed && tile.shownTop !== modelData.summary + modelData.app) {
                        opacity = 0;
                        fadeIn.start();
                    }
                }
                NumberAnimation on opacity {
                    id: fadeIn
                    running: false
                    to: 1
                    duration: Kirigami.Units.longDuration
                }
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
