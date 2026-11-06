#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Screenshots of Glance with made-up data, for the README and the KDE Store.
#
#   GLANCE_SHOT_AREA="X Y W H" tools/screenshots.sh [out-dir]     (default: build/screenshots)
#
# Only that area of the screen is captured (through KWin, capture.py), so set it to take in the
# panel's strip and the drawer: logical pixels, the whole first screen by default.
#
# What it does, and undoes at the end (or on Ctrl+C):
#   - plasmashell restarted with GLANCE_DEMO=1: a made-up person, day of events and weather
#     (SystemInfo.demo), and GLANCE_DEMO_TOUR: the tabs and cards shown in turn (DemoTour.qml);
#   - an empty virtual desktop with KWrite on a short note, so nothing of yours is behind the
#     drawer;
#   - a made-up music player (mock-player.py) with a generated cover, and a generated tune played
#     into a temporary "Speakers" output, the default meanwhile, for the bars (your own
#     sound is silent while it runs);
#   - a few notifications (notify-send) from NeoChat, KDE Connect, Discover and a calendar, closed
#     after; the apps' desktop entries made for the while where they aren't installed (Plasma keeps
#     notifications without one out of its history);
#   - Plasma in English while it runs.
# A shot per step, named after it, and tour.mp4: the whole tour, for a GIF.
#
# Needs: qdbus6, kwrite, notify-send, gdbus, pactl, paplay, ffmpeg, magick
# (ImageMagick), python3 with dbus-python and PyGObject. Don't run it in a call: Plasma restarts.

