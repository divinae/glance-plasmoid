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

    // The weather Event Calendar shows (over D-Bus only): { temp, text, iconName, high, low, place }
    property var weather: null
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
    // Minutes to its end, for one on now
    function minutesLeft(ev): int {
        return Math.max(0, Math.ceil((ev.end.getTime() - now.getTime()) / 60000));
    }

    // "14:00 – 15:30", or "All day"
    function timeRange(ev): string {
        if (!ev) {
            return "";
        }
        if (ev.allDay) {
            return i18n("All day");
        }
        const f = Qt.locale().timeFormat(Locale.ShortFormat);
        return Qt.formatTime(ev.start, f) + " – " + Qt.formatTime(ev.end, f);
    }

    // "Standup in 5 min"; `shorten` cuts the name only, so the time always shows
    function label(ev, shorten): string {
        if (!ev) {
            return "";
        }
        const name = shorten ? shorten(ev.summary) : ev.summary;
        const m = minutesUntil(ev);
        if (m <= 0) {
            return i18nc("event happening now", "%1 now", name);
        }
        if (m < 60) {
            return i18nc("event starts in N minutes", "%1 in %2 min", name, m);
        }
        return i18nc("event starts at time", "%1 at %2", name, Qt.formatTime(ev.start, Qt.locale().timeFormat(Locale.ShortFormat)));
    }

    // Opens a meeting's link (only http(s), only on a click)
    function join(ev) {
        if (ev && ev.meetingUrl) {
            Qt.openUrlExternally(ev.meetingUrl);
        }
    }

    // The widget (Plasmoid), to find Event Calendar in the same shell and ask it to send
    property var applet: null
    // Asks Event Calendar to send its events now, at most once a minute (a later ask waits for
    // the minute to pass, not dropped): a few seconds after start (it may have sent before Glance
    // was there), and while it has sent an empty list then (below)
    property real _askedMs: 0
    function askEventCalendar() {
        if (!applet) {
            return;
        }
        const wait = _askedMs + 60000 - Date.now();
        if (wait > 0) {
            askAgain.interval = wait;
            askAgain.restart();
            return;
        }
        _askedMs = Date.now();
        Island.CalendarBus.requestPublish(applet);
    }
    Timer {
        interval: 5000
        running: source.active && source.applet !== null
        onTriggered: source.askEventCalendar()
    }
    Timer {
        id: askAgain
        onTriggered: source.askEventCalendar()
    }
    // Event Calendar before 1.21 sent an empty list at every start, before its events loaded. Until
    // the bus has brought real events once, within the first minutes, an empty list is taken for
    // that and the cache shown instead; after, an empty list means nothing's there
    readonly property real _startMs: Date.now()
    property bool _busHadEvents: false

    function reload() {
        if (!active) {
            _events = [];
            origin = "";
            recompute();
            return;
        }
        // Screenshots: a made-up day instead of Event Calendar's
        if (Island.SystemInfo.demo) {
            const demo = Calendar.demoJson(Date.now());
            weather = Calendar.weatherFromBus(demo);
            _events = Calendar.fromBus(demo);
            origin = "bus";
            recompute();
            return;
        }
        let events = null;
        weather = Island.CalendarBus.connected ? Calendar.weatherFromBus(Island.CalendarBus.eventsJson) : null;
        if (Island.CalendarBus.connected) {
            events = Calendar.fromBus(Island.CalendarBus.eventsJson);
            if (events !== null) {
                origin = "bus";
                _busHadEvents = _busHadEvents || events.length > 0;
            }
        }
        const earlyEmpty = events !== null && events.length === 0 && !_busHadEvents
            && Date.now() - _startMs < 10 * 60000;
        if (events === null || earlyEmpty) {
            const cached = Calendar.fromCache(Island.CalendarBus.readCacheFile());
            if (events === null || (cached && cached.length > 0)) {
                events = cached;
                origin = cached !== null ? "file" : "";
            }
            if (earlyEmpty) {
                askEventCalendar();
            }
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
