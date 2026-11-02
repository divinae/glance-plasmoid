/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    Reads the event cache written by the Event Calendar widget
    (~/.cache/plasma-eventcalendar/events.ini, [events] json=...). Read-only:
    Island never talks to Google itself.
*/

import QtQuick
import QtCore

Item {
    id: source

    property bool active: true
    property int leadMinutes: 15
    property int nowMinutes: 5

    readonly property bool available: _events.length > 0 || _loaded
    property var todayEvents: []      // remaining timed + all-day events today, sorted
    property var tomorrowFirst: null  // first timed event tomorrow
    property var nextEvent: null      // next timed event that has not started
    property var currentEvent: null   // timed event that started at most nowMinutes ago
    // Event shown on the panel strip: just started, or starting within leadMinutes
    readonly property var stripEvent: currentEvent ? currentEvent
        : (nextEvent && minutesUntil(nextEvent) <= leadMinutes ? nextEvent : null)

    property var _events: []
    property bool _loaded: false
    property date now: new Date()

    function localPath(url) {
        const p = String(url || "");
        return p.indexOf("file://") === 0 ? decodeURIComponent(p.slice(7)) : p;
    }

    Settings {
        id: cache
        location: "file://" + source.localPath(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation))
            + "/plasma-eventcalendar/events.ini"
        category: "events"
    }

    function minutesUntil(ev): int {
        return Math.round((ev.start.getTime() - now.getTime()) / 60000);
    }

    function label(ev): string {
        if (!ev) {
            return "";
        }
        const m = minutesUntil(ev);
        if (m <= 0) {
            return i18nc("event happening now", "%1 · now", ev.summary);
        }
        if (m < 60) {
            return i18nc("event starts in N minutes", "%1 · %2 min", ev.summary, m);
        }
        return i18nc("event starts at time", "%1 · %2", ev.summary, Qt.formatTime(ev.start, Qt.locale().timeFormat(Locale.ShortFormat)));
    }

    function parseDate(d) {
        if (!d) {
            return null;
        }
        if (d.dateTime) {
            return {date: new Date(d.dateTime), allDay: false};
        }
        if (d.date) {
            const parts = d.date.split("-");
            return {date: new Date(+parts[0], +parts[1] - 1, +parts[2]), allDay: true};
        }
        return null;
    }

    function reload() {
        if (!active) {
            _events = [];
            recompute();
            return;
        }
        cache.sync();
        const text = cache.value("json", "");
        let data = null;
        try {
            data = text ? JSON.parse(text) : null;
        } catch (e) {
            data = null;
        }
        const out = [];
        if (data && data.version === 1 && data.calendars) {
            for (const calId in data.calendars) {
                const items = data.calendars[calId];
                if (!Array.isArray(items)) {
                    continue;
                }
                for (const it of items) {
                    if (!it || it.status === "cancelled" || !it.summary) {
                        continue;
                    }
                    const s = parseDate(it.start);
                    const e = parseDate(it.end);
                    if (!s) {
                        continue;
                    }
                    out.push({
                        summary: it.summary,
                        start: s.date,
                        end: e ? e.date : s.date,
                        allDay: s.allDay,
                        color: it.backgroundColor || "",
                        link: it.htmlLink || "",
                        location: it.location || "",
                    });
                }
            }
        }
        out.sort((a, b) => a.start - b.start);
        _events = out;
        _loaded = data !== null;
        recompute();
    }

    function recompute() {
        now = new Date();
        const t = now.getTime();
        const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const dayEnd = new Date(dayStart.getTime() + 86400000);
        const tomorrowEnd = new Date(dayEnd.getTime() + 86400000);

        const today = [];
        let next = null;
        let current = null;
        let tomorrow = null;
        for (const ev of _events) {
            if (ev.allDay) {
                if (ev.start < dayEnd && ev.end > dayStart) {
                    today.push(ev);
                }
                continue;
            }
            if (ev.start < dayEnd && ev.end.getTime() > t) {
                today.push(ev);
            }
            if (ev.start.getTime() > t && !next) {
                next = ev;
            }
            if (ev.start.getTime() <= t && ev.end.getTime() > t && t - ev.start.getTime() <= nowMinutes * 60000) {
                current = ev;
            }
            if (!tomorrow && ev.start >= dayEnd && ev.start < tomorrowEnd) {
                tomorrow = ev;
            }
        }
        // all-day first, then by start time
        today.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
        todayEvents = today;
        nextEvent = next;
        currentEvent = current;
        tomorrowFirst = tomorrow;
    }

    onActiveChanged: reload()
    Component.onCompleted: Qt.callLater(reload)

    // File refresh is cheap; minute ticks keep countdowns right
    Timer {
        interval: 60000
        repeat: true
        running: source.active
        onTriggered: source.reload()
    }
    Timer {
        interval: 15000
        repeat: true
        running: source.active && source.stripEvent !== null
        onTriggered: source.recompute()
    }
}
