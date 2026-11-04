/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    The events of the Event Calendar widget. Over D-Bus, as it publishes them (every calendar,
    with meeting links and your answer: Island.CalendarBus); without that (an older Event
    Calendar) from its per-widget cache file, Google calendars only. Read-only: Glance never
    talks to a calendar itself.
*/

import QtQuick

import com.dv.glance.private as Island

import "Calendar.js" as Calendar

Item {
    id: source

    property bool active: true
    property int leadMinutes: 15
    property int nowMinutes: 5

    // Where the events come from now: "bus", "file" or ""
    property string origin: ""
    readonly property bool available: _events.length > 0 || origin !== ""
    property var todayEvents: []      // remaining timed + all-day events today, sorted
    property var tomorrowFirst: null  // first timed event tomorrow
    property var nextEvent: null      // next timed event that has not started (not declined)
    property var currentEvent: null   // timed event that started at most nowMinutes ago
    property var meetingNow: null     // the meeting on now
    property var meetingNext: null    // the next meeting, however far
    // The meeting for the panel: on now, or starting within leadMinutes
    property var meeting: null
    // Event shown on the panel strip: just started, or starting within leadMinutes
    readonly property var stripEvent: currentEvent ? currentEvent
        : (nextEvent && minutesUntil(nextEvent) <= leadMinutes ? nextEvent : null)

    // A meeting's real start and end, seen as the clock passes them (not when a meeting merely
    // appears or vanishes: the events' source can change, Plasma can restart). Only within
    // 2 minutes of the moment, so a suspend or a long gap doesn't fire old ones; an end only for
    // a meeting whose start was acted on, even if it has vanished since.
    signal meetingStarted(var ev)
    signal meetingEnded(var ev)
    property real _prevNowMs: 0
    property var _started: ({}) // id → end (ms) of the meetings started

    property var _events: []
    property date now: new Date()

    // Whole minutes left, rounded up: "now" only once it has started
    function minutesUntil(ev): int {
        return Math.ceil((ev.start.getTime() - now.getTime()) / 60000);
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

    // Opens a meeting's link (only http(s), only on a click)
    function join(ev) {
        if (ev && ev.meetingUrl) {
            Qt.openUrlExternally(ev.meetingUrl);
        }
    }

    function reload() {
        if (!active) {
            _events = [];
            origin = "";
            recompute();
            return;
        }
        let events = null;
        if (Island.CalendarBus.connected) {
            events = Calendar.fromBus(Island.CalendarBus.eventsJson);
            if (events !== null) {
                origin = "bus";
            }
        }
        if (events === null) {
            events = Calendar.fromCache(Island.CalendarBus.readCacheFile());
            origin = events !== null ? "file" : "";
        }
        _events = events || [];
        recompute();
    }

    function recompute() {
        now = new Date();
        const r = Calendar.compute(_events, now.getTime(), nowMinutes, leadMinutes);
        todayEvents = r.today;
        nextEvent = r.next;
        currentEvent = r.current;
        tomorrowFirst = r.tomorrow;
        meetingNow = r.meetingNow;
        meetingNext = r.meetingNext;
        meeting = r.meeting;
        crossings(now.getTime());
    }

    function crossings(nowMs) {
        const r = Calendar.crossings(_events, _started, _prevNowMs, nowMs);
        _prevNowMs = nowMs;
        _started = r.started;
        // Ends first: back to back, the next one starts as the last one ends
        for (const ev of r.ended) {
            meetingEnded(ev);
        }
        for (const ev of r.begun) {
            meetingStarted(ev);
        }
    }

    onActiveChanged: reload()
    onLeadMinutesChanged: recompute()
    Component.onCompleted: Qt.callLater(reload)

    Connections {
        target: Island.CalendarBus
        function onChanged() { source.reload(); }
        function onConnectedChanged() { source.reload(); }
    }

    // Without the bus, the file is read every minute; with it, the minute only moves the clock
    Timer {
        interval: 60000
        repeat: true
        running: source.active
        onTriggered: source.origin === "bus" ? source.recompute() : source.reload()
    }
    // Countdowns in the panel stay right to the minute
    Timer {
        interval: 15000
        repeat: true
        running: source.active && (source.stripEvent !== null || source.meeting !== null)
        onTriggered: source.recompute()
    }
}
