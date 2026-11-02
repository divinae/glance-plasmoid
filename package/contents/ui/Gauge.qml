/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// A round gauge (Caelestia's Performance tab): a 270° track open at the bottom, filled to
// `fraction`, the figure large in the middle with its label under it, a second figure below.
Item {
    id: gauge

    property real fraction: 0
    // An optional second ring inside (e.g. the temperature around a usage): -1 none
    property real innerFraction: -1
    property color innerColor: Kirigami.Theme.neutralTextColor
    property string value
    property string label
    property string detail
    property real thickness: Math.max(6, Math.round(Math.min(width, height) / 14))
    property color color: fraction > 0.9 ? Kirigami.Theme.negativeTextColor
        : fraction > 0.75 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor

    readonly property real side: Math.min(width, height)
    readonly property real r: side / 2 - thickness / 2
    property real shown: fraction
    Behavior on shown {
        NumberAnimation { duration: Kirigami.Units.longDuration * 2; easing.type: Easing.OutCubic }
    }
    readonly property real innerR: r - thickness * 1.6
    property real innerShown: Math.max(0, innerFraction)
    Behavior on innerShown {
        NumberAnimation { duration: Kirigami.Units.longDuration * 2; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.centerIn: parent
        width: gauge.side
        height: gauge.side
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(gauge.color, 0.18)
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.side / 2
                centerY: gauge.side / 2
                radiusX: gauge.r
                radiusY: gauge.r
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: gauge.color
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.side / 2
                centerY: gauge.side / 2
                radiusX: gauge.r
                radiusY: gauge.r
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * Math.max(0, Math.min(1, gauge.shown)))
            }
        }
        ShapePath {
            strokeColor: gauge.innerFraction >= 0 ? Qt.alpha(gauge.innerColor, 0.15) : "transparent"
            strokeWidth: gauge.thickness * 0.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.side / 2
                centerY: gauge.side / 2
                radiusX: gauge.innerR
                radiusY: gauge.innerR
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: gauge.innerFraction >= 0 ? gauge.innerColor : "transparent"
            strokeWidth: gauge.thickness * 0.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.side / 2
                centerY: gauge.side / 2
                radiusX: gauge.innerR
                radiusY: gauge.innerR
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * Math.min(1, gauge.innerShown))
            }
        }
    }

    Column {
        anchors.centerIn: parent
        PlasmaComponents.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.value
            font.pointSize: Math.max(Kirigami.Theme.defaultFont.pointSize, gauge.side / 9)
            font.weight: Font.DemiBold
        }
        PlasmaComponents.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.label
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
    PlasmaComponents.Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(0, (parent.height - gauge.side) / 2)
        text: gauge.detail
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
