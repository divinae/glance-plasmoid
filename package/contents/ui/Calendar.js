.pragma library

// Glance's events, from either source, as one shape:
// { id, summary, start: Date, end: Date, allDay, color, location, calendar, calendarId,
//   meetingUrl, meetingLabel, response, guests, busy, meeting }
// `meeting`: timed, with a link or guests, and not declined: what the panel and Focus/Shift
// treat as a meeting.

function isHttp(url) {
    return /^https?:\/\//i.test(String(url || ""));
}

function finish(ev) {
    ev.meetingUrl = isHttp(ev.meetingUrl) ? ev.meetingUrl : "";
    ev.meeting = !ev.allDay && ev.response !== "declined" && (ev.meetingUrl !== "" || ev.guests > 0);
    return ev;
}

// Event Calendar's D-Bus payload: {"version": 1, "events": [{ id, summary, start (ms), ... }]}
function fromBus(text) {
    let data = null;
    try {
        data = text ? JSON.parse(text) : null;
    } catch (e) {
        return null;
    }
    if (!data || data.version !== 1 || !Array.isArray(data.events)) {
        return null;
    }
    const out = [];
    for (const it of data.events) {
        if (!it || !it.summary || typeof it.start !== "number") {
            continue;
        }
        out.push(finish({
            id: String(it.id || ""),
            summary: String(it.summary),
            start: new Date(it.start),
            end: new Date(typeof it.end === "number" && it.end >= it.start ? it.end : it.start),
            allDay: !!it.allDay,
            color: String(it.color || ""),
            location: String(it.location || ""),
            calendar: String(it.calendar || ""),
            calendarId: String(it.calendarId || ""),
            meetingUrl: String(it.meetingUrl || ""),
            meetingLabel: String(it.meetingLabel || ""),
            response: String(it.response || ""),
            guests: it.guests | 0,
            busy: it.busy !== false,
        }));
    }
    return out.sort((a, b) => a.start - b.start);
}

function parseDate(d) {
    if (!d) {
        return null;
    }
    if (d.dateTime) {
        return { date: new Date(d.dateTime), allDay: false };
    }
    if (d.date) {
        const parts = String(d.date).split("-");
        return { date: new Date(+parts[0], +parts[1] - 1, +parts[2]), allDay: true };
    }
    return null;
}

// A Google item's meeting link, as Event Calendar finds one: Meet, then a video entry point
function googleMeeting(it) {
    if (isHttp(it.hangoutLink)) {
        return { url: it.hangoutLink, label: "Google Meet" };
    }
    const points = it.conferenceData && Array.isArray(it.conferenceData.entryPoints) ? it.conferenceData.entryPoints : [];
    for (const p of points) {
        if (p && p.entryPointType === "video" && isHttp(p.uri)) {
            const name = it.conferenceData.conferenceSolution && it.conferenceData.conferenceSolution.name;
            return { url: p.uri, label: name || "" };
        }
    }
    return { url: "", label: "" };
}

// The fallback: Event Calendar's own cache (Google calendars only):
// {"version": 1, "calendars": {"<account>::<id>": [google items]}}
function fromCache(text) {
    let data = null;
    try {
        data = text ? JSON.parse(text) : null;
    } catch (e) {
        return null;
    }
    if (!data || data.version !== 1 || !data.calendars) {
        return null;
    }
    const out = [];
    for (const calId in data.calendars) {
        const items = data.calendars[calId];
        if (!Array.isArray(items)) {
            continue;
        }
        for (const it of items) {
            if (!it || it.status === "cancelled" || !it.summary || it.kind === "tasks#task") {
                continue;
            }
            const s = parseDate(it.start);
            const e = parseDate(it.end);
            if (!s) {
                continue;
            }
            let response = "";
            let guests = 0;
            for (const a of Array.isArray(it.attendees) ? it.attendees : []) {
                if (a && a.self) {
                    response = a.organizer ? "" : String(a.responseStatus || "");
                } else if (a && !a.resource) {
                    guests++;
                }
            }
            const m = googleMeeting(it);
            out.push(finish({
                id: String(it.id || ""),
                summary: String(it.summary),
                start: s.date,
                end: e ? e.date : s.date,
                allDay: s.allDay,
                color: String(it.backgroundColor || ""),
                    location: String(it.location || ""),
                calendar: "",
                calendarId: calId,
                meetingUrl: m.url,
                meetingLabel: m.label,
                response: response,
                guests: guests,
                busy: it.transparency !== "transparent",
            }));
        }
    }
    return out.sort((a, b) => a.start - b.start);
}

