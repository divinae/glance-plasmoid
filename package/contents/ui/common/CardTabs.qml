/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Pages inside a card (Focus | Posture): tabs, not buttons. Icon and text, the others dimmed,
// an accent line sliding under the current one. `tabs`: [{label, icon}] (icon a name or a URL).
Item {
    id: bar

    property var tabs: []
    property int currentIndex: 0
    signal activated(int index)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + line.height + 2

    Row {
        id: row
        spacing: Kirigami.Units.largeSpacing * 2

        Repeater {
            id: repeater
            model: bar.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: index === bar.currentIndex
                implicitWidth: content.implicitWidth
                implicitHeight: content.implicitHeight + Kirigami.Units.smallSpacing
                // Reachable with Tab, switched with Space or Enter, a page tab to screen readers
                activeFocusOnTab: true
                Keys.onSpacePressed: bar.activated(index)
                Keys.onReturnPressed: bar.activated(index)
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.onPressAction: bar.activated(index)

                Row {
                    id: content
                    spacing: Kirigami.Units.smallSpacing
                    opacity: tab.current || hover.hovered || tab.activeFocus ? 1 : 0.6
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: tab.modelData.icon
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                    }
                }
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: bar.activated(tab.index)
                }
            }
        }
    }

    // Under the current tab, as wide as it
    Rectangle {
        id: line
        readonly property Item target: repeater.count > bar.currentIndex ? repeater.itemAt(bar.currentIndex) : null
        y: row.height + 2
        x: target ? target.x : 0
        width: target ? target.width : 0
        height: 2
        radius: 1
        color: Kirigami.Theme.highlightColor
        Behavior on x {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }
}
