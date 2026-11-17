/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// The classic Plasma popup: used when the drawer is turned off or layer-shell is missing.
Item {
    id: flyout

    required property PlasmoidItem island
    required property Item tasks
    required property QtObject appMenu
    required property QtObject cava
    required property QtObject mpris
    required property Item mediaState
    required property Item notifications
    required property Item calendar
    required property Item monitor

    // A preferred size that doesn't follow the content, so the popup never jumps between tabs; the
    // limits are wide, so its edges can be dragged (Plasma remembers the size the user gives it)
    readonly property real startHeight: Kirigami.Units.gridUnit * island.cfg.popupHeight

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.maximumWidth: Kirigami.Units.gridUnit * 100
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredHeight: startHeight
    Layout.maximumHeight: Kirigami.Units.gridUnit * 80

    HoverHandler {
        onHoveredChanged: flyout.island.flyoutHovered = hovered
    }
    Component.onDestruction: island.flyoutHovered = false

    IslandContent {
        anchors.fill: parent
        island: flyout.island
        tasks: flyout.tasks
        appMenu: flyout.appMenu
        cava: flyout.cava
        mpris: flyout.mpris
        mediaState: flyout.mediaState
        notifications: flyout.notifications
        calendar: flyout.calendar
        monitor: flyout.monitor
    }
}
