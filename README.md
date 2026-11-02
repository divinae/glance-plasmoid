# Glance

Plasma 6 panel widget for a vertical panel. It replaces a window-title widget.

- **In the panel:** the active application's name, rotated along the panel. While media plays it
  crossfades to the track and artist, with a small equalizer from `cava` and a progress line.
- **On hover (or click to pin):** a drawer slides out of the panel beside it, translucent over a
  blurred background, flowing into the panel's edge. Its first tab is a dashboard: the time,
  what's playing, today's events (from Event Calendar), notifications, the shelf, and the active
  window with its buttons and global menu. The other tabs show each of these in full.
- Middle-click plays or pauses. The wheel skips tracks.
- The drawer needs `layer-shell-qt`; without it, or if you prefer, Glance opens Plasma's usual
  popup instead (Settings > Popup > Style).

## Build and install

```sh
sudo pacman -S cava   # optional; audio bars are hidden without it
make install          # builds the C++ plugin, installs to ~/.local
make restart          # restart plasmashell
```

`~/.local/lib/qml` must be on `QML2_IMPORT_PATH` for plasmashell (it already is when other
`~/.local` plugins such as uswitch work).

## Global menu

While "Application menu" is enabled the widget owns the DBus name `org.kde.kappmenuview`, like
the stock Global Menu widget. Applications that support it then export their menus and hide
their own menu bars. Turn the option off to get in-window menu bars back.

`plugin/dbusmenuqt/` is vendored from plasma-workspace, which does not install it.
