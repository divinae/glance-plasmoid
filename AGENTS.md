# Glance: notes for AI agents

Glance is a KDE Plasma 6 panel widget for a vertical panel: a strip showing one thing at a time
(window title, track, meeting, notice), status pills with hover cards, and a layer-shell drawer
that slides out with tabs (Dashboard, Controls, Notifications, Media, Shelf, System, Work =
Focus + Shift) and the active window's global menu with search. Plugin Id `com.dv.glance` (was
`com.dv.island` before 1.0.0), GPL-2.0-or-later, author Jakub Lipiński (GitHub `divinae`).
Published on GitHub (`divinae/glance-plasmoid`, releases from `vX.Y.Z` tags) and the KDE Store
(https://store.kde.org/p/2381246/). Push to `origin` (git@github.com:divinae/glance-plasmoid.git);
commit on `master`, no feature branches. It ships a C++ QML plugin, so it is built from source; a
bare `.plasmoid` will not load.

## Layout

- `package/metadata.json`: Id, Version (single source; CMake reads both from it).
- `package/contents/config/main.xml`: all settings (~154 entries, one `General` group).
  `config.qml`: the six pages (General, Popup, Media & Bars, Shift, Focus, Activities) =
  `ui/config*.qml` with `cfg_<key>` aliases.
- `package/contents/ui/`: `main.qml` (root; `readonly property var cfg: Plasmoid.configuration`),
  `CompactIsland.qml` (panel strip + pills), `IslandContent.qml` (drawer content, menu bar),
  state helpers (`MediaState`, `ControlsState`, `CalendarSource`, `PrivacyMonitor`...), pure JS
  `Format.js`, `Calendar.js`. "Island" is the pre-1.0 name; the plugin is imported `as Island`
  almost everywhere.
  - `tabs/` drawer tabs, `tiles/` dashboard cards, `drawer/` (Drawer.qml layer-shell window,
    `DrawerGeometry.js` shape math), `popouts/` pill hover cards, `controls/` (Wi-Fi, audio,
    power profile), `common/` helpers shared by Glance, Focus and Shift (ExecUtil, Sfx,
    NotificationManager, ProgressCircle, Utils.js, PillButton, DrawerMenu...).
  - `focus/` Fokus's pomodoro/flowmodoro timer (`FocusController` = state, `FocusView` = tab),
    `focus/lib/{timer,tasks}.js`; `stand/` Shift's sit/stand reminder (`StandController`,
    `StandView`, `Desk.qml`), `stand/lib/{cycle,desk}.js`.
