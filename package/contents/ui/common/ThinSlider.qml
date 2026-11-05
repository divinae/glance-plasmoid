/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// A thin slider in a colour of its own (the music card's seek and volume, in the cover's): a
// track with its fill, thicker and with a knob under the pointer. Click or drag sets it, the
// wheel nudges it. `moved(value)` as the user sets it; `value` follows what it shows.
Item {
    id: slider

    property real value: 0
    property real from: 0
    property real to: 1
    // A wheel notch's step, in the slider's own units
    property real wheelStep: (to - from) / 20
    property color color: Kirigami.Theme.highlightColor

    signal moved(real value)

    readonly property bool active: hover.hovered || drag.pressed
    readonly property real fraction: to > from
        ? Math.max(0, Math.min(1, ((drag.pressed ? dragValue : value) - from) / (to - from))) : 0
    property real dragValue: 0

    implicitHeight: Kirigami.Units.gridUnit * 0.75

    function valueAt(x) {
        return from + Math.max(0, Math.min(1, x / width)) * (to - from);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: slider.active ? 6 : 4
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        Behavior on height {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
        Rectangle {
            width: slider.fraction * parent.width
            height: parent.height
            radius: parent.radius
            color: slider.color
        }
    }
    Rectangle {
        width: Math.round(Kirigami.Units.gridUnit * 0.7)
        height: width
        radius: width / 2
        x: slider.fraction * slider.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: slider.color
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1
        opacity: slider.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        // A little taller than the track: easy to catch
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        onPressed: mouse => slider.dragValue = slider.valueAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) {
                slider.dragValue = slider.valueAt(mouse.x);
            }
        }
        onReleased: slider.moved(slider.dragValue)
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real pending: 0
        onWheel: event => {
            pending += event.angleDelta.y || -event.angleDelta.x;
            const steps = Math.trunc(pending / 120);
            if (steps !== 0) {
                pending -= steps * 120;
                slider.moved(Math.max(slider.from, Math.min(slider.to, slider.value + steps * slider.wheelStep)));
            }
        }
    }
}
