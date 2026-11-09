# KDE Store listing

The page: https://store.kde.org/p/2381246/

Text and files for the [KDE Store](https://store.kde.org) page, ready to paste. Update the
version, the changelog and the file for each release.

## Before uploading

- **Glance needs its compiled plugin.** The `.plasmoid` from `make package` holds the QML and the
  translations only, not the `com.dv.glance.private` plugin (C++). Installed by itself from "Get
  New Widgets", the widget fails to load. So the store's file is the source archive of the
  release, and the page says first that it's built from source, with the three commands.
- **Screenshots** are made with made-up data by `tools/screenshots.sh` (see its header), then
  cropped: the tabs to the drawer (900×635 from 0,125 of the captured area), the cards to the
  strip and the card (420×520 from 0,240). They're in `docs/screenshots/`.
- **The file:** GitHub makes the archive with each tag:
  `https://github.com/divinae/glance-plasmoid/archive/refs/tags/v<version>.tar.gz`. Upload
  that `.tar.gz` (or link it, as the store allows).

## Fields

**Title**

    Glance

**Category**

    Plasma 6 Extensions > Plasma 6 Widgets

**Version**

    1.8.0

**License**

    GPL-2.0-or-later

**Tags**

    panel, vertical panel, global menu, media, notifications, calendar, pomodoro, focus, standing desk, bluetooth, plasma6

**Donation link**

    https://ko-fi.com/divinae4535

**Source / homepage**

    https://github.com/divinae/glance-plasmoid

**Logo**

    docs/store/logo.png (256×256; the source is logo.svg)

**Summary (one line)**

    Everything at a glance from a vertical panel: the window's menus, music, notifications, meetings, controls and a focus timer, in a drawer that slides out of the panel.

**Description** (each line its own paragraph: the store joins lines that have only a single line break between them)

```
Everything at a glance from a vertical Plasma 6 panel: the active window and its menus, what's playing, your notifications and today's meetings, quick controls, the system's load, a focus timer and sit/stand reminders. In a strip along the panel, status pills as macOS shows them in its menu bar, and a drawer that slides out of the panel.

⚠ Built from source: Glance comes with a small QML plugin, so the file here is the source. Unpack it, run "make install" (CMake, Qt 6 and KDE Frameworks 6 development packages needed), let Plasma find the plugin with a one-line setting, log out and back in, and add Glance to a vertical panel. The steps and the packages: https://github.com/divinae/glance-plasmoid#install

THE STRIP

One thing at a time: a notification, a meeting coming up ("Standup in 5 min"), the time to stand up, what's playing, the next event, or the active window's name.

Status pills after it, only those that apply: music (bars to the beat in the album's colour), camera, microphone and screen sharing in use, file transfers, the focus timer, the meeting on now with its time left, sit/stand, unread notifications, Do Not Disturb, a device's battery running low.

Hover a pill for its card: the track with seek and volume, the meeting with Join, the transfers with Pause and Cancel, the latest notifications.

THE DRAWER

The window's menu bar, as on macOS: the app's menus (the global menu), search across them in a few letters, its About, Settings and Quit, Alt+letter, the window's buttons.

Dashboard: the time and weather, today's meetings with Join, controls, the system's load, notifications, music over its blurred cover, focus and posture.

Media: the cover in the spectrum's rays, the controls in a colour from the cover, seek, volume, shuffle, repeat, the player.

Notifications: the history grouped by app, with actions, replies and file transfers; Do Not Disturb for an hour, until tomorrow…

Controls: Wi-Fi, Do Not Disturb, keep awake, the microphone, the power profile; each screen's brightness, the keyboard's light, the appearance (light, dark or automatic) and Night Light; where sound goes; Bluetooth with its devices and pairing; the batteries of mice and keyboards on a USB receiver.

Work: a pomodoro or flowmodoro timer with a break overlay, and sit/stand reminders for a motorized standing desk (idasen or any command line tool). Breaks wait for the end of a meeting.

System: processor, graphics, memory, disk and network.

MEETINGS

With Event Calendar NG (1.21 or later) and "Share events with Glance" on there: meeting links, a pill while it's on, the screen kept awake, the desk standing you up.

Requirements: Plasma 6 with plasma-pa and layer-shell-qt; optionally cava for the audio bars, Event Calendar NG for events, plasma-nm, bluedevil and power-profiles-daemon for their controls.

Source and the full README: https://github.com/divinae/glance-plasmoid

Bugs and ideas: https://github.com/divinae/glance-plasmoid/issues

Support: https://ko-fi.com/divinae4535
```

**Changelog** (the store's field, for this version)

```
1.8.0

Light, dark or automatic (Plasma's own switching at sunrise and sunset), on the Controls tab and the dashboard.

Shift: "Not on weekends", with or without the working hours.

The tabs in a new order: Controls and Notifications next to the dashboard, Focus and Shift last.

Bluetooth shows a spinner while connecting and disconnecting. A dashboard toggle no longer opens the Controls tab.

1.7.1

A pill's card stays open while what the pill shows changes (the music's position, a meeting's minutes).

1.7.0

The Controls tab: Wi-Fi, Do Not Disturb, keep awake, the microphone and the power profile; the screens' brightness, the keyboard's light, dark mode and Night Light; where sound goes; Bluetooth with its devices and pairing; the batteries on a USB receiver.

The dashboard: a Controls card; music only with a player.

Music as a pill of its own: bars in the album's colour; its card with seek and volume.

Simpler settings, saner defaults. A crash fixed.
```

**Screenshots** (in this order; the first is the page's main image)

1. `docs/screenshots/dashboard.png`: the dashboard
2. `docs/screenshots/tour.gif`: the tour (the cards, then the tabs)
3. `docs/screenshots/card-media.png`: the music pill's card
4. `docs/screenshots/controls.png`: the Controls tab
5. `docs/screenshots/card-meeting.png`: a meeting's card, Join on it
6. `docs/screenshots/media.png`: the Media tab
7. `docs/screenshots/notifications.png`: notifications
8. `docs/screenshots/work.png`: focus and the standing desk
9. `docs/screenshots/system.png`: the system tab
10. `docs/screenshots/card-unread.png`: unread notifications
