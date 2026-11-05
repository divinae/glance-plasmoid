/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

import org.kde.kirigami as Kirigami

// The cover, blurred, behind a card (as macOS's Now Playing): soft and faint, darkened on a dark
// theme and lightened on a light one so the text keeps reading; fades with the cover.
Item {
    id: root
    // Never past its card: the blur pads itself outward by its radius, and spilled over the
    // dashboard's other cards
    clip: true

    property url source
    property bool shown: true
    property real radius: 0
    // How much of it shows: the Media tab more, the dashboard's card a touch
    property real strength: 0.45

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(128, 128) // blurred anyway: small is enough, and cheap
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        readonly property bool on: root.shown && root.source.toString() !== "" && image.status === Image.Ready
        visible: opacity > 0
        opacity: on ? root.strength : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration }
        }
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        saturation: 0.2
        brightness: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ? -0.35 : 0.35
        maskEnabled: true
        maskSource: mask
    }
}
