# Glance

Everything at a glance, from a vertical Plasma 6 panel: the active window and its menus, what's
playing, your notifications and today's events, the system's load, a focus timer, sit/stand
reminders for a standing desk, and who's using your camera, microphone or screen, in a strip
along the panel and a drawer that slides out of it.

| | |
| --- | --- |
| ![Dashboard](docs/dashboard.png) | ![System](docs/system.png) |
| The dashboard | The system tab |

## What it does

**In the panel.** The active application's name, rotated along the panel; while music plays,
the track and artist with a small equalizer from `cava`. After it, status segments in one
capsule, as macOS shows them in its menu bar:

- **camera** in use (green), **microphone** (orange), **screen sharing** (red), each with a
  tooltip saying who uses it;
- a **focus session** with its time left, also while paused;
- **time to sit down or stand up** (amber), when a switch is due;
- **Do Not Disturb** (grey), with how long it lasts.

A click on the microphone's mutes what's being recorded (whichever microphone each app uses),
on screen sharing's ends it (through the portal's own "End"), on Do Not Disturb's turns it off;
on the focus session's it starts or pauses, on the sit/stand one it switches.
Middle-click plays or pauses, the wheel skips tracks. Which segments show is up to you.

**The drawer.** Hover the strip or click it, and a drawer slides out of the panel beside it,
translucent over a blurred background, rounded where it meets the panel's edge (or floating off
a floating panel). Across its top runs the active window's menu bar, as on macOS: its menus
(global menu) and window buttons. Its tabs:

- **Dashboard:** the time, CPU/memory/disk, what's playing, who you are and what you run, your
  notifications, focus and posture, and the shelf;
- **Media:** the cover inside the spectrum's rays, controls, seek bar, players;
- **Notifications:** the history grouped by app, with actions, replies, thumbnails and file
  transfers; Do Not Disturb for an hour, four hours, until tomorrow…;
- **Agenda:** today's events, from the [Event Calendar NG](https://store.kde.org/p/2379570/) widget;
- **Shelf:** drop files to keep them at hand, drag them out into any app;
- **Focus:** a pomodoro or flowmodoro timer with its stats; a break overlay on every screen,
  Do Not Disturb while you focus, media paused for breaks, sounds and scripts. Locking the
  screen pauses a focus session;
- **Shift:** sit/stand reminders, today against your goal, the week, and a motorized desk
  (idasen by default, any command line tool) that moves by itself if you want;
- **System:** processor, graphics, memory, disk and network.

Focus and Shift are off until turned on in their settings. Together, Shift waits for your focus
breaks: no reminder or desk move in the middle of a session, and a switch that's nearly due is
made at the break. Breaks count as neither sitting nor standing. They take over from the
separate [Fokus](https://gitlab.com/divinae/focus-plasmoid) and
[Shift](https://gitlab.com/divinae/shift-plasmoid) widgets (their settings aren't imported).

The drawer resizes from its corner. Without `layer-shell-qt`, or if you prefer, Glance opens
Plasma's usual popup instead (Settings > Popup > Style).

## Requirements

Plasma 6 (tested on 6.8) with plasma-pa, `layer-shell-qt` for the drawer, PipeWire, and
optionally `cava` for the audio bars.

Build: CMake, extra-cmake-modules, Qt 6 (Quick, DBus, Widgets, Concurrent), KF6 WindowSystem and
Service, libplasma, libpipewire, gettext.

## Build and install

The widget comes with a small QML plugin (`com.dv.glance.private`), so it has to be built:

```sh
sudo pacman -S cava   # optional; the audio bars hide without it
make install          # builds the plugin and installs everything to ~/.local
make restart          # restarts plasmashell
```

Then add **Glance** to a vertical panel. `~/.local/lib/qml` must be on `QML2_IMPORT_PATH` for
plasmashell.

`make package` builds `glance-v<version>.plasmoid` (QML and translations only: the plugin still
has to be installed with `make install`). `make test` runs the tests, `make lint` the QML linter,
`make messages` collects the strings to translate into `po/`.

### Upgrading from 0.x

Up to 0.2 the widget's id was `com.dv.island`. Remove the old widget from the panel, add Glance
again, then `kpackagetool6 -t Plasma/Applet -r com.dv.island` and
`rm -rf ~/.local/lib/qml/com/dv/island`.

## Global menu

While "Application menu" is on, Glance owns the D-Bus name `org.kde.kappmenuview`, like the
stock Global Menu widget: applications that support it export their menus and hide their own
menu bars. Turn the option off to get in-window menu bars back.

`plugin/dbusmenuqt/` is vendored from plasma-workspace, which does not install it.

## License

GPL-2.0-or-later.
