#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>
# SPDX-License-Identifier: GPL-2.0-or-later
"""A made-up music player on the session bus (MPRIS), for Glance's screenshots: one track,
playing, its position moving, a cover from the first argument (a file path)."""

import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS_NAME = "org.mpris.MediaPlayer2.glancedemo"
PATH = "/org/mpris/MediaPlayer2"
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
PROPS = "org.freedesktop.DBus.Properties"
LENGTH_US = 214_000_000


class Player(dbus.service.Object):
    def __init__(self, bus, cover):
        super().__init__(bus, PATH)
        self.cover = cover
        self.status = "Playing"
        self.volume = 0.7
        # A minute and a bit in, so the seek bar shows it
        self.started = time.monotonic() - 72

    def position(self):
        return dbus.Int64(int((time.monotonic() - self.started) * 1_000_000) % LENGTH_US)

    def metadata(self):
        return dbus.Dictionary({
            "mpris:trackid": dbus.ObjectPath("/org/glance/demo/track/1"),
            "mpris:length": dbus.Int64(LENGTH_US),
            "mpris:artUrl": "file://" + self.cover,
            "xesam:title": "Golden Hour Drive",
            "xesam:artist": dbus.Array(["Nova Lights"], signature="s"),
            "xesam:album": "Coastal Roads",
        }, signature="sv")

    def all(self, interface):
        if interface == ROOT:
            return {
                "Identity": "Music", "DesktopEntry": "", "CanQuit": False, "CanRaise": False,
                "HasTrackList": False, "SupportedUriSchemes": dbus.Array([], signature="s"),
                "SupportedMimeTypes": dbus.Array([], signature="s"),
            }
        return {
            "PlaybackStatus": self.status, "LoopStatus": "None", "Rate": 1.0, "Shuffle": False,
            "Metadata": self.metadata(), "Volume": self.volume, "Position": self.position(),
            "MinimumRate": 1.0, "MaximumRate": 1.0, "CanGoNext": True, "CanGoPrevious": True,
            "CanPlay": True, "CanPause": True, "CanSeek": True, "CanControl": True,
        }

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.all(interface)[name]

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.all(interface)

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, interface, name, value):
        if name == "Volume":
            self.volume = float(value)
            self.PropertiesChanged(PLAYER, {"Volume": self.volume}, [])

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.signal(PLAYER, signature="x")
    def Seeked(self, position):
        pass

    def set_status(self, status):
        self.status = status
        self.PropertiesChanged(PLAYER, {"PlaybackStatus": status}, [])

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        self.set_status("Paused" if self.status == "Playing" else "Playing")

    @dbus.service.method(PLAYER)
    def Play(self):
        self.set_status("Playing")

    @dbus.service.method(PLAYER)
    def Pause(self):
        self.set_status("Paused")

    @dbus.service.method(PLAYER)
    def Stop(self):
        self.set_status("Stopped")

    @dbus.service.method(PLAYER)
    def Next(self):
        pass

    @dbus.service.method(PLAYER)
    def Previous(self):
        pass

    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, offset):
        pass

    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track, position):
        pass

    @dbus.service.method(ROOT)
    def Raise(self):
        pass

    @dbus.service.method(ROOT)
    def Quit(self):
        loop.quit()


if __name__ == "__main__":
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName(BUS_NAME, bus)
    player = Player(bus, sys.argv[1] if len(sys.argv) > 1 else "")
    loop = GLib.MainLoop()
    loop.run()
