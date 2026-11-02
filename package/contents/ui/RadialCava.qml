/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// The spectrum as rays around a circle (Caelestia's media tab): the bands mirrored left and right
// so the low end sits at the bottom, each ray growing outward from `innerRadius`.
Item {
    id: radial

    required property QtObject cava
    property real innerRadius: Math.min(width, height) / 2 * 0.7
    property real maxLength: Math.min(width, height) / 2 - innerRadius
    property real rayWidth: 3
    property color color: Kirigami.Theme.highlightColor

    readonly property var values: cava.values || []
    readonly property int half: values.length
    readonly property int rays: half * 2

    opacity: cava.silent ? 0 : 1
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration * 2 }
    }

    Repeater {
        model: radial.rays
        Rectangle {
            id: ray
            required property int index
            // Rays 0..half-1 go up the right side from the bottom, the rest mirror them on the left
            readonly property int band: index < radial.half ? index : radial.rays - 1 - index
            readonly property real level: Math.sqrt(Math.max(0, Math.min(1, (radial.values[band] ?? 0) / 100)))
            readonly property real angle: 180 + (index + 0.5) * 360 / radial.rays
            width: radial.rayWidth
            height: Math.max(radial.rayWidth, level * radial.maxLength)
            radius: width / 2
            color: radial.color
            opacity: 0.35 + 0.65 * level
            x: radial.width / 2 - width / 2
            y: radial.height / 2 - radial.innerRadius - height
            transform: Rotation {
                origin.x: radial.rayWidth / 2
                origin.y: radial.innerRadius + ray.height
                angle: ray.angle
            }
            Behavior on height {
                NumberAnimation { duration: 60 }
            }
        }
    }
}
