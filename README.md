# Island

Plasma 6 panel widget for a vertical panel. It replaces a window-title widget.

- **In the panel:** the active application's name, rotated along the panel. While media plays it
  crossfades to the track and artist, with live audio bars from `cava`.
- **On hover (or click to pin):** a popup with the window's icon and title, window buttons
  (keep above, minimize, maximize, close), the application's global menu, and media controls.
- Middle-click plays or pauses. The wheel skips tracks.

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
