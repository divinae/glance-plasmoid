/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../tiles"
import "../common"
import "../focus" as Focus
import "../stand" as Stand

// Focus and Shift in one tab, as they work together (Shift waits for the focus breaks):
//
//   timer           | posture, Sit / Stand, the desk
//   Skip Start Stop | [Focus | Posture] stats
GridLayout {
    id: tab

    required property var focusTimer
    required property var stand

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    Focus.FocusTimerCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.rowSpan: 2
        root: tab.focusTimer
    }

    Stand.ShiftCard {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        root: tab.stand
        focusTimer: tab.focusTimer
    }

    // One card for the figures, Focus's or Shift's
    Tile {
        id: statsCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        property int page: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                // Pages of the card: tabs, not buttons
                CardTabs {
                    tabs: [
                        {label: i18n("Focus"), icon: "chronometer-symbolic"},
                        {label: i18n("Posture"), icon: Qt.resolvedUrl("../stand/icons/person-stand.svg")}
                    ]
                    currentIndex: statsCard.page
                    onActivated: index => statsCard.page = index
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: statsCard.page

                Focus.FocusStats {
                    root: tab.focusTimer
                }
                Stand.ShiftHistory {
                    root: tab.stand
                }
            }
        }
    }
}
