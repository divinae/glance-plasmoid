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
//   clock | calendar          | CPU·RAM·disk | media
//   notifications             | shelf
//   window (all across)
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
    // The month needs no events; with Event Calendar's they get dots
    readonly property bool showAgenda: true
    readonly property bool showNotifications: island.cfg.showNotifications
    readonly property bool showShelf: island.cfg.showShelf
    readonly property bool showSystem: island.cfg.showSystem

    columns: 4
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    // ---- top row ------------------------------------------------------------------
    ClockTile {
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        Layout.columnSpan: tab.showAgenda ? 1 : 2
        Layout.fillWidth: !tab.showAgenda
    }
    CalendarTile {
        visible: tab.showAgenda
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        calendar: tab.calendar
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
        Layout.columnSpan: tab.showSystem ? 1 : 2
        island: tab.island
        cava: tab.cava
        mediaState: tab.mediaState
        onOpenMedia: tab.openTab("media")
    }

    // ---- notifications and shelf ------------------------------------------------------
    NotificationsTile {
        visible: tab.showNotifications
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        Layout.columnSpan: tab.showShelf ? 2 : 4
        watcher: tab.notifications
        onClicked: tab.openTab("notifications")
    }
    ShelfTile {
        visible: tab.showShelf
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        Layout.columnSpan: tab.showNotifications ? 2 : 4
        island: tab.island
        onClicked: tab.openTab("shelf")
    }

    // ---- the window ------------------------------------------------------------------------
    WindowTile {
        Layout.fillWidth: true
        Layout.columnSpan: 4
        island: tab.island
        tasks: tab.tasks
        appMenu: tab.appMenu
    }
}
