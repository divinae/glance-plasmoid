/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes

import "DrawerGeometry.js" as Geometry

// The drawer's surface: rounded on the outside, flowing into the screen edge through two concave
// ears (Caelestia's look). Geometry in DrawerGeometry.js.
Shape {
    id: shape

    property string edge: "left"
    property real depth: 0
    property real along: 0
    property real ear: 20
    property real radius: 20
    property color color: "black"

    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
        fillColor: shape.color
        strokeColor: "transparent"
        strokeWidth: -1
        PathSvg {
            path: Geometry.path(shape.edge, shape.width, shape.height, shape.depth, shape.along, shape.ear, shape.radius)
        }
    }
}
