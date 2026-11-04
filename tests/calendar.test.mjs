import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const C = load("Calendar.js");
const at = (d, h, m = 0) => new Date(2026, 10, 4 + d, h, m).getTime();
const now = at(0, 10);

const bus = (events) => JSON.stringify({ version: 1, events });
const ev = (o) => Object.assign({ id: "x", summary: "Event", start: at(0, 12), end: at(0, 13) }, o);

test("fromBus: shape, meeting flag, links only http(s)", () => {
    const list = C.fromBus(bus([
        ev({ id: "m", summary: "Standup", start: at(0, 10, 10), end: at(0, 10, 25), meetingUrl: "https://meet.google.com/a", response: "accepted", guests: 4 }),
        ev({ id: "d", summary: "Declined", meetingUrl: "https://zoom.us/j/1", response: "declined" }),
        ev({ id: "bad", summary: "Bad link", meetingUrl: "javascript:alert(1)" }),
        ev({ id: "solo", summary: "Focus time" }),
        ev({ id: "allday", summary: "Holiday", allDay: true, start: at(0, 0), end: at(1, 0), guests: 3 }),
    ]));
    const by = Object.fromEntries(list.map((e) => [e.id, e]));
    assert.equal(by.m.meeting, true);
    assert.equal(by.m.start.getTime(), at(0, 10, 10));
    assert.equal(by.d.meeting, false);
    assert.equal(by.bad.meetingUrl, "");
    assert.equal(by.bad.meeting, false);
    assert.equal(by.solo.meeting, false);
    assert.equal(by.allday.meeting, false);
});

test("fromBus: rejects other versions and junk", () => {
    assert.equal(C.fromBus(JSON.stringify({ version: 2, events: [] })), null);
    assert.equal(C.fromBus("{nope"), null);
    assert.equal(C.fromBus(""), null);
});

test("compute: next skips declined; the meeting soon within the lead, or on now", () => {
    const list = C.fromBus(bus([
        ev({ id: "dec", summary: "Declined", start: at(0, 10, 5), end: at(0, 11), response: "declined", guests: 2 }),
        ev({ id: "m", summary: "Review", start: at(0, 10, 12), end: at(0, 11), meetingUrl: "https://meet.google.com/b" }),
        ev({ id: "later", summary: "Later", start: at(0, 15), end: at(0, 16), guests: 1 }),
        ev({ id: "tom", summary: "Tomorrow", start: at(1, 9), end: at(1, 10) }),
    ]));
    let r = C.compute(list, now, 5, 15);
    assert.equal(r.next.id, "m");
    assert.equal(r.meeting.id, "m");
    assert.equal(r.tomorrow.id, "tom");
    assert.ok(r.today.some((e) => e.id === "dec"), "declined still listed today");
    r = C.compute(list, now, 5, 10);
    assert.equal(r.meeting, null, "12 min away with a 10 min lead");
    assert.equal(r.meetingNext.id, "m");
    r = C.compute(list, at(0, 10, 40), 5, 10);
    assert.equal(r.meetingNow.id, "m");
    assert.equal(r.meeting.id, "m", "on now, long after it started");
    assert.equal(r.current, null, "current only within nowMinutes of the start");
});

test("fromCache: Google items, the Meet link and your answer", () => {
    const text = JSON.stringify({ version: 1, calendars: { "acc::primary": [
        { id: "g", summary: "Sync", start: { dateTime: new Date(at(0, 11)).toISOString() }, end: { dateTime: new Date(at(0, 12)).toISOString() },
          hangoutLink: "https://meet.google.com/c", attendees: [{ self: true, responseStatus: "tentative" }, { email: "a@b" }, { resource: true }] },
        { id: "c", summary: "Gone", status: "cancelled", start: { date: "2026-11-04" } },
    ] } });
    const list = C.fromCache(text);
    assert.equal(list.length, 1);
    assert.equal(list[0].meetingUrl, "https://meet.google.com/c");
    assert.equal(list[0].response, "tentative");
    assert.equal(list[0].guests, 1);
    assert.equal(list[0].meeting, true);
});

test("crossings: a start and an end as the clock passes them, not as meetings come and go", () => {
    const list = C.fromBus(bus([
        ev({ id: "a", start: at(0, 10), end: at(0, 10, 30), guests: 2 }),
        ev({ id: "b", start: at(0, 10, 30), end: at(0, 11), guests: 2 }),
        ev({ id: "solo", start: at(0, 10), end: at(0, 11) }),
    ]));
    // Before anything: nothing
    let r = C.crossings(list, {}, 0, at(0, 9, 59));
    assert.equal(r.begun.length, 0);
    // A starts (the solo event isn't a meeting)
    r = C.crossings(list, r.started, at(0, 9, 59), at(0, 10, 0));
    assert.deepEqual(Array.from(r.begun, (e) => e.id), ["a"]);
    // A vanishes (the source changed) and comes back: no end, no second start
    let s = r.started;
    r = C.crossings([], s, at(0, 10, 0), at(0, 10, 5));
    assert.equal(r.ended.length + r.begun.length, 0);
    r = C.crossings(list, r.started, at(0, 10, 5), at(0, 10, 6));
    assert.equal(r.begun.length, 0);
    // Back to back: A ends and B starts in the same tick
    r = C.crossings(list, r.started, at(0, 10, 29), at(0, 10, 30));
    assert.deepEqual(Array.from(r.ended, (e) => e.id), ["a"]);
    assert.deepEqual(Array.from(r.begun, (e) => e.id), ["b"]);
    // B ends while it's gone from the list: still reported
    r = C.crossings([], r.started, at(0, 10, 59), at(0, 11, 0));
    assert.deepEqual(Array.from(r.ended, (e) => e.id), ["b"]);
    // After a suspend over a whole meeting: neither its start nor its end
    r = C.crossings(list, {}, at(0, 9), at(0, 12));
    assert.equal(r.begun.length + r.ended.length, 0);
});

test("crossings: a meeting marked as ended early ends then, even if the news comes a tick late", () => {
    const planned = C.fromBus(bus([ev({ id: "a", start: at(0, 10), end: at(0, 11), guests: 2 })]));
    let r = C.crossings(planned, {}, at(0, 9, 59), at(0, 10, 0));
    assert.deepEqual(Array.from(r.begun, (e) => e.id), ["a"]);
    // Marked as ended at 10:20; Glance hears it at 10:21, after a tick at 10:20:30
    const early = C.fromBus(bus([ev({ id: "a", start: at(0, 10), end: at(0, 10, 20), guests: 2 })]));
    r = C.crossings(early, r.started, at(0, 10, 20) + 30000, at(0, 10, 21));
    assert.deepEqual(Array.from(r.ended, (e) => e.id), ["a"]);
    // Once: not again at its planned end
    r = C.crossings(planned, r.started, at(0, 10, 59), at(0, 11, 0));
    assert.equal(r.ended.length, 0);
});

test("weatherFromBus: the weather Event Calendar sends, or nothing", () => {
    const w = C.weatherFromBus(JSON.stringify({ version: 1, events: [], weather: { temp: 7.6, text: "Clouds", iconName: "weather-clouds", high: 10, low: 3, place: "Warsaw" } }));
    assert.equal(w.temp, 8);
    assert.equal(w.iconName, "weather-clouds");
    assert.equal(C.weatherFromBus(JSON.stringify({ version: 1, events: [] })), null);
    assert.equal(C.weatherFromBus(JSON.stringify({ version: 1, events: [], weather: { text: "?" } })), null);
});
