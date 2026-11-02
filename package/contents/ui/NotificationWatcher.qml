/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    Notification history for the Notifications tab, plus the panel pulse.
    Model setup follows plasma-workspace applets/notifications (history view).
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Item {
    id: watcher

    property bool pulseEnabled: true
    property bool pulseOnJobs: true
    property var ignoredApps: []

    readonly property alias model: historyModel
    readonly property int count: historyModel.count
    readonly property int unreadCount: historyModel.unreadNotificationsCount
    readonly property bool doNotDisturb: {
        const until = settings.notificationsInhibitedUntil;
        return NotificationManager.Server.inhibited
            || (until !== undefined && !isNaN(until) && until > new Date())
            || settings.notificationsInhibitedByApplication;
    }

    signal pulse(color color, string summary)

    // History is "read" up to the moment the popup shows it
    function markRead() {
        historyModel.lastRead = new Date();
    }

    function toggleDoNotDisturb() {
        if (doNotDisturb) {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1); // "until turned off", as the stock applet does
            settings.notificationsInhibitedUntil = d;
        }
        settings.save();
    }

    function clearHistory() {
        historyModel.clear(NotificationManager.Notifications.ClearExpired);
    }

    NotificationManager.Settings {
        id: settings
        live: true
    }

    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: settings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        expandUnread: true
        blacklistedDesktopEntries: settings.historyBlacklistedApplications
        blacklistedNotifyRcNames: settings.historyBlacklistedServices
        urgencies: {
            let u = NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency;
            if (settings.lowPriorityHistory) {
                u |= NotificationManager.Notifications.LowUrgency;
            }
            return u;
        }

        onRowsInserted: (parent, first, last) => watcher.handleInserted(first, last)
    }

    // The model fills with history at startup; only rows added later are "new"
    property bool armed: false
    Timer {
        interval: 3000
        running: true
        onTriggered: watcher.armed = true
    }

    function role(row, r) {
        return historyModel.data(historyModel.index(row, 0), r);
    }

    function handleInserted(first, last) {
        if (!armed || !pulseEnabled || doNotDisturb) {
            return;
        }
        for (let row = first; row <= last; ++row) {
            const type = role(row, NotificationManager.Notifications.TypeRole);
            const isJob = type === NotificationManager.Notifications.JobType;
            if (isJob && !pulseOnJobs) {
                continue;
            }
            const app = role(row, NotificationManager.Notifications.ApplicationNameRole) || "";
            if (ignoredApps.indexOf(app) !== -1) {
                continue;
            }
            const urgency = role(row, NotificationManager.Notifications.UrgencyRole);
            const summary = role(row, NotificationManager.Notifications.SummaryRole) || app;
            let c = Kirigami.Theme.highlightColor;
            if (urgency === NotificationManager.Notifications.CriticalUrgency) {
                c = Kirigami.Theme.negativeTextColor;
            } else if (isJob) {
                c = Kirigami.Theme.positiveTextColor;
            }
            pulse(c, summary);
            return; // one pulse per batch
        }
    }
}
