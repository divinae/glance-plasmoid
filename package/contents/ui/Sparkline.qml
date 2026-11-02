/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes

import org.kde.kirigami as Kirigami

// A small area chart of the last values, newest on the right. maximum 0: scaled to the largest.
Item {
    id: spark

    property var values: []
    property real maximum: 0
    property int capacity: 60
    property color color: Kirigami.Theme.highlightColor

    readonly property real peak: maximum > 0 ? maximum : Math.max(1, ...values)

    function points(closed) {
        const n = values.length;
        if (n < 2 || width <= 0 || height <= 0) {
            return [];
        }
        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (n - 1) * step;
        const pts = [];
        for (let i = 0; i < n; ++i) {
            const v = Math.max(0, Math.min(1, values[i] / peak));
            pts.push(Qt.point(x0 + i * step, height - 1 - v * (height - 2)));
        }
        if (closed) {
            pts.push(Qt.point(width, height), Qt.point(x0, height), pts[0]);
        }
        return pts;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: spark.height
                GradientStop { position: 0; color: Qt.alpha(spark.color, 0.35) }
                GradientStop { position: 1; color: Qt.alpha(spark.color, 0.02) }
            }
            PathPolyline { path: spark.points(true) }
        }
        ShapePath {
            strokeColor: spark.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: spark.points(false) }
        }
    }
}
