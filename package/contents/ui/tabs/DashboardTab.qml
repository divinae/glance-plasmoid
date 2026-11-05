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
//   clock, today's events | CPU·RAM·disk | media
//   user and system       | notifications · focus/shift · shelf
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
    readonly property bool showControls: island.cfg.showDevices

    columns: 2
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

            // The time at the top (the weather small at its right, from Event Calendar), today's
            // agenda under it, who and what at the bottom
            Item {
                Layout.fillWidth: true
                implicitHeight: clock.implicitHeight

                ClockTile {
                    id: clock
                    anchors.fill: parent
                    anchors.rightMargin: weather.visible ? weather.width : 0
                    color: "transparent"
                    padding: 0
                    alignTop: true
                    timeScale: 3.6
                }
                WeatherLine {
                    id: weather
                    // On the time's line, in its middle
                    anchors.right: parent.right
                    y: clock.timeItem.y + (clock.timeItem.height - height) / 2
                    visible: tab.island.cfg.calendarEnabled && tab.calendar.weather !== null
                    weather: tab.calendar.weather || ({})
                    onClicked: tab.island.openEventCalendar(null)
                }
            }
            // Under the date, between it and the agenda: the same line as above who-and-what
            Rectangle {
                visible: tab.showAgenda
                Layout.fillWidth: true
                implicitHeight: 1
                color: Kirigami.Theme.textColor
                opacity: 0.12
            }
            // What's next today, from Event Calendar (the month itself is Event Calendar's)
            AgendaTile {
                visible: tab.showAgenda
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                padding: 0
                calendar: tab.calendar
                maxEvents: 4
                // The calendar itself is Event Calendar's: its popup opens
                onEventClicked: ev => tab.island.openEventCalendar(ev)
            }
            Item {
                visible: !tab.showAgenda
                Layout.fillHeight: true
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
    // ---- controls, system, notifications: notifications take what the other two leave ----
    RowLayout {
        visible: tab.showSystem || tab.showNotifications || tab.showControls
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        spacing: Kirigami.Units.largeSpacing

        // Bluetooth, Wi-Fi…, the brightness, the batteries in rings
        DevicesTile {
            visible: tab.showControls
            Layout.fillWidth: !tab.showNotifications
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            island: tab.island
            onClicked: tab.openTab("devices")
        }
        ResourcesTile {
            visible: tab.showSystem
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            monitor: tab.monitor
            onClicked: tab.openTab("system")
        }
        NotificationsTile {
            visible: tab.showNotifications
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            watcher: tab.notifications
            onClicked: tab.openTab("notifications")
        }
    }

    // ---- music, focus, stand, shelf ------------------------------------------------------
    // Music gets most of the room, the shelf what it needs
    RowLayout {
        visible: (tab.showMedia && tab.island.hasPlayer) || tab.showShelf || !!tab.island.stand || !!tab.island.focusTimer
        Layout.fillWidth: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 7
        Layout.fillHeight: true
        spacing: Kirigami.Units.largeSpacing

        // Only with a player: an empty "Nothing playing" card gives its room to Focus and Stand
        MediaTile {
            visible: tab.showMedia && tab.island.hasPlayer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            island: tab.island
            cava: tab.cava
            mediaState: tab.mediaState
            onOpenMedia: tab.openTab("media")
        }
        // Focus and Stand share a card, one row each
        WorkTile {
            visible: !!tab.island.focusTimer || !!tab.island.stand
            Layout.fillWidth: !(tab.showMedia && tab.island.hasPlayer) && !tab.showShelf
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10.5
            timer: tab.island.focusTimer
            stand: tab.island.stand
            onOpenTab: key => tab.openTab(key)
        }
        ShelfTile {
            visible: tab.showShelf
            Layout.fillWidth: !(tab.showMedia && tab.island.hasPlayer)
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            island: tab.island
            onClicked: tab.openTab("shelf")
        }
    }
}
