# Changelog

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
