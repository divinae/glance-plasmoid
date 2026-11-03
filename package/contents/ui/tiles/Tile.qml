/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// A rounded card on the dashboard, a shade off the drawer's surface. Clickable ones light up
// under the pointer and send `clicked` (usually: open the matching tab).
Rectangle {
    id: tile

    default property alias contentData: inner.data
    property bool clickable: false
    property real padding: Kirigami.Units.largeSpacing

    signal clicked()

    radius: Kirigami.Units.cornerRadius * 2.5
    color: Qt.alpha(Kirigami.Theme.textColor, clickable && hover.hovered ? 0.1 : 0.06)
    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.shortDuration }
    }
    scale: clickable && tap.pressed ? 0.98 : 1
    Behavior on scale {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack }
    }

    HoverHandler {
        id: hover
        cursorShape: tile.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        id: tap
        enabled: tile.clickable
        onTapped: tile.clicked()
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: tile.padding
    }
}