- `plugin/`: QML module `com.dv.glance.private` (`ecm_add_qml_module`, `QML_ELEMENT`/
  `QML_SINGLETON` classes): `appmenumodel` (global menu, owns `org.kde.kappmenuview`),
  `calendarbus` (D-Bus `com.dv.glance /Calendar`, fed by Event Calendar NG), `cavasource`,
  `drawereffects` (blur/contrast), `screencastmonitor` (PipeWire: mic/screen/camera in use),
  `shelfhelper`, `systeminfo` (also demo mode), `thememode`, `trayactions` (runs other tray
  icons' menu entries). `plugin/dbusmenuqt/` is vendored from plasma-workspace (LGPL, Canonical);
  don't restyle it.
- `tests/`: `*.test.mjs` (node, load `.pragma library` JS via `tests/load.mjs`), `tests/focus/`
  and `tests/stand/` (qmltestrunner `tst_*.qml`), `compile.sh` + `compile.qml` (every QML file must
  compile).
- `tools/extract-messages.sh` (i18n), `tools/screenshots.sh` + `tools/screenshots/` (demo shots).
- `docs/screenshots/`, `docs/store/kde-store.md` (store text, release checklist), `po/`.
- Ignored: `build/`, `*.plasmoid` (old ones sit in the root), `package/contents/locale/`.

## Build, run, test

All via the `Makefile` (wraps CMake; `PREFIX ?= ~/.local`, `BUILD_DIR ?= build`):
- `make` / `make build`: configure (Release), compile `.mo` files, build the plugin.
- `make install`: build + `cmake --install` (package via `plasma_install_package`, plugin to
  `~/.local/lib/qml/com/dv/glance/...`). Plasma finds the plugin only with `QML_IMPORT_PATH`
  including `~/.local/lib/qml` (README "Install" step 3, `~/.config/plasma-workspace/env/glance.sh`).
- See a change live: `make install && make restart` (restarts `plasma-plasmashell` via systemd;
  needed for C++ changes, the plugin is loaded once). `make run` opens the installed widget in
  `plasmawindowed` (install first). Don't restart Plasma without asking: the user may be in a call.
- `make test`: `node --test tests/`, qmltestrunner on `tests/stand` and `tests/focus` (offscreen),
  `tests/compile.sh` (needs `qml6` and `build/bin`), the `plasmoid.configuration` guard (below),
  `msgfmt --check` on `po/*.po`. Runs `build` first.
- `make lint`: `qmllint` with `--unqualified` and `--missing-property` disabled (Plasma attached
  props aren't resolvable outside plasmashell). Its file list omits `ui/controls/` and
  `ui/popouts/`; `compile.sh` covers everything.
- Other targets: `uninstall`, `package` (zip of `package/` to `glance-v<version>.plasmoid`, QML and
  translations only), `messages`, `translations`, `clean`.
- Debug: `journalctl --user -b | grep -iE "glance|plasmashell"`; events received:
  `qdbus6 com.dv.glance /Calendar Snapshot`.

## Conventions

- QML: 4-space indent, `id: root`, comments are full sentences explaining why (often citing the
  crash or issue that motivated them). Heavy/optional pieces sit behind `Loader`s (Focus/Stand are
  `active: root.cfg.focusEnabled/standEnabled`). JS logic that tests touch is `.pragma library`
  with no QML deps (`Format.js`, `Calendar.js`, `DrawerGeometry.js`, `focus/lib`, `stand/lib`).
- C++: C++20, KDE compiler settings, Qt6/KF6 >= 6.8/6.14; nothing may block plasmashell's GUI
  thread (D-Bus/process calls async or on a worker, with timeouts; see `trayactions.h`).
  New plugin classes must be added to `plugin/CMakeLists.txt` `target_sources`.
- SPDX: Glance's own files start with
  `SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>` +
  `SPDX-License-Identifier: GPL-2.0-or-later` (C-style block in QML/C++, `#` in shell). Files
  copied from Fokus/Shift (`focus/`, `stand/`, parts of `common/`) and the tests mostly have none.
  Add the header to new files.
- i18n: `i18n()/i18nc()/i18np()/i18ncp()`; domain `plasma_applet_com.dv.glance`.
  `make messages` regenerates `po/plasma_applet_com.dv.glance.pot` and merges `po/*.po`; `make
  translations` compiles them into `package/contents/locale/` (ignored). There are currently no
  `.po` files: Polish was dropped in `0de60d1`; only extraction is kept.
- Settings: add the entry to `main.xml` (Focus/Shift keys are prefixed `focus_*`/`stand_*`), a
  `cfg_<key>` alias on the page, read it through `root.cfg` / the `settings` handed in. Runtime
  state is also stored as JSON strings in config (`focus_session_state`, `focus_session_history`,
  `stand_cycle_state`, `stand_stand_history`). There is no migration mechanism: don't rename or
  remove keys (1.7.0 hid options from the pages but kept their values).
- Versioning/release: semver in `package/metadata.json`. Changes collect under `## Unreleased` in
  `CHANGELOG.md` (bold lead-ins, user-facing prose); the release commit `Glance X.Y.Z` renames it to
  `## X.Y.Z — YYYY-MM-DD`, bumps `metadata.json`, updates version + changelog in
  `docs/store/kde-store.md`, then tag `vX.Y.Z`. The store gets the GitHub tag tarball, not the
  `.plasmoid` (see `docs/store/kde-store.md`).
- Commits: subject is a plain descriptive phrase, often `Area: what changes` (`Panel: ...`,
  `README: ...`, `Menus: ...`), no conventional-commit prefix, no trailing period; bodies wrap at
  ~72 with `- ` bullets for multi-part changes; trailer `Co-Authored-By: ...`.

## Gotchas

- `make test` fails on any non-comment `plasmoid.configuration` / `Plasmoid.configuration` under
  `ui/common`, `ui/focus`, `ui/stand`. Fokus and Shift read their own unprefixed keys directly; in
  Glance their keys are `focus_*`/`stand_*` and `main.qml` hands `Plasmoid.configuration` in as the
  `settings` property of `FocusController`/`StandController` (and `common/` is shared by all).
  A direct read would hit a non-existent key and silently yield `undefined`, and qmllint (with
  `--unqualified` off) can't catch it, so the grep guard does.
- Never statically reference a type importing `org.kde.layershell`: `LayerShellProbe.qml` (root
  and `focus/`) is created via `Qt.createComponent()` and the overlay via Loader URL, so a machine
  without layer-shell-qt falls back to Plasma's popup instead of failing to load.
- `common/Sfx.qml` creates `MediaPlayer` lazily: constructing one probes VDPAU and keeps an
  NVIDIA dGPU awake.
- `Kirigami.ImageColors` lives once in `main.qml` for the widget's lifetime: destroying one mid
  extraction crashed plasmashell.
- Pills keep keyed delegates; rebuilding them closed open hover cards (fixed in 1.7.1).
- `CalendarBus` accepts payloads only from a process plasmashell started; Event Calendar NG >= 1.21
  with "Share events with Glance". Fallback: its newest cache file.
- The application menu owns `org.kde.kappmenuview`, which makes apps hide their own menu bars.
- Demo/screenshot mode: `GLANCE_DEMO=1` (+ `GLANCE_DEMO_TOUR`) in plasmashell's env, read by
  `SystemInfo`. `tools/screenshots.sh` restarts Plasma and switches audio output; never run it
  unasked.
- `tools/extract-messages.sh` still has a GitLab `--msgid-bugs-address`; the project moved to
  GitHub (`069d6ce`).

## Related (sibling checkouts in `../`)

- `../focus-plasmoid` (Fokus) and `../shift-plasmoid` (Shift): their code was imported on
  2026-11-03 (`b53b43a`, `7283f48`), main.qml split into Controller + View, settings renamed to
  `focus_*`/`stand_*`, shared helpers deduplicated into `ui/common/` (`0de60d1`). No sync
  mechanism; copies have diverged (Glance's `focus/lib/timer.js` has `savedThisBoot`;
  `stand/Desk.qml` differs only in its import). Byte-identical with the standalone repos (as of
  `fb907ba`): `focus/lib/tasks.js`, `stand/lib/desk.js`, `stand/WeekChart.qml`, `focus/TaskListView.qml`, the break overlay layers,
  `common/ProgressCircle.qml`, `common/Sfx.qml` (= Fokus), `common/ExecUtil.qml` (= Shift).
  `stand/lib/cycle.js` was too until 1.8.0, which added `offReason` and `weekendsOff` (Shift's
  "Not on weekends"); Shift's own copy hasn't got them. Each repo
  is the source of truth for its own copy; port fixes by hand. Glance doesn't import their settings.
- `../eventcalendar-plasmoid` (Event Calendar NG): publishes events and weather to Glance over D-Bus
  (`ui/GlancePublisher.qml`/`.js` there, `plugin/calendarbus.*` here). Change both sides together.
- `../github-plasmoid` follows Glance's layout and Makefile; `../zephyr-theme`'s look-and-feel
  layouts place `com.dv.glance` in the panel. `.github/FUNDING.yml` is identical in glance,
  eventcalendar, karousel-overview, shift, taskline and uswitch.
- No shared code found with `../taskline-plasmoid`, `../uswitch-plasmoid`, `../karousel-overview`.
