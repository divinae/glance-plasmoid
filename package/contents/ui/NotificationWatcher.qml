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
    // The same history, grouped by application, for the Notifications tab
    readonly property alias groupedModel: groupedModel
    readonly property int count: historyModel.count
    readonly property int unreadCount: historyModel.unreadNotificationsCount
    // Ticks while Do Not Disturb runs, so a timed one ends on time in the UI too
    property date now: new Date()
    Timer {
        interval: 30000
        repeat: true
        running: watcher.doNotDisturb
        onTriggered: watcher.now = new Date()
    }

    readonly property var dndUntil: {
        const until = settings.notificationsInhibitedUntil;
        return until !== undefined && until !== null && !isNaN(until) && until > now ? until : null;
    }
    readonly property bool dndByApplication: settings.notificationsInhibitedByApplication
    readonly property bool doNotDisturb: NotificationManager.Server.inhibited || dndUntil !== null || dndByApplication

    // "Until 14:00", "Until tomorrow, 8:00", "Until turned off", "Requested by an application"
    readonly property string dndText: {
        if (!doNotDisturb) {
            return "";
        }
        if (dndUntil) {
            const u = new Date(dndUntil);
            if (u.getFullYear() > now.getFullYear()) {
                return i18n("Until turned off");
            }
            const time = Qt.formatTime(u, Qt.locale().timeFormat(Locale.ShortFormat));
            const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const day = Math.round((new Date(u.getFullYear(), u.getMonth(), u.getDate()) - today) / 86400000);
            if (day === 0) {
                return i18nc("do not disturb until a time today", "Until %1", time);
            }
            if (day === 1) {
                return i18nc("do not disturb until a time tomorrow", "Until tomorrow, %1", time);
            }
            return i18nc("do not disturb until a day and time", "Until %1, %2",
                u.toLocaleDateString(Qt.locale(), "dddd"), time);
        }
        if (dndByApplication) {
            return i18n("Requested by an application");
        }
        return i18n("On");
    }

    // The durations offered when turning it on, as the stock applet does
    function dndChoices() {
        const n = new Date();
        const out = [
            {label: i18n("For 1 hour"), until: new Date(n.getTime() + 3600000)},
            {label: i18n("For 4 hours"), until: new Date(n.getTime() + 4 * 3600000)},
        ];
        if (n.getHours() < 17) {
            out.push({label: i18n("Until this evening"), until: new Date(n.getFullYear(), n.getMonth(), n.getDate(), 18)});
        }
        out.push({label: i18n("Until tomorrow morning"), until: new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1, 8)});
        const forever = new Date(n);
        forever.setFullYear(forever.getFullYear() + 1); // "until turned off", as the stock applet stores it
        out.push({label: i18n("Until turned off"), until: forever});
        return out;
    }

    function setDoNotDisturbUntil(until) {
        settings.notificationsInhibitedUntil = until;
        settings.save();
        now = new Date();
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
            settings.save();
            now = new Date();
        } else {
            const choices = dndChoices();
            setDoNotDisturbUntil(choices[choices.length - 1].until);
        }
    }

    // Everything goes: the expired ones, and those not timed out yet, except running file
    // transfers and the ones that can't be closed
    function clearHistory() {
        historyModel.clear(NotificationManager.Notifications.ClearExpired);
        for (let row = historyModel.count - 1; row >= 0; --row) {
            const idx = historyModel.index(row, 0);
            const isJob = historyModel.data(idx, NotificationManager.Notifications.TypeRole) === NotificationManager.Notifications.JobType;
            const running = isJob && historyModel.data(idx, NotificationManager.Notifications.JobStateRole) !== NotificationManager.Notifications.JobStateStopped;
            if (!running && historyModel.data(idx, NotificationManager.Notifications.ClosableRole) !== false) {
                historyModel.close(idx);
            }
        }
    }

    NotificationManager.Settings {
        id: settings
        live: true
    }

    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        // Neither is on by default: no notifications at all without the first, none from while
        // Do Not Disturb was on without the second
        showNotifications: true
        showAddedDuringInhibition: true
        ignoreBlacklistDuringInhibition: true
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

    NotificationManager.Notifications {
        id: groupedModel
        showExpired: true
        showDismissed: true
        // Neither is on by default: no notifications at all without the first, none from while
        // Do Not Disturb was on without the second
        showNotifications: true
        showAddedDuringInhibition: true
        ignoreBlacklistDuringInhibition: true
        showJobs: settings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        expandUnread: true
        blacklistedDesktopEntries: settings.historyBlacklistedApplications
        blacklistedNotifyRcNames: settings.historyBlacklistedServices
        urgencies: historyModel.urgencies
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
