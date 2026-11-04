/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// A round cover that keeps the last one until the next has loaded, then crossfades: swapping one
// image's source showed the placeholder for as long as the new one took (long for Spotify's
// covers, fetched over https). Two RoundedImages take turns.
//
// `ready`: a cover is shown. `accent`: a colour from it for the controls (the theme's highlight
// when there's none, or it's too close to the background to read).
Item {
    id: root

    property url source
    property size sourceSize
    property real radius: width / 2

    readonly property bool ready: front.status === Image.Ready && front.source.toString() !== ""
    readonly property color accent: {
        if (!ready || colors.highlight === undefined) {
            return Kirigami.Theme.highlightColor;
        }
        const c = colors.highlight;
        // Too faint against the card (a near-white or near-black cover): the theme's own
        const bg = Kirigami.Theme.backgroundColor;
        const contrast = Math.abs(luminance(c) - luminance(bg));
        return contrast < 0.25 ? Kirigami.Theme.highlightColor : c;
    }
    // What reads on the accent: dark text on a light one
    readonly property color onAccent: luminance(accent) > 0.6 ? "#202020" : "white"

    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    property bool aInFront: true
    readonly property Item front: aInFront ? a : b
    readonly property Item back: aInFront ? b : a

    onSourceChanged: {
        if (source.toString() === "") {
            a.source = "";
            b.source = "";
            return;
        }
        if (front.source === source) {
            // Back to the one shown: drop what was loading, so it can't swap in later
            back.source = "";
            return;
        }
        if (back.source === source) {
            // Already loaded there (switched back and forth): no statusChanged will come
            if (back.status === Image.Ready) {
                aInFront = !aInFront;
            }
            return;
        }
        back.source = source;
    }
    Component.onCompleted: a.source = source

    function swapIfReady(img) {
        if (img === back && img.status === Image.Ready && img.source === source) {
            aInFront = !aInFront;
        } else if (img === back && img.status === Image.Error) {
            // No new cover: not the last track's either
            front.source = "";
        }
    }

    RoundedImage {
        id: a
        anchors.fill: parent
        radius: root.radius
        sourceSize: root.sourceSize
        opacity: root.aInFront ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration }
        }
        onStatusChanged: root.swapIfReady(a)
    }
    RoundedImage {
        id: b
        anchors.fill: parent
        radius: root.radius
        sourceSize: root.sourceSize
        opacity: root.aInFront ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration }
        }
        onStatusChanged: root.swapIfReady(b)
    }

    Kirigami.ImageColors {
        id: colors
        source: root.ready ? root.front.source : ""
        onSourceChanged: update()
    }
}
