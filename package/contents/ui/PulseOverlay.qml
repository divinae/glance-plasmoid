/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// Short double flash over the panel strip for a new notification.
Rectangle {
    id: overlay

    function flash(c: color) {
        overlay.color = c;
        anim.restart();
    }

    radius: Kirigami.Units.cornerRadius
    opacity: 0
    visible: opacity > 0

    SequentialAnimation {
        id: anim
        NumberAnimation { target: overlay; property: "opacity"; to: 0.65; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: overlay; property: "opacity"; to: 0.1; duration: 260; easing.type: Easing.InQuad }
        NumberAnimation { target: overlay; property: "opacity"; to: 0.55; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: overlay; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InQuad }
    }
}