set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/../build/screenshots}
tour=${GLANCE_DEMO_TOUR:-panel,card:meeting,card:media,card:unread,dashboard,media,notifications,work,devices,system}
mkdir -p "$out"
out=$(cd "$out" && pwd)
work=$(mktemp -d)
area=${GLANCE_SHOT_AREA:-}
if [ -z "$area" ]; then
    size=$(kscreen-doctor -j 2>/dev/null | python3 -c 'import json,sys
o=[o for o in json.load(sys.stdin)["outputs"] if o.get("enabled")][0]
m=[m for m in o["modes"] if m["id"]==o["currentModeId"]][0]["size"]
print(round(m["width"]/o.get("scale",1)), round(m["height"]/o.get("scale",1)))')
    area="0 0 $size"
fi
# Plasma's environment before: the locale is set to English for the shots and put back after
locale_vars=(LANG LANGUAGE LC_ALL)
declare -A old_env
while IFS='=' read -r key value; do
    for v in "${locale_vars[@]}"; do
        [ "$key" = "$v" ] && old_env[$key]=$value
    done
done < <(systemctl --user show-environment)

vdm=(qdbus6 org.kde.KWin /VirtualDesktopManager)
pids=()
notes=()
entries=()
sink_module=""
old_sink=$(pactl get-default-sink)
old_desktop=$("${vdm[@]}" org.freedesktop.DBus.Properties.Get org.kde.KWin.VirtualDesktopManager current)
demo_desktop=""

restart_plasma() {
    systemctl --user reset-failed plasma-plasmashell.service
    timeout 20 systemctl --user restart plasma-plasmashell.service || {
        pkill -9 plasmashell
        sleep 2
        systemctl --user reset-failed plasma-plasmashell.service
        systemctl --user start plasma-plasmashell.service
    }
}

cleanup() {
    trap - EXIT INT TERM
    echo "Cleaning up…"
    systemctl --user unset-environment GLANCE_DEMO GLANCE_DEMO_TOUR
    for v in "${locale_vars[@]}"; do
        if [ -n "${old_env[$v]+set}" ]; then
            systemctl --user set-environment "$v=${old_env[$v]}"
        else
            systemctl --user unset-environment "$v"
        fi
    done
    for id in "${notes[@]}"; do
        gdbus call --session -d org.freedesktop.Notifications -o /org/freedesktop/Notifications \
            -m org.freedesktop.Notifications.CloseNotification "$id" >/dev/null 2>&1
    done
    for f in "${entries[@]}"; do
        rm -f "$f"
    done
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    pactl set-default-sink "$old_sink"
    [ -n "$sink_module" ] && pactl unload-module "$sink_module"
    "${vdm[@]}" org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager current "$old_desktop" >/dev/null 2>&1
    [ -n "$demo_desktop" ] && "${vdm[@]}" org.kde.KWin.VirtualDesktopManager.removeDesktop "$demo_desktop"
    restart_plasma
    rm -rf "$work"
    echo "Done: $out"
}
trap cleanup EXIT INT TERM

# ---- the made-up things --------------------------------------------------------------------

# A cover: a striped sun setting behind two ridges
magick -size 640x640 gradient:"#ffb36b"-"#5b2a86" \
    \( -size 640x640 xc:none -fill "#ffe7a3" -draw "circle 320,350 320,222" \
       \( -size 640x640 xc:none -fill black -draw "rectangle 0,372 640,380" -draw "rectangle 0,396 640,406" \
          -draw "rectangle 0,422 640,436" -draw "rectangle 0,450 640,468" \) -compose DstOut -composite \) \
    -compose over -composite \
    -fill "#3b1f5e" -draw "polygon 0,640 0,470 110,410 220,465 330,390 450,455 560,405 640,440 640,640" \
    -fill "#22123d" -draw "polygon 0,640 0,560 150,505 290,565 420,522 640,585 640,640" \
    "$work/cover.png"

# A tune for the bars: a kick, a bass and chords that swell, a minute and a half
ffmpeg -loglevel error -f lavfi -t 90 -i "aevalsrc='\
0.55*exp(-mod(t,0.5)*18)*sin(2*PI*52*t)\
+0.25*sin(2*PI*110*t)*(0.6+0.4*sin(2*PI*0.5*t))\
+0.12*sin(2*PI*330*t)*(0.5+0.5*sin(2*PI*1.3*t))\
+0.10*sin(2*PI*660*t)*(0.5+0.5*sin(2*PI*2.1*t))\
+0.08*sin(2*PI*1320*t)*(0.5+0.5*sin(2*PI*3.7*t))\
+0.05*sin(2*PI*2640*t)*(0.5+0.5*sin(2*PI*5.3*t))\
+0.03*sin(2*PI*5280*t)*(0.5+0.5*sin(2*PI*7.9*t))':s=44100" "$work/tune.wav"

sink_module=$(pactl load-module module-null-sink sink_name=glance_demo \
    sink_properties=device.description=Speakers)
pactl set-default-sink glance_demo

python3 "$here/screenshots/mock-player.py" "$work/cover.png" &
pids+=($!)
paplay --device=glance_demo "$work/tune.wav" &
pids+=($!)

# A desk of its own, KWrite on it
"${vdm[@]}" org.kde.KWin.VirtualDesktopManager.createDesktop 99 "Glance demo"
sleep 0.5
demo_desktop=$(qdbus6 --literal org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Get \
    org.kde.KWin.VirtualDesktopManager desktops | grep -o '[0-9a-f-]\{36\}", "Glance demo"' | cut -d'"' -f1)
"${vdm[@]}" org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager current "$demo_desktop"
cat > "$work/Trip notes.md" <<'NOTE'
# Coastal road trip

- Day 1: Lisbon → Sintra, the palaces in the morning
- Day 2: Cascais, the beach, dinner by the harbour
- Day 3: up the coast to Nazaré for the waves
NOTE
kwrite "$work/Trip notes.md" >/dev/null 2>&1 &
pids+=($!)
sleep 2

# The notifications' apps: a desktop entry for the while where one isn't installed, before
# Plasma restarts so it knows them (it keeps notifications from no app out of its history)
app_entry() {
    local entry=$1 name=$2 icon=$3 file
    file=$HOME/.local/share/applications/$entry.desktop
    if [ ! -e "$file" ] && [ ! -e "/usr/share/applications/$entry.desktop" ]; then
        printf '[Desktop Entry]\nType=Application\nName=%s\nIcon=%s\nExec=true\nNoDisplay=true\n' \
            "$name" "$icon" > "$file"
        entries+=("$file")
    fi
}
app_entry org.kde.neochat NeoChat org.kde.neochat
app_entry org.kde.kdeconnect.app "KDE Connect" kdeconnect
app_entry org.kde.discover Discover plasmadiscover
app_entry org.kde.merkuro.calendar Calendar view-calendar
kbuildsycoca6 >/dev/null 2>&1

# ---- Plasma in demo mode, the tour, the shots ------------------------------------------------

systemctl --user set-environment GLANCE_DEMO=1 "GLANCE_DEMO_TOUR=$tour" \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
since=$(date '+%Y-%m-%d %H:%M:%S')
restart_plasma

# The notifications, sent once the tour has begun (just after its first shot: right after the
# restart they sometimes went nowhere), a few seconds before the unread pill's card
# notify ENTRY NAME ICON SUMMARY BODY: from the app with that desktop entry (made above)
notify() {
    local entry=$1 name=$2 icon=$3 id
    shift 3
    id=$(notify-send -p -a "$name" -i "$icon" -h "string:desktop-entry:$entry" "$@")
    notes+=("$id")
    echo "  notification $id from $name"
}
send_notifications() {
    notify org.kde.neochat NeoChat org.kde.neochat "Sam" "Lunch at the Corner Café? I'll book a table for 12:30"
    notify org.kde.kdeconnect.app "KDE Connect" kdeconnect "Pixel 8" "Battery at 15%. Plug it in soon."
    notify org.kde.discover Discover plasmadiscover "Updates available" "3 updates are ready to install"
    notify org.kde.merkuro.calendar Calendar view-calendar "Design review" "Starting now · Meet"
}

# Plasma's notification server back first
for _ in $(seq 40); do
    gdbus call --session -d org.freedesktop.Notifications -o /org/freedesktop/Notifications \
        -m org.freedesktop.Notifications.GetServerInformation 2>/dev/null | grep -q Plasma && break
    sleep 0.5
done
sleep 1

echo "Taking: $tour, in $area"
python3 "$here/screenshots/capture.py" record $area 20 "$out/tour.mp4" &
recorder=$!
pids+=($recorder)
exec 3< <(timeout 240 journalctl --user -u plasma-plasmashell -f --since "$since" -o cat)
follower=$!
while read -r line <&3; do
    case "$line" in
    *glance-demo-shot*)
        step=${line##*glance-demo-shot }
        name=${step//:/-}
        python3 "$here/screenshots/capture.py" shot $area "$out/$name.png"
        echo "  $name.png"
        [ ${#notes[@]} -eq 0 ] && send_notifications
        ;;
    *glance-demo-done*)
        break
        ;;
    esac
done
kill "$follower" 2>/dev/null
exec 3<&-
kill -TERM "$recorder"
wait "$recorder"
