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
//   clock    | today's events | CPU·RAM·disk | media
//   user and | notifications · focus · stand · shelf
//   system   |
// (the window's menus and buttons are in the menu bar along the top of the drawer)
GridLayout {
    id: tab

    required property var island
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

    // ---- the clock, and who and what: one card down both rows --------------------------
    Tile {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
        Layout.rowSpan: 2

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            // The time at the top, who and what at the bottom
            ClockTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                padding: 0
                alignTop: true
                timeScale: 3.6
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Kirigami.Theme.textColor
                opacity: 0.12
            }
            InfoTile {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 7.5
                color: "transparent"
                padding: 0
            }
        }
    }
    // What's next today, from Event Calendar (the month itself is Event Calendar's)
    AgendaTile {
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        visible: tab.showAgenda
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        calendar: tab.calendar
        maxEvents: 5
        onClicked: tab.openTab("agenda")
    }
    ResourcesTile {
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        visible: tab.showSystem
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        monitor: tab.monitor
        onClicked: tab.openTab("system")
    }
    MediaTile {
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
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

    // ---- notifications, focus, stand, shelf ---------------------------------------------
    // Notifications get most of the room, the shelf what it needs
    RowLayout {
        visible: tab.showNotifications || tab.showShelf || !!tab.island.stand || !!tab.island.focusTimer
        Layout.fillWidth: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 7
        Layout.fillHeight: true
        Layout.columnSpan: 3
        spacing: Kirigami.Units.largeSpacing

        NotificationsTile {
            visible: tab.showNotifications
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            watcher: tab.notifications
            onClicked: tab.openTab("notifications")
        }
        // Focus and Stand share a card, one row each
        WorkTile {
            visible: !!tab.island.focusTimer || !!tab.island.stand
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10.5
            timer: tab.island.focusTimer
            stand: tab.island.stand
            onOpenTab: key => tab.openTab(key)
        }
        ShelfTile {
            visible: tab.showShelf
            Layout.fillWidth: !tab.showNotifications
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            island: tab.island
            onClicked: tab.openTab("shelf")
        }
    }
}
