/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    Compact notification history. Uses the same model setup as the stock
    Notifications applet's history (see NotificationWatcher.qml).
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: tab

    required property Item watcher
    readonly property var model: watcher.model

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.Switch {
            text: i18n("Do not disturb")
            checked: tab.watcher.doNotDisturb
            onToggled: tab.watcher.toggleDoNotDisturb()
        }
        Item {
            Layout.fillWidth: true
        }
        PlasmaComponents.ToolButton {
            icon.name: "edit-clear-history"
            text: i18n("Clear All")
            display: PlasmaComponents.AbstractButton.IconOnly
            enabled: tab.watcher.count > 0
            onClicked: tab.watcher.clearHistory()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ToolButton {
            icon.name: "configure"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Configure Notifications…")
            onClicked: Qt.openUrlExternally("systemsettings://kcm_notifications")
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    PlasmaExtras.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.largeSpacing
        visible: tab.watcher.count === 0
        iconName: "checkmark"
        text: i18n("No unread notifications")
    }

    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tab.watcher.count > 0

        ListView {
            id: list
            model: tab.model
            spacing: Kirigami.Units.smallSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: PlasmaComponents.ItemDelegate {
                id: item

                required property int index
                required property var model

                readonly property bool isJob: model.type === NotificationManager.Notifications.JobType
                readonly property bool critical: model.urgency === NotificationManager.Notifications.CriticalUrgency
                readonly property var actionNames: model.actionNames || []
                readonly property var actionLabels: model.actionLabels || []

                function modelIndex() {
                    return tab.model.index(index, 0);
                }

                width: ListView.view.width
                onClicked: {
                    if (model.hasDefaultAction) {
                        tab.model.invokeDefaultAction(modelIndex());
                    }
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        radius: 1.5
                        visible: item.critical
                        color: Kirigami.Theme.negativeTextColor
                    }

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        Layout.alignment: Qt.AlignTop
                        source: item.model.image ? item.model.image
                            : (item.model.iconName || item.model.applicationIconName || "preferences-desktop-notification")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: item.model.applicationName || ""
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                            PlasmaComponents.Label {
                                text: tab.ago(item.model.updated || item.model.created)
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                            }
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: item.model.summary || ""
                            font.bold: !item.model.read
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            visible: text !== ""
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: item.model.body || ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            visible: text !== ""
                            opacity: 0.85
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        PlasmaComponents.ProgressBar {
                            Layout.fillWidth: true
                            visible: item.isJob && item.model.jobState !== NotificationManager.Notifications.JobStateStopped
                            from: 0
                            to: 100
                            value: item.model.percentage || 0
                        }
                        Flow {
                            Layout.fillWidth: true
                            visible: item.actionNames.length > 0
                            spacing: Kirigami.Units.smallSpacing
                            Repeater {
                                model: item.actionNames.length
                                PlasmaComponents.Button {
                                    required property int index
                                    text: item.actionLabels[index] || item.actionNames[index]
                                    onClicked: tab.model.invokeAction(item.modelIndex(), item.actionNames[index])
                                }
                            }
                        }
                    }

                    PlasmaComponents.ToolButton {
                        Layout.alignment: Qt.AlignTop
                        icon.name: "window-close"
                        visible: item.model.closable !== false
                        display: PlasmaComponents.AbstractButton.IconOnly
                        text: i18n("Close")
                        onClicked: tab.model.close(item.modelIndex())
                    }
                }
            }
        }
    }

    function ago(d) {
        if (!d) {
            return "";
        }
        const secs = Math.max(0, (Date.now() - new Date(d).getTime()) / 1000);
        if (secs < 60) {
            return i18nc("notification time", "now");
        }
        if (secs < 3600) {
            return i18nc("notification time, minutes", "%1 min", Math.floor(secs / 60));
        }
        if (secs < 86400) {
            return i18nc("notification time, hours", "%1 h", Math.floor(secs / 3600));
        }
        return Qt.formatDate(new Date(d), Qt.locale().dateFormat(Locale.ShortFormat));
    }
}
