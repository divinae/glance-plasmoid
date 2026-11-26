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
    // limits are wide, so its edges can be dragged. The size the user drags it to is kept
    // (flyoutWidth/flyoutHeight) and it opens at that size next time
    readonly property int savedWidth: island.cfg.flyoutWidth > 0 ? island.cfg.flyoutWidth : 26
    readonly property int savedHeight: island.cfg.flyoutHeight > 0 ? island.cfg.flyoutHeight : island.cfg.popupHeight
    readonly property real startHeight: Kirigami.Units.gridUnit * savedHeight

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * savedWidth
    Layout.maximumWidth: Kirigami.Units.gridUnit * 100
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredHeight: startHeight
    Layout.maximumHeight: Kirigami.Units.gridUnit * 80

    HoverHandler {
        onHoveredChanged: flyout.island.flyoutHovered = hovered
    }

    // Dragged to a new size: kept, in whole grid units, once the dragging has settled. Only a
    // size that differs from the one it was given: opening, or the tabs, don't count
    onWidthChanged: sizeSaver.restart()
    onHeightChanged: sizeSaver.restart()
    Timer {
        id: sizeSaver
        interval: 600
        onTriggered: {
            const gu = Kirigami.Units.gridUnit;
            if (!flyout.visible || flyout.width < gu * 10 || flyout.height < gu * 8) {
                return;
            }
            const w = Math.max(16, Math.min(100, Math.round(flyout.width / gu)));
            const h = Math.max(12, Math.min(80, Math.round(flyout.height / gu)));
            if (w !== flyout.savedWidth) {
                flyout.island.cfg.flyoutWidth = w;
            }
            if (h !== flyout.savedHeight) {
                flyout.island.cfg.flyoutHeight = h;
            }
        }
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
