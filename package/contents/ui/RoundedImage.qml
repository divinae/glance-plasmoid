/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

// An image with rounded corners (radius: half the side for a circle), cropped to fill. The image
// itself stays hidden and is drawn through a mask: handed to ShadowedTexture inline instead, it
// drew itself too, uncropped, at its own size.
Item {
    id: root

    property alias source: image.source
    property alias status: image.status
    property alias sourceSize: image.sourceSize
    property real radius: 0

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    // The mask at twice the size and smoothed, read with a soft threshold: a hard-edged mask
    // left the round covers' edge jagged
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * 2, height * 2)
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        visible: image.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
