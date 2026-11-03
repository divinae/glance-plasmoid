# Changelog

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
