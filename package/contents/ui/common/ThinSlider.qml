/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// A thin slider in a colour of its own (the music card's seek and volume, in the cover's): a
// track with its fill, thicker and with a knob under the pointer. Click or drag sets it, the
// wheel nudges it. `moved(value)` as the user sets it; `value` follows what it shows.
// `live`: `moved` while dragging too (a few times a second), not only on release: brightness
// follows the finger; a seek stays on release. `valueText` puts what you'd set in a bubble over
// the knob while dragging; `shownValue` is it, for a label beside it.
Item {
    id: slider

    property real value: 0
    property real from: 0
    property real to: 1
    // A wheel notch's step, in the slider's own units
    property real wheelStep: (to - from) / 20
    property color color: Kirigami.Theme.highlightColor
    property bool live: false
    // Snaps to multiples of it (a keyboard's few backlight levels); 0 for none
    property real stepSize: 0
    // The bubble's text for a value, while dragging (empty: no bubble)
    property var valueText: null

    signal moved(real value)

    readonly property bool active: hover.hovered || drag.pressed
    // What it shows: where the finger is while dragging, and where it was let go until the value
    // gets there (a seek answers a moment later: it mustn't spring back first), else the value
    readonly property real shownValue: drag.pressed || settling ? dragValue : value
    property bool settling: false
    onValueChanged: settling = false
    Timer {
        id: settleTimer
        interval: 1500
        onTriggered: slider.settling = false
    }
    readonly property real targetFraction: to > from
        ? Math.max(0, Math.min(1, (shownValue - from) / (to - from))) : 0
    // Follows the finger at once; eases when the value moves by itself (the wheel, a key)
    property real fraction: targetFraction
    Behavior on fraction {
        enabled: !drag.pressed && !slider.settling
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    property real dragValue: 0

    implicitHeight: Kirigami.Units.gridUnit * 0.75

    function valueAt(x) {
        const v = from + Math.max(0, Math.min(1, x / width)) * (to - from);
        return stepSize > 0 ? Math.max(from, Math.min(to, from + Math.round((v - from) / stepSize) * stepSize)) : v;
    }
    // While dragging, live: the latest position, sent at most every 50 ms (each one a D-Bus call)
    property real sentValue: NaN
    function sendLive() {
        if (live && drag.pressed && dragValue !== sentValue) {
            sentValue = dragValue;
            moved(dragValue);
        }
    }
    Timer {
        id: liveTimer
        interval: 50
        repeat: true
        running: slider.live && drag.pressed
        onTriggered: slider.sendLive()
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
        id: knob
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

    // What you'd set, over the knob while dragging
    Rectangle {
        visible: drag.pressed && !!slider.valueText
        z: 1
        width: bubbleLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        height: bubbleLabel.implicitHeight + 2
        radius: height / 2
        x: Math.max(-knob.width / 2, Math.min(slider.width - width + knob.width / 2,
            slider.fraction * slider.width - width / 2))
        y: -height - 4
        color: slider.color
        Text {
            id: bubbleLabel
            anchors.centerIn: parent
            text: slider.valueText ? slider.valueText(slider.dragValue) : ""
            color: Kirigami.Theme.highlightedTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.features: { "tnum": 1 }
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
        // Keep the drag when the pointer strays off the slider's line
        preventStealing: true
        onPressed: mouse => {
            slider.sentValue = NaN;
            slider.dragValue = slider.valueAt(mouse.x);
            slider.sendLive();
        }
        onPositionChanged: mouse => {
            if (pressed) {
                slider.dragValue = slider.valueAt(mouse.x);
            }
        }
        onReleased: {
            const changed = slider.dragValue !== slider.value;
            if (slider.dragValue !== slider.sentValue) {
                slider.moved(slider.dragValue);
            }
            // A value already there won't change again: nothing to wait for
            slider.settling = changed && slider.dragValue !== slider.value;
            if (slider.settling) {
                settleTimer.restart();
            }
        }
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