// What the panel and the tabs want at `now` (ms):
// today: today's events still to come or on (all-day first), declined included (shown dimmed)
// next: the next timed event not declined; current: a timed event, not declined, that started at
// most nowMinutes ago; tomorrow: tomorrow's first timed event;
// meeting: the meeting on now, else the next one within leadMinutes (panel strip and pill)
function compute(events, nowMs, nowMinutes, leadMinutes) {
    const now = new Date(nowMs);
    const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const dayEnd = new Date(dayStart.getFullYear(), dayStart.getMonth(), dayStart.getDate() + 1);
    const tomorrowEnd = new Date(dayStart.getFullYear(), dayStart.getMonth(), dayStart.getDate() + 2);
    const today = [];
    let next = null;
    let current = null;
    let tomorrow = null;
    let meetingNow = null;
    let meetingNext = null;
    for (const ev of events) {
        if (ev.allDay) {
            if (ev.start < dayEnd && ev.end > dayStart) {
                today.push(ev);
            }
            continue;
        }
        const s = ev.start.getTime();
        const e = ev.end.getTime();
        if (ev.start < dayEnd && e > nowMs) {
            today.push(ev);
        }
        if (ev.response === "declined") {
            continue;
        }
        if (s > nowMs && !next) {
            next = ev;
        }
        if (s <= nowMs && e > nowMs && nowMs - s <= nowMinutes * 60000) {
            current = ev;
        }
        if (!tomorrow && ev.start >= dayEnd && ev.start < tomorrowEnd) {
            tomorrow = ev;
        }
        if (ev.meeting) {
            if (s <= nowMs && e > nowMs) {
                meetingNow = meetingNow || ev;
            } else if (s > nowMs && !meetingNext) {
                meetingNext = ev;
            }
        }
    }
    today.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
    const soon = meetingNext && (meetingNext.start.getTime() - nowMs) <= leadMinutes * 60000 ? meetingNext : null;
    return {
        today: today,
        next: next,
        current: current,
        tomorrow: tomorrow,
        meetingNow: meetingNow,
        meetingNext: meetingNext,
        meeting: meetingNow || soon,
    };
}

// Meetings whose start or end the clock passed between prevMs and nowMs (each only within
// 2 minutes of it, so a suspend doesn't fire old ones). started: { id: end ms } of the meetings
// started so far; an end is reported only for those, present in `events` or not (it may have
// vanished when the events' source changed). An end that moved earlier (Event Calendar's "Mark as
// Ended") counts as soon as it's seen, even if the clock passed it a moment before the news came.
// Returns { started, begun: [events], ended: [{id, end}] }.
function crossings(events, started, prevMs, nowMs) {
    const out = Object.assign({}, started);
    const begun = [];
    const ended = [];
    if (prevMs <= 0 || nowMs <= prevMs) {
        return { started: out, begun: begun, ended: ended };
    }
    const window = 2 * 60000;
    for (const id in started) {
        let end = started[id];
        const ev = events.find(e => e.id === id);
        const earlier = !!ev && ev.end.getTime() < end;
        if (earlier) {
            end = ev.end.getTime();
            out[id] = end;
        }
        if ((end > prevMs || earlier) && end <= nowMs && nowMs - end < window) {
            ended.push({ id: id, end: new Date(end) });
        }
        if (end <= nowMs) {
            delete out[id];
        }
    }
    for (const ev of events) {
        const s = ev.start.getTime();
        if (ev.meeting && ev.id && !(ev.id in out) && s > prevMs && s <= nowMs && nowMs - s < window) {
            out[ev.id] = ev.end.getTime();
            begun.push(ev);
        }
    }
    return { started: out, begun: begun, ended: ended };
}

// The weather Event Calendar sends along (its "weather"): { temp, text, iconName, high, low,
// place, units }, temperatures rounded or null; null when it sends none
function weatherFromBus(text) {
    let data = null;
    try {
        data = text ? JSON.parse(text) : null;
    } catch (e) {
        return null;
    }
    const w = data && data.version === 1 ? data.weather : null;
    if (!w || typeof w !== "object") {
        return null;
    }
    const num = (v) => typeof v === "number" && isFinite(v) ? Math.round(v) : null;
    const out = {
        temp: num(w.temp),
        text: String(w.text || ""),
        iconName: String(w.iconName || ""),
        high: num(w.high),
        low: num(w.low),
        place: String(w.place || ""),
    };
    return out.temp === null && out.high === null ? null : out;
}
