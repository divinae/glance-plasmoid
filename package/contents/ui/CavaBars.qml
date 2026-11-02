/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes

import org.kde.kirigami as Kirigami

// Audio spectrum from CavaSource (values 0..100).
// style 0: bars, 1: filled wave. centered: grows both ways from the middle.
Item {
    id: barsRoot

    required property QtObject cava
    property int style: 0
    property int barWidth: 4
    property int spacing: 2
    property bool rounded: true
    property bool centered: false
    property color color: Kirigami.Theme.highlightColor
    property int minimumBarHeight: 2
    // Fill the width with evenly sized bars instead of using barWidth
    property bool stretch: false
    // Fade towards the top (bars grow from the bottom): solid at the base, faint at full height
    property bool fadeUp: false
    property real fadeTopAlpha: 0.1

    // Square-root curve lifts quiet passages so the thin panel strip still moves
    property bool boost: false
    function level(i: int): real {
        const v = (values[i] ?? 0) / 100;
        return boost ? Math.sqrt(v) : v;
    }

    function alphaAt(y: real): real {
        return fadeTopAlpha + (1 - fadeTopAlpha) * Math.max(0, Math.min(1, y / height));
    }

    // Fewer, wider bands (0: all of cava's): each the average of a group of bars, from the low
    // end, where music has most of its energy
    property int bands: 0
    readonly property var values: {
        const all = cava.values;
        if (bands <= 0 || all.length <= bands) {
            return all;
        }
        const used = Math.max(bands, Math.round(all.length * 0.75)); // the top quarter is mostly empty
        const out = [];
        for (let b = 0; b < bands; ++b) {
            const from = Math.floor(b * used / bands);
            const to = Math.max(from + 1, Math.floor((b + 1) * used / bands));
            let sum = 0;
            for (let i = from; i < to; ++i) {
                sum += all[i] ?? 0;
            }
            out.push(sum / (to - from));
        }
        return out;
    }
    readonly property int count: values.length
    readonly property int effectiveBarWidth: stretch && count > 0
        ? Math.max(1, Math.floor((width - (count - 1) * spacing) / count))
        : barWidth

    implicitWidth: count > 0 ? count * barWidth + (count - 1) * spacing : 0
    implicitHeight: Kirigami.Units.gridUnit

    // Fade out during silence instead of showing flat stubs
    Item {
        id: fade
        anchors.fill: parent
        opacity: barsRoot.cava.silent ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration * 2 }
        }

    Row {
        visible: barsRoot.style === 0
        anchors.horizontalCenter: parent.horizontalCenter
        height: barsRoot.height
        spacing: barsRoot.spacing

        Repeater {
            model: barsRoot.style === 0 ? barsRoot.count : 0

            Rectangle {
                required property int index
                readonly property real v: barsRoot.level(index)
                width: barsRoot.effectiveBarWidth
                height: Math.max(barsRoot.minimumBarHeight, v * barsRoot.height)
                y: barsRoot.centered ? (barsRoot.height - height) / 2 : barsRoot.height - height
                radius: barsRoot.rounded ? Math.min(width / 2, 2) : Math.min(width / 2, 1)
                color: barsRoot.color
                gradient: barsRoot.fadeUp ? fadeGradient : null

                Gradient {
                    id: fadeGradient
                    GradientStop {
                        position: 0
                        color: Qt.alpha(barsRoot.color, barsRoot.alphaAt(barsRoot.height - parent.height))
                    }
                    GradientStop {
                        position: 1
                        color: barsRoot.color
                    }
                }

                Behavior on height {
                    NumberAnimation { duration: 60 }
                }
            }
        }
    }

    Shape {
        id: wave
        visible: barsRoot.style === 1
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: barsRoot.color
            strokeColor: "transparent"
            fillGradient: barsRoot.fadeUp ? waveGradient : null
            PathPolyline {
                path: barsRoot.style === 1 ? barsRoot.wavePoints() : []
            }
        }
    }

    }

    LinearGradient {
        id: waveGradient
        x1: 0
        y1: 0
        x2: 0
        y2: barsRoot.height
        GradientStop {
            position: 0
            color: Qt.alpha(barsRoot.color, barsRoot.fadeTopAlpha)
        }
        GradientStop {
            position: 1
            color: barsRoot.color
        }
    }

    function wavePoints() {
        const n = count;
        const w = width;
        const h = height;
        if (n === 0 || w <= 0 || h <= 0) {
            return [];
        }
        const pts = [];
        const step = n > 1 ? w / (n - 1) : w;
        const mid = h / 2;
        const top = [];
        for (let i = 0; i < n; ++i) {
            const amp = Math.max(minimumBarHeight / 2, level(i) * (centered ? h / 2 : h));
            top.push(Qt.point(i * step, centered ? mid - amp : h - amp));
        }
        // smooth: midpoints between samples for a softer outline
        pts.push(Qt.point(0, centered ? mid : h));
        for (let i = 0; i < n; ++i) {
            pts.push(top[i]);
            if (i < n - 1) {
                pts.push(Qt.point((top[i].x + top[i + 1].x) / 2, (top[i].y + top[i + 1].y) / 2));
            }
        }
        pts.push(Qt.point(w, centered ? mid : h));
        if (centered) {
            for (let i = n - 1; i >= 0; --i) {
                pts.push(Qt.point(top[i].x, h - top[i].y));
            }
        }
        pts.push(pts[0]);
        return pts;
    }
}
