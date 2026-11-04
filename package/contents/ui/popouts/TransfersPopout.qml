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
import "../common"

// The transfers pill's card: each copy or download with its bar; pause or resume, cancel
PopoutCard {
    id: card

    required property var island
    required property Item watcher
    // The pill's colour, for the bars
    property color tint: Kirigami.Theme.highlightColor
    readonly property var jobs: watcher.jobsModel

    cardWidth: Kirigami.Units.gridUnit * 18

    Repeater {
        model: card.jobs
        delegate: ColumnLayout {
            id: job
            required property int index
            required property var model
            readonly property bool suspended: model.jobState === NotificationManager.Notifications.JobStateSuspended
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 2
            // Finished ones stay in the model (dismissed, expired): only those still going
            visible: model.jobState !== NotificationManager.Notifications.JobStateStopped

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: job.model.applicationIconName || "download-symbolic"
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: job.model.summary || job.model.applicationName || i18n("Transfer")
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                }
                PlasmaComponents.Label {
                    text: job.suspended ? i18n("Paused") : i18nc("a transfer's progress", "%1%", Math.max(0, job.model.percentage || 0))
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                }
                // As the notification's own buttons: only what the transfer says it allows
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    visible: job.model.suspendable === true
                    text: job.suspended ? i18n("Resume") : i18n("Pause")
                    icon.name: job.suspended ? "media-playback-start" : "media-playback-pause"
                    onClicked: job.suspended ? card.jobs.resumeJob(card.jobs.index(job.index, 0))
                        : card.jobs.suspendJob(card.jobs.index(job.index, 0))
                }
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    visible: job.model.killable === true
                    text: i18n("Cancel")
                    icon.name: "media-playback-stop"
                    onClicked: card.jobs.killJob(card.jobs.index(job.index, 0))
                }
            }
            ProgressEdge {
                Layout.fillWidth: true
                implicitHeight: 4
                fraction: Math.max(0, Math.min(100, job.model.percentage || 0)) / 100
                color: card.tint
            }
        }
    }
    PillButton {
        text: i18n("Open Notifications")
        icon.name: "notifications-symbolic"
        onClicked: card.island.openOn("notifications", true)
    }
}
