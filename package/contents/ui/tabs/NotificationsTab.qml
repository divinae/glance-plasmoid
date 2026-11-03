/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    Notification history, grouped by application, as the stock Notifications applet's (see
    NotificationWatcher.qml for the models).
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import ".."

ColumnLayout {
    id: tab

    required property Item watcher
    readonly property var model: watcher.groupedModel

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        DndButton {
            watcher: tab.watcher
            showText: true
        }
        Item {
            Layout.fillWidth: true
        }
        IconButton {
            icon.name: "edit-clear-history"
            text: i18n("Clear All")
            enabled: tab.watcher.count > 0
            onClicked: tab.watcher.clearHistory()
        }
        IconButton {
            icon.name: "configure"
            text: i18n("Configure Notifications…")
            onClicked: Qt.openUrlExternally("systemsettings://kcm_notifications")
        }
    }

    PlasmaExtras.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.largeSpacing
        visible: tab.watcher.count === 0
        iconName: tab.watcher.doNotDisturb ? "notifications-disabled-symbolic" : "checkmark"
        text: i18n("No notifications")
        explanation: tab.watcher.doNotDisturb ? i18n("Do not disturb: %1", tab.watcher.dndText) : ""
    }

    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // It scrolls itself: don't let the page grow (and scroll the header away) with it
        Layout.preferredHeight: 0
        visible: tab.watcher.count > 0

        ListView {
            model: tab.model
            spacing: Kirigami.Units.smallSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Loader {
                id: row
                required property int index
                required property var model
                width: ListView.view.width
                sourceComponent: model.isGroup ? groupHeader : notification

                Component {
                    id: groupHeader
                    // The application: icon, name, how many, expand or collapse, clear the group
                    PlasmaComponents.ItemDelegate {
                        readonly property int hidden: row.model.groupChildrenCount - row.model.expandedGroupChildrenCount
                        onClicked: row.model.isGroupExpanded = !row.model.isGroupExpanded
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: row.model.applicationIconName || "preferences-desktop-notification"
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: row.model.applicationName || ""
                                textFormat: Text.PlainText
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                text: row.model.isGroupExpanded || parent.parent.hidden <= 0
                                    ? i18np("%1 notification", "%1 notifications", row.model.groupChildrenCount)
                                    : i18np("+%1 more", "+%1 more", parent.parent.hidden)
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                visible: row.model.groupChildrenCount > 2
                                source: row.model.isGroupExpanded ? "arrow-up" : "arrow-down"
                            }
                            IconButton {
                                icon.name: "window-close"
                                text: i18n("Clear Group")
                                onClicked: tab.model.close(tab.model.index(row.index, 0))
                            }
                        }
                    }
                }

                Component {
                    id: notification
                    PlasmaComponents.ItemDelegate {
                        leftPadding: row.model.isInGroup ? Kirigami.Units.gridUnit : Kirigami.Units.smallSpacing
                        onClicked: {
                            if (row.model.hasDefaultAction) {
                                tab.model.invokeDefaultAction(tab.model.index(row.index, 0), 1 /* Close */);
                            }
                        }
                        contentItem: NotificationItem {
                            notifications: tab.model
                            rowIndex: row.index
                            notif: row.model
                            inGroup: row.model.isInGroup === true
                        }
                    }
                }
            }
        }
    }
}
