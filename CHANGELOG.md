# Changelog

## 1.3.0 — 2026-11-04

**Music.** The cover, blurred, behind the Media tab and lighter behind the dashboard's card; the
controls take a colour from it. The last cover stays until the next has loaded, then they
crossfade (no more placeholder flashing between tracks). Scroll on the cover for the volume
(with Plasma's volume display), on the seek bar for 5 s on or back. Keys in the Media tab, as
Plasma's own player: Space or K, P and N, J and L (or the arrows), Home and End, 0–9. A tap on
the track's length shows the time left. A browser's empty player is "nothing playing", not a
player called Vivaldi; with more than one player, "Choose a player". Shuffle works (it never
did), the player menu doesn't list one twice, and the player chip shows only when there is a
choice or a name to add.

**Panel.** Unread notifications: a bell pill in place of the dot. A meeting on now: its pill
shows the time left ("20 min"; the end in its tooltip), and a click opens it in Event Calendar
(it joins when there's none). Focus: its pill is Fokus's wedge emptying as the session runs (the
stopwatch during a flow or a break past its end). The pills sit evenly in the capsule's
rounded end.

**Drawer.** One button style across the cards: rounded and tinted, the main or chosen one in
the accent (Start, Sit | Stand, the player, the period). Focus | Posture are tabs. A click on
the window's icon in the menu bar opens KWin's window menu (as Alt+F3). Picking from a menu in
the drawer (the player, the period, Shift's pause, Do Not Disturb) no longer closes it.

**Focus.** "Start the timer when Plasma starts" means after a reboot: a Plasma restart leaves a
timer you stopped stopped.

**Also:** no bell twice on the dashboard's notifications card.

## 1.2.0 — 2026-11-04

Glance and [Event Calendar NG](https://github.com/divinae/plasma-applet-eventcalendar) work
together: with "Share events with Glance" on in Event Calendar (Calendars), it sends today's
and tomorrow's events, from every calendar, with meeting links and your response, over D-Bus
whenever they change. Only widgets in Plasma itself can send them. Without it, Glance reads
Event Calendar's cache file (Google calendars only) as before, which works again with Event
Calendar 1.18's per-widget files.

**Meetings in the panel.** Before a meeting, its name takes the panel text: "Standup in
5 min", with a calendar in the event's colour. While it's on, a pill with a camera in its place
(a click joins). "Join" is in the right-click menu too.

**Focus and Shift know meetings.** Focus warns of a meeting coming up, pauses at its start (a
flow too) and offers to resume after. Shift holds its reminders and the desk during a meeting
and makes a switch that came due at its end; it can stand you up for meetings (off by default).

**Dashboard.** Always there, and the first tab. Today's events under the clock, one slim row
each (declined struck through, tentative in italics, a camera to join); a click opens that
event in Event Calendar. The weather, from Event Calendar, small at the time's right. Icons are
symbolic and match the theme; the media card's spectrum circles the cover, as on the Media tab.

**Shift's reminder** offers Snooze, and Done (or Move the desk, with one) to record the switch.

**Gone:** the Agenda and Window tabs (the dashboard and the menu bar on top have both);
Glance's notifications stay out of the history.

## 1.1.1 — 2026-11-03

**One Work tab.** With Focus and Shift both on, they share a tab: the timer on the left, a
compact Shift card (where you are, the time to the switch as a line, Sit | Stand, the desk in a
line) and one stats card that switches between Focus and Posture.

**Dashboard.** The Focus and Shift rows look alike: a badge, one line of text, a progress line
and a button ("Sit in 11 min"; an empty line during a flow).

**Fixed:** a tab asked for while the drawer was closed (a dashboard row, the shelf after a
drop) fell back to the dashboard on opening.

**Also:** the Polish translation is gone for now (`make messages` still collects the strings);
the code shared by Focus and Shift lives once in `ui/common`.

## 1.1.0 — 2026-11-03

Glance takes in two widgets of its own: Fokus and Shift.

**Focus.** Fokus's pomodoro and flowmodoro timer as a Focus tab: the timer and its stats side by
side, the break overlay on every screen, Do Not Disturb while you focus, media paused for breaks,
sounds, notifications and scripts. In the panel, a pill with the time left beside the window's
title (a click starts or pauses); on the dashboard, a row with a button; in the right-click menu,
Start, Skip to Break, Stop and Flowmodoro. Locking the screen pauses a focus session and
unlocking resumes it. Its settings are one page.

**Shift.** Shift's sit/stand reminders as a Shift tab: where you are and what's next, today
against your goal, the week, and the desk with its height on a scale. When a switch is due, an
amber pill in the panel (a click switches) and an amber edge on the dashboard's card; Sit Down /
Stand Up in the right-click menu and on the dashboard. A motorized desk (idasen by default)
can move by itself. Its settings, desk included, are one page.

**Together.** Shift waits for focus breaks: no reminder or desk move in the middle of a
session, and a switch due within 10 minutes is made at the break. Breaks count as neither
sitting nor standing ("Switch at focus breaks", on by default).

**Dashboard.** The clock and who-and-what share one tall card; focus and posture share another,
which leaves the notifications room for their header.

**Also:** the right-click menu drops its "Open …" entries; the Polish translation covers the new
pages. Fokus's and Shift's own settings and history aren't imported: Focus and Shift start fresh
and are off until turned on.

## 1.0.0 — 2026-11-03

The widget is Glance now, through and through: its id is `com.dv.glance` (see the README for
upgrading from 0.x).

**A drawer instead of a popup.** It slides out of the panel beside the strip, translucent over a
blurred background, rounded into the panel's edge or floating off a floating panel, and resizes
from its corner. The active window's menu bar runs across its top, as on macOS.

**Tabs.** A dashboard (time, CPU/memory/disk, what's playing, who and what you run,
notifications, shelf); Media with the cover in the spectrum's rays; Notifications grouped by app,
with actions, replies, thumbnails, file transfers and Do Not Disturb for a while; Agenda from
Event Calendar; the Shelf; and a System tab of gauges for processor, graphics, memory, disk and
network.

**Status in the panel.** Camera, microphone, screen sharing and Do Not Disturb as segments of
one capsule after the title, each with who's using it. A click mutes what's being recorded,
ends screen sharing or turns Do Not Disturb off. Detected from PipeWire directly, so a screen
shared through KWin and cameras opened past PipeWire count too.

**The panel strip.** No capsule, icon or progress line unless you want them; a small equalizer,
or bars along the panel's edge, while music plays; a soft highlight while the drawer is open.

**Also:** a right-click menu (Do Not Disturb, clear notifications, media, open a tab), a Polish
translation, tests (`make test`) and a `.plasmoid` package (`make package`).

## 0.2.0

The first version: the active window's name, global menu, window buttons and media in one
island, with a popup of tabs.
