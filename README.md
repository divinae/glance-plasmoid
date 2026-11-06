# Glance

Everything at a glance, from a vertical Plasma 6 panel: the active window and its menus, what's
playing, your notifications and today's events, the system's load, a focus timer, sit/stand
reminders for a standing desk, and who's using your camera, microphone or screen, in a strip
along the panel and a drawer that slides out of it.

![The tour: the pills' cards, then the drawer's tabs](docs/screenshots/tour.gif)

| | |
| --- | --- |
| ![Dashboard](docs/screenshots/dashboard.png) | ![Controls](docs/screenshots/controls.png) |
| The dashboard | The Controls tab |
| ![Media](docs/screenshots/media.png) | ![Notifications](docs/screenshots/notifications.png) |
| The Media tab | Notifications |
| ![Focus and the desk](docs/screenshots/work.png) | ![System](docs/screenshots/system.png) |
| Focus and the standing desk | The System tab |

| | | |
| --- | --- | --- |
| ![Music](docs/screenshots/card-media.png) | ![Meeting](docs/screenshots/card-meeting.png) | ![Unread](docs/screenshots/card-unread.png) |
| The music pill's card | A meeting on now | Unread notifications |

## What it does

### In the panel

The strip shows one thing at a time, the first that applies:

1. a notice (a notification's summary, briefly);
2. the desk moving ("Moving the desk to standing…", or "Connecting to the desk… (try 3)");
3. time to sit down or stand up;
4. a meeting coming up: "Standup in 5 min";
5. what's playing, with a small equalizer from `cava`;
6. the next event, shortly before it;
7. the active window's name.

After it, status pills in one capsule, as macOS shows them in its menu bar. Only those that apply
show, and which may show at all is up to you:

| Pill | Shows | A click |
| --- | --- | --- |
| Music (the album's colour) | thin bars to the music; paused: resting bars and a pause badge | plays or pauses |
| Camera (green) | it's in use, and by whom | — |
| Microphone (orange) | it's in use | mutes what's being recorded |
| Screen sharing (red) | it's shared | ends it (through the portal) |
| File transfers (blue) | a wedge filling up, "42%" | opens the notifications |
| Focus | a wedge emptying, the time left; paused: the wedge or a stopwatch with a pause badge | starts or pauses |
| Meeting on now | the time left in it, "20 min" | opens it in Event Calendar (joins without it) |
| Sit/stand (amber) | a switch is due | switches |
| Unread (purple) | notifications you haven't seen | opens them |
| Do Not Disturb (grey) | how long it lasts | turns it off |

**Hover cards.** Hover the music pill for the track, the seek and volume sliders and the
controls. Hover the Focus, meeting, transfers, sit/stand or unread pill and a card opens
beside it, without the drawer: what's left and today's total with Start, Pause, Skip and Stop;
the meeting's times and guests with Join and Details; each transfer with Pause and Cancel;
Move the desk (or Done) and Snooze; the latest notifications with Open and Clear All.

Middle-click on the strip plays or pauses, the wheel skips tracks.

### The drawer

Hover the strip or click it, and a drawer slides out of the panel beside it, translucent over
a blurred background, rounded where it meets the panel's edge (or floating off a floating
panel). It resizes from its corner. Without `layer-shell-qt`, or if you prefer, Glance opens
Plasma's usual popup instead (Settings > Popup > Style).

**The window's menu bar** runs across its top, as on macOS:
- the app's icon: KWin's window menu (desktops, activities, keep above…), as Alt+F3;
- the app's name: its own About, Settings and Quit, found in its menus;
- its menus (the global menu), and Alt and a letter opens one by its mnemonic;
- 🔍 search them, as the old HUD: a few letters of any item however deep ("prof new" finds
  File › New Tab › Profile…), Enter runs it, ← goes back to the menus;
- the window's buttons: keep above, minimize, maximize, close.

**Its tabs:**
- **Dashboard:** the time and weather; today's events, one slim line each, with Join on
  meetings and tomorrow's first, faint, when today's are done; CPU, memory and disk; what's
  playing, over its blurred cover (with a player); who you are and what you run; your
  notifications; quick controls (Bluetooth, Wi-Fi, Do Not Disturb, dark mode, Night Light, the
  microphone, the brightness, the batteries); focus and posture; the shelf.
- **Media:** the cover inside the spectrum's rays and blurred behind it all, the controls in a
  colour from the cover, the seek bar (scroll for 5 s, tap the length for the time left), the
  volume (scroll on the cover), shuffle, repeat, and the player when there's more than one.
- **Notifications:** the history grouped by app, with actions, replies, thumbnails and file
  transfers; Do Not Disturb for an hour, four hours, until tomorrow…
- **Controls:** Wi-Fi, Do Not Disturb, keep awake, the microphone and the power profile; each
  screen's brightness, the keyboard's light, dark mode and Night Light; where sound goes;
  Bluetooth with its devices and Pair; the batteries of devices on a USB receiver.
- **Shelf:** drop files to keep them at hand, drag them out into any app.
- **Work** (Focus and Shift together, or each alone): the timer and its stats, where you are
  and what's next, today against your goal, the week, the desk.
- **System:** processor, graphics, memory, disk and network.

### Focus and Shift

Both are off until turned on in their settings. They take over from the separate
[Fokus](https://gitlab.com/divinae/focus-plasmoid) and
[Shift](https://gitlab.com/divinae/shift-plasmoid) widgets (their settings aren't imported).

- **Focus:** a pomodoro or flowmodoro timer, a break overlay on every screen, Do Not Disturb
  while you focus, media paused for breaks, sounds and scripts. Locking the screen pauses a
  session. "Start the timer when Plasma starts" means after a reboot: a timer you stopped stays
  stopped through a Plasma restart.
- **Shift:** sit/stand reminders and a motorized desk (idasen by default, any command line
  tool) that moves when you click, or by itself if you want.
- **Together:** Shift waits for your focus breaks, so there's no reminder or desk move in the
  middle of a session, and a switch that's nearly due is made at the break. Breaks count as
  neither sitting nor standing.
- **Keep the screen on:** while focusing, its breaks too, and during meetings; no dimming,
  screen lock or sleep. Two settings, both on.

### Meetings and events

Events and the weather come from the [Event Calendar NG](https://github.com/divinae/plasma-applet-eventcalendar)
widget, 1.21 or later, with "Share events with Glance" on there. They come over D-Bus, with
meeting links, within seconds of Plasma starting. Before a meeting, its name takes the panel
text; while it's on, its pill shows the time left.

- **Focus** goes on through a meeting, but no break starts during it: a session that ends
  meanwhile waits, and its break begins as the meeting ends ("No break during meetings").
- **Shift** waits until the meeting is over, and can stand you up for it.
- **"Mark as Ended"** in Event Calendar ends it in Glance too.
- **A click on an event** opens it in Event Calendar.

## Keys

| Where | Keys | Do |
| --- | --- | --- |
| The drawer | Esc | closes it |
| | Ctrl+F, Alt+/ | search the window's menus |
| | Alt+letter | open that menu |
| The search | ↑ ↓, Enter, Esc | pick, run, back to the menus |
| The Media tab | Space or K | play or pause |
| | P, N | previous, next |
| | J, L or ←, → | 5 s back, on |
| | Home, End, 0–9 | start, end, a tenth of the way in |

The keys work while the drawer has the keyboard (opened with a click).

## Requirements

Plasma 6 (tested on 6.8) with plasma-pa, `layer-shell-qt` for the drawer, PipeWire, and
optionally `cava` for the audio bars.

Build: CMake, extra-cmake-modules, Qt 6 (Quick, DBus, Widgets, Concurrent), KF6 WindowSystem and
Service, libplasma (with PlasmaQuick), libpipewire, gettext.

At run time, for what uses them: [Event Calendar NG](https://github.com/divinae/plasma-applet-eventcalendar)
1.21 or later for events and meetings, `kde-inhibit` (Plasma's) to keep the screen on, and
`gdbus` (GLib's) for KWin's window menu. The Controls tab uses Plasma's own modules: bluez-qt
and bluedevil for Bluetooth, plasma-nm for Wi-Fi, power-profiles-daemon for the power profile;
without one, only its control is missing.

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

`tools/screenshots.sh` takes the screenshots above with made-up data: a person, a day of
meetings, a player and its cover, notifications (`GLANCE_DEMO=1`, see the script's header). It
restarts Plasma, so not in a call.

## Global menu

While "Application menu" is on, Glance owns the D-Bus name `org.kde.kappmenuview`, like the
stock Global Menu widget: applications that support it export their menus and hide their own
menu bars. Turn the option off to get in-window menu bars back.

`plugin/dbusmenuqt/` is vendored from plasma-workspace, which does not install it.

## When something's off

- **No events:** turn on "Share events with Glance" in Event Calendar's settings (General). See what
  arrived with `qdbus6 com.dv.glance /Calendar Snapshot`. Without the link, Glance reads Event
  Calendar's cache (Google calendars only).
- **Apps' own menu bars are gone:** that's the global menu (see above). Turn "Application menu"
  off in Glance's settings, then restart the app.
- **No drawer, only Plasma's popup:** install `layer-shell-qt`.
- **A widget shortcut:** Glance's (Settings > Keyboard Shortcuts) opens and closes the drawer.

## License

GPL-2.0-or-later.
