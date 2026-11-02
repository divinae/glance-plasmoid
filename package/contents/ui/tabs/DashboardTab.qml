/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../tiles"

// The first tab, after Caelestia's dashboard:
//
//   clock | today's events     | CPU·RAM·disk | media
//   user and system           | notifications | shelf
// (the window's menus and buttons are in the menu bar along the top of the drawer)
GridLayout {
    id: tab

    required property var island
    required property Item tasks
    required property QtObject appMenu
    required property QtObject cava
    required property Item mediaState
    required property Item notifications
    required property Item calendar
    required property Item monitor

    signal openTab(string key)

    readonly property bool showMedia: island.cfg.showMedia
    readonly property bool showAgenda: island.cfg.calendarEnabled && calendar.available
    readonly property bool showNotifications: island.cfg.showNotifications
    readonly property bool showShelf: island.cfg.showShelf
    readonly property bool showSystem: island.cfg.showSystem

    columns: 4
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    // ---- top row ------------------------------------------------------------------
    ClockTile {
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        Layout.fillWidth: true
    }
    // What's next today, from Event Calendar (the month itself is Event Calendar's)
    AgendaTile {
        visible: tab.showAgenda
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        calendar: tab.calendar
        maxEvents: 5
        onClicked: tab.openTab("agenda")
    }
    ResourcesTile {
        visible: tab.showSystem
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        monitor: tab.monitor
        onClicked: tab.openTab("system")
    }
    MediaTile {
        visible: tab.showMedia
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
        // Takes the places of what's hidden in this row, so it never leaves a gap
        Layout.columnSpan: 1 + (tab.showAgenda ? 0 : 1) + (tab.showSystem ? 0 : 1)
        island: tab.island
        cava: tab.cava
        mediaState: tab.mediaState
        onOpenMedia: tab.openTab("media")
    }

    // ---- who and what, notifications, shelf ---------------------------------------------
    InfoTile {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
        Layout.columnSpan: 2
    }
    NotificationsTile {
        visible: tab.showNotifications
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
        Layout.columnSpan: tab.showShelf ? 1 : 2
        watcher: tab.notifications
        onClicked: tab.openTab("notifications")
    }
    ShelfTile {
        visible: tab.showShelf
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
        Layout.columnSpan: tab.showNotifications ? 1 : 2
        island: tab.island
        onClicked: tab.openTab("shelf")
    }

}
