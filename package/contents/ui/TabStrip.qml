/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The drawer's tabs: icon buttons on a soft track, with a pill that slides to the current one
// (as in Caelestia's dashboard).
Item {
    id: strip

    property var tabs: []
    property int currentIndex: 0
    property string badgeKey: ""
    property bool hoverSwitch: false

    signal activated(string key)

    implicitHeight: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing * 2

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
    }

    readonly property real cellWidth: tabs.length > 0 ? width / tabs.length : width

    // The pill under the current tab: it stretches towards the new tab first, then catches up
    Rectangle {
        id: pill
        readonly property real targetX: strip.currentIndex * strip.cellWidth
        property real lo: targetX
        property real hi: targetX + strip.cellWidth
        x: lo + 3
        y: 3
        width: Math.max(0, hi - lo - 6)
        height: parent.height - 6
        radius: height / 2
        color: Kirigami.Theme.highlightColor
        onTargetXChanged: {
            const forward = targetX > lo;
            leftAnim.duration = forward ? Kirigami.Units.veryLongDuration : Kirigami.Units.longDuration;
            rightAnim.duration = forward ? Kirigami.Units.longDuration : Kirigami.Units.veryLongDuration;
            lo = targetX;
            hi = targetX + strip.cellWidth;
        }
        Behavior on lo {
            NumberAnimation { id: leftAnim; easing.type: Easing.OutCubic }
        }
        Behavior on hi {
            NumberAnimation { id: rightAnim; easing.type: Easing.OutCubic }
        }
    }

    Timer {
        id: dwell
        property string key
        interval: 150
        onTriggered: strip.activated(key)
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: strip.tabs
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool current: index === strip.currentIndex
                width: strip.cellWidth
                height: strip.height

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: cell.modelData.icon
                    isMask: true
                    color: cell.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: cell.current || hover.hovered ? 1 : 0.7
                    scale: tap.pressed ? 0.85 : 1
                    Behavior on scale {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.longDuration }
                    }
                }
                Rectangle {
                    visible: strip.badgeKey === cell.modelData.key
                    width: Kirigami.Units.smallSpacing * 2
                    height: width
                    radius: width / 2
                    x: parent.width / 2 + Kirigami.Units.iconSizes.smallMedium / 2 - width / 2
                    y: parent.height / 2 - Kirigami.Units.iconSizes.smallMedium / 2 - height / 2
                    color: cell.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.highlightColor
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: {
                        if (hovered && strip.hoverSwitch && !cell.current) {
                            dwell.key = cell.modelData.key;
                            dwell.restart();
                        } else if (!hovered && dwell.key === cell.modelData.key) {
                            dwell.stop();
                        }
                    }
                }
                TapHandler {
                    id: tap
                    onTapped: strip.activated(cell.modelData.key)
                }
                PlasmaComponents.ToolTip.text: cell.modelData.label
                PlasmaComponents.ToolTip.visible: hover.hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
