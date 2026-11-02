/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../tiles"

// The first tab: a grid of tiles, each a glance at one of the other tabs.
//
//   clock          | media (2 rows)
//   agenda         |
//   notifications  | shelf
//   window (both columns)
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

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    ClockTile {
        monitor: tab.island.cfg.showSystem ? tab.monitor : null
        clickable: tab.island.cfg.showSystem
        onClicked: tab.openTab("system")
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.columnSpan: tab.showMedia ? 1 : 2
        Layout.rowSpan: tab.showAgenda ? 1 : 2
        Layout.preferredWidth: 1
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4
    }
    MediaTile {
        visible: tab.showMedia
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.rowSpan: 2
        Layout.preferredWidth: 1
        island: tab.island
        cava: tab.cava
        mediaState: tab.mediaState
        onOpenMedia: tab.openTab("media")
    }
    AgendaTile {
        visible: tab.showAgenda
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.columnSpan: tab.showMedia ? 1 : 2
        Layout.preferredWidth: 1
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4
        calendar: tab.calendar
        onClicked: tab.openTab("agenda")
    }
    NotificationsTile {
        visible: tab.showNotifications
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.columnSpan: tab.showShelf ? 1 : 2
        Layout.preferredWidth: 1
        Layout.minimumHeight: Kirigami.Units.gridUnit * 3.5
        watcher: tab.notifications
        onClicked: tab.openTab("notifications")
    }
    ShelfTile {
        visible: tab.showShelf
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.columnSpan: tab.showNotifications ? 1 : 2
        Layout.preferredWidth: 1
        Layout.minimumHeight: Kirigami.Units.gridUnit * 3.5
        island: tab.island
        onClicked: tab.openTab("shelf")
    }
    WindowTile {
        Layout.fillWidth: true
        Layout.columnSpan: 2
        island: tab.island
        tasks: tab.tasks
        appMenu: tab.appMenu
    }
}
