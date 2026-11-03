/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents

import com.dv.island.private as Island

import "Format.js" as Format

// One notification: who sent it and when, its text, the files it carries (images as thumbnails),
// a file transfer's progress with pause, resume and cancel, its actions, and a reply field.
// The history's (NotificationsTab).
Item {
    id: item

    // The NotificationManager.Notifications model and the row's data (the delegate's `model`)
    required property var notifications
    required property int rowIndex
    required property var notif

    // In a group, the app name and icon are in the group's header
    property bool inGroup: false

    readonly property bool isJob: notif.type === NotificationManager.Notifications.JobType
    readonly property bool critical: notif.urgency === NotificationManager.Notifications.CriticalUrgency
    readonly property var actionNames: notif.actionNames || []
    readonly property var actionLabels: notif.actionLabels || []
    readonly property var urls: notif.urls || []
    readonly property var job: notif.jobDetails || null
    readonly property int jobState: notif.jobState !== undefined ? notif.jobState : -1
    readonly property bool jobRunning: isJob && jobState === NotificationManager.Notifications.JobStateRunning
    readonly property bool jobSuspended: isJob && jobState === NotificationManager.Notifications.JobStateSuspended
    readonly property bool jobDone: isJob && jobState === NotificationManager.Notifications.JobStateStopped
    readonly property bool jobFailed: jobDone && (notif.jobError || 0) !== 0

    implicitHeight: row_.implicitHeight

    function idx() {
        return notifications.index(rowIndex, 0);
    }

    function formatDuration(secs: real): string {
        secs = Math.max(0, Math.round(secs));
        if (secs < 60) {
            return i18nc("seconds left", "%1 s", secs);
        }
        if (secs < 3600) {
            return i18nc("minutes and seconds left", "%1 min %2 s", Math.floor(secs / 60), secs % 60);
        }
        return i18nc("hours and minutes left", "%1 h %2 min", Math.floor(secs / 3600), Math.floor(secs % 3600 / 60));
    }
    // "12.4 MiB of 300 MiB · 8.2 MiB/s · 35 s left"
    readonly property string jobText: {
        if (!job) {
            return "";
        }
        const parts = [];
        if (job.totalBytes > 0) {
            parts.push(i18nc("bytes done of total", "%1 of %2", Format.bytes(job.processedBytes), Format.bytes(job.totalBytes)));
        } else if (job.totalFiles > 1) {
            parts.push(i18nc("files done of total", "%1 of %2 files", job.processedFiles, job.totalFiles));
        }
        if (jobRunning && job.speed > 0) {
            parts.push(i18nc("transfer speed", "%1/s", Format.bytes(job.speed)));
            if (job.totalBytes > job.processedBytes) {
                parts.push(i18nc("time left", "%1 left", formatDuration((job.totalBytes - job.processedBytes) / job.speed)));
            }
        }
        if (jobSuspended) {
            parts.push(i18n("Paused"));
        }
        return parts.join(" · ");
    }

    function ago(d): string {
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

    function isImage(url: string): bool {
        return /\.(png|jpe?g|webp|gif|bmp|svg|avif|heic|tiff?)$/i.test(url);
    }

    RowLayout {
        id: row_
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        // A critical one: a red bar along its side
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
            visible: !item.inGroup || !!item.notif.image
            source: item.notif.image ? item.notif.image
                : (item.notif.iconName || item.notif.applicationIconName || "preferences-desktop-notification")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: item.inGroup ? (item.notif.summary || "") : (item.notif.applicationName || "")
                    font.bold: item.inGroup && !item.notif.read
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.pointSize: item.inGroup ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.smallFont.pointSize
                    opacity: item.inGroup ? 1 : 0.7
                }
                PlasmaComponents.Label {
                    text: item.ago(item.notif.updated || item.notif.created)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: !item.inGroup && text !== ""
                text: item.notif.summary || ""
                font.bold: !item.notif.read
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: item.notif.body || ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                visible: text !== ""
                opacity: 0.85
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // ---- files it carries: images as thumbnails, the rest as an icon and name ----
            Flow {
                Layout.fillWidth: true
                visible: item.urls.length > 0 && !item.isJob
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: item.urls.slice(0, 4)
                    delegate: Item {
                        id: file
                        required property var modelData
                        readonly property string url: String(modelData)
                        readonly property bool image: item.isImage(url)
                        width: image ? Kirigami.Units.gridUnit * 6 : fileRow.implicitWidth + Kirigami.Units.largeSpacing
                        height: image ? Kirigami.Units.gridUnit * 4 : Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: Qt.alpha(Kirigami.Theme.textColor, fileHover.hovered ? 0.12 : 0.06)
                        }
                        RoundedImage {
                            id: thumb
                            anchors.fill: parent
                            visible: file.image
                            radius: Kirigami.Units.cornerRadius
                            source: file.image ? file.url : ""
                            sourceSize: Qt.size(Kirigami.Units.gridUnit * 12, Kirigami.Units.gridUnit * 8)
                        }
                        Row {
                            id: fileRow
                            visible: !file.image || thumb.status === Image.Error
                            anchors.verticalCenter: parent.verticalCenter
                            x: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                source: Island.ShelfHelper.iconName(file.url)
                            }
                            PlasmaComponents.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Island.ShelfHelper.fileName(file.url)
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 10)
                            }
                        }
                        HoverHandler {
                            id: fileHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Qt.openUrlExternally(file.url)
                        }
                        PlasmaComponents.ToolTip.text: Island.ShelfHelper.fileName(file.url)
                        PlasmaComponents.ToolTip.visible: fileHover.hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
            }

            // ---- a file transfer -----------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                visible: item.isJob
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    visible: !item.jobDone
                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: item.notif.percentage || 0
                        indeterminate: item.jobRunning && !(item.notif.percentage > 0)
                    }
                    IconButton {
                        visible: item.notif.suspendable === true
                        icon.name: item.jobSuspended ? "media-playback-start" : "media-playback-pause"
                        text: item.jobSuspended ? i18n("Resume") : i18n("Pause")
                        onClicked: item.jobSuspended ? item.notifications.resumeJob(item.idx()) : item.notifications.suspendJob(item.idx())
                    }
                    IconButton {
                        visible: item.notif.killable === true
                        icon.name: "media-playback-stop"
                        text: i18n("Cancel")
                        onClicked: item.notifications.killJob(item.idx())
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: item.jobFailed ? (item.notif.body || i18n("Failed")) : item.jobText
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    color: item.jobFailed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                }
                // Done: open what came, or where it went
                Row {
                    visible: item.jobDone && !item.jobFailed && item.job !== null
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Button {
                        visible: item.urls.length === 1
                        icon.name: "document-open"
                        text: i18n("Open")
                        onClicked: Qt.openUrlExternally(item.urls[0])
                    }
                    PlasmaComponents.Button {
                        visible: !!(item.job && item.job.effectiveDestUrl && String(item.job.effectiveDestUrl) !== "")
                        icon.name: "folder-open"
                        text: i18n("Open Folder")
                        onClicked: Qt.openUrlExternally(item.job.effectiveDestUrl)
                    }
                }
            }

            // ---- actions, and a reply field when the app takes one ---------------------
            Flow {
                Layout.fillWidth: true
                visible: item.actionNames.length > 0 || item.notif.hasReplyAction === true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: item.actionNames.length
                    PlasmaComponents.Button {
                        required property int index
                        text: item.actionLabels[index] || item.actionNames[index]
                        onClicked: item.notifications.invokeAction(item.idx(), item.actionNames[index])
                    }
                }
                PlasmaComponents.Button {
                    visible: item.notif.hasReplyAction === true && !reply.visible
                    icon.name: "mail-reply-sender"
                    text: item.notif.replyActionLabel || i18nc("reply to a notification", "Reply")
                    onClicked: {
                        reply.visible = true;
                        replyField.forceActiveFocus();
                    }
                }
            }
            RowLayout {
                id: reply
                Layout.fillWidth: true
                visible: false
                PlasmaComponents.TextField {
                    id: replyField
                    Layout.fillWidth: true
                    placeholderText: item.notif.replyPlaceholderText || i18n("Type a reply…")
                    onAccepted: send.clicked()
                    Keys.onEscapePressed: reply.visible = false
                }
                PlasmaComponents.Button {
                    id: send
                    icon.name: item.notif.replySubmitButtonIconName || "document-send"
                    text: item.notif.replySubmitButtonText || i18n("Send")
                    enabled: replyField.text.length > 0
                    onClicked: {
                        item.notifications.reply(item.idx(), replyField.text, NotificationManager.Notifications.Close);
                        replyField.text = "";
                        reply.visible = false;
                    }
                }
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            icon.name: "window-close"
            visible: item.notif.closable !== false && !(item.isJob && !item.jobDone)
            text: i18n("Close")
            onClicked: item.notifications.close(item.idx())
        }
    }
}
