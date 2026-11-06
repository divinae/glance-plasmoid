#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>
# SPDX-License-Identifier: GPL-2.0-or-later
"""An area of the screen through KWin (ScreenShot2.CaptureArea), so nothing outside it is ever
captured:

    capture.py shot X Y W H out.png
    capture.py record X Y W H FPS out.mp4     (until SIGINT or SIGTERM)

X, Y, W, H in logical pixels."""

import os
import signal
import subprocess
import sys
import time

import dbus

# QImage formats KWin sends, as ffmpeg's pixel formats
FORMATS = {4: "bgr0", 5: "bgra", 6: "bgra", 16: "rgb0", 17: "rgba", 18: "rgba"}

bus = dbus.SessionBus()
shot = dbus.Interface(bus.get_object("org.kde.KWin", "/org/kde/KWin/ScreenShot2"), "org.kde.KWin.ScreenShot2")


def grab(x, y, w, h):
    r, wfd = os.pipe()
    meta = shot.CaptureArea(x, y, w, h, {"native-resolution": True}, dbus.types.UnixFd(wfd))
    os.close(wfd)
    chunks = []
    while True:
        chunk = os.read(r, 1 << 20)
        if not chunk:
            break
        chunks.append(chunk)
    os.close(r)
    return int(meta["width"]), int(meta["height"]), int(meta["stride"]), int(meta["format"]), b"".join(chunks)


def ffmpeg(width, height, fmt, args):
    return subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", fmt,
                             "-s", f"{width}x{height}"] + args, stdin=subprocess.PIPE)


def rows(data, width, height, stride):
    if stride == width * 4:
        return data
    return b"".join(data[i * stride:i * stride + width * 4] for i in range(height))


def main():
    mode, x, y, w, h = sys.argv[1], *map(int, sys.argv[2:6])
    if mode == "shot":
        width, height, stride, fmt, data = grab(x, y, w, h)
        p = ffmpeg(width, height, FORMATS[fmt], ["-i", "-", "-frames:v", "1", sys.argv[6]])
        p.communicate(rows(data, width, height, stride))
        return
    fps, out = int(sys.argv[6]), sys.argv[7]
    width, height, stride, fmt, data = grab(x, y, w, h)
    p = ffmpeg(width, height, FORMATS[fmt], ["-framerate", str(fps), "-i", "-",
                                             "-c:v", "libx264", "-crf", "12", "-pix_fmt", "yuv444p", out])
    stop = []
    signal.signal(signal.SIGTERM, lambda *_: stop.append(1))
    signal.signal(signal.SIGINT, lambda *_: stop.append(1))
    frame = 1 / fps
    next_at = time.monotonic()
    while not stop:
        p.stdin.write(rows(data, width, height, stride))
        next_at += frame
        time.sleep(max(0, next_at - time.monotonic()))
        width, height, stride, fmt, data = grab(x, y, w, h)
    p.stdin.close()
    p.wait()


if __name__ == "__main__":
    main()
