/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// Thin playback progress line; fills left to right in its own (possibly rotated) frame.
Item {
    id: edge

    property real fraction: 0
    property color color: Kirigami.Theme.highlightColor
    property bool playing: false

    implicitHeight: 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: edge.color
        opacity: 0.18
    }

    Rectangle {
        id: fill
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: height / 2
        color: edge.color
        width: Math.round(edge.fraction * edge.width)
        opacity: edge.playing ? 1 : 0.6
        Behavior on width {
            // glide between the 1 s position polls, but jump on seeks/track changes
            enabled: Math.abs(fill.width - edge.fraction * edge.width) < edge.width * 0.05
            NumberAnimation { duration: 1000; easing.type: Easing.Linear }
        }
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration }
        }
    }
}
