/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../focus" as Focus
import "../stand"
import "../stand/lib/cycle.js" as Cycle

// Focus and Shift in one card, a row each (whichever is on): a small ring, two lines and a
// button (start/pause; sit/stand). A row opens its tab; a switch that's due tints the edge.
Tile {
    id: tile

    property var timer: null
    property var stand: null
    readonly property bool hasTimer: timer !== null && timer !== undefined
    readonly property bool hasStand: stand !== null && stand !== undefined
    readonly property real ring: Kirigami.Units.gridUnit * 2.4

    signal openTab(string key)

    border.width: hasStand && stand.switchDue ? 2 : 0
    border.color: "#c9a227"

    component WorkRow: Item {
        id: row
        property string key
        default property alias ringData: ringSlot.data
        // A button at the row's end
        property alias trailing: trailSlot.data
        property string title
        property string detail
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: tile.ring

        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: tile.openTab(row.key)
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Kirigami.Units.smallSpacing
            radius: Kirigami.Units.cornerRadius * 1.5
            color: Qt.alpha(Kirigami.Theme.textColor, rowHover.hovered ? 0.06 : 0)
        }
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing * 2
            Item {
                id: ringSlot
                Layout.preferredWidth: tile.ring
                Layout.preferredHeight: tile.ring
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: row.title
                    textFormat: Text.PlainText
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: row.detail
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
            Item {
                id: trailSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        WorkRow {
            visible: tile.hasTimer
            key: "focus"
            title: !tile.hasTimer ? "" : tile.timer.settings.focus_task_label && !tile.timer.isBreak()
                ? tile.timer.settings.focus_task_label : i18n("Focus")
            detail: !tile.hasTimer ? "" : tile.timer.active ? tile.timer.statusText
                : i18n("%1 · ready", tile.timer.panelTimeText)
            // Start, pause, or take the break (flowmodoro), as the Focus tab's main button
            trailing: PlasmaComponents.ToolButton {
                visible: tile.hasTimer
                icon.name: tile.hasTimer ? tile.timer.sessionBtnIconSource : ""
                display: PlasmaComponents.AbstractButton.IconOnly
                text: tile.hasTimer ? tile.timer.sessionBtnText.replace("&", "") : ""
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: tile.timer.toggleSession()
            }

            Focus.ProgressCircle {
                anchors.fill: parent
                size: tile.ring
                lineWidth: Kirigami.Units.smallSpacing * 0.75
                arcBegin: 0
                arcEnd: tile.hasTimer ? 360 * tile.timer.progressFraction() : 0
                showBackground: true
                colorCircle: tile.hasTimer ? tile.timer.getCircleColor() : "transparent"

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: tile.hasTimer && tile.timer.active
                    text: tile.hasTimer ? tile.timer.panelTimeText : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    visible: tile.hasTimer && !tile.timer.active
                    width: parent.width * 0.42
                    height: width
                    source: "chronometer-symbolic"
                    opacity: 0.6
                }
            }
        }

        Rectangle {
            visible: tile.hasTimer && tile.hasStand
            Layout.fillWidth: true
            implicitHeight: 1
            color: Kirigami.Theme.textColor
            opacity: 0.12
        }

        WorkRow {
            visible: tile.hasStand
            key: "stand"
            title: tile.hasStand ? tile.stand.statusText() : ""
            detail: tile.hasStand ? tile.stand.countdownText() : ""
            // Switch now (the desk moves when it's controlled); Done for a switch waiting on you
            trailing: PlasmaComponents.ToolButton {
                readonly property bool standing: tile.hasStand && tile.stand.cycle.position === "stand"
                readonly property bool pending: tile.hasStand && tile.stand.pendingPosition !== ""
                visible: tile.hasStand
                icon.name: pending ? "dialog-ok-apply-symbolic" : standing ? "go-down-symbolic" : "go-up-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: pending ? i18n("Done") : standing ? i18n("Sit Down") : i18n("Stand Up")
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    if (pending) {
                        tile.stand.confirmPending();
                    } else {
                        tile.stand.goTo(standing ? "sit" : "stand");
                    }
                }
            }

            ProgressCircle {
                anchors.fill: parent
                size: tile.ring
                lineWidth: Kirigami.Units.smallSpacing * 0.75
                arcBegin: 0
                arcEnd: tile.hasStand ? 360 * Cycle.progress(tile.stand.cycle, tile.stand.cfg) : 0
                showBackground: true
                colorCircle: !tile.hasStand ? "transparent" : tile.stand.switchDue ? "#c9a227" : tile.stand.ringColor
                colorBackground: tile.hasStand ? tile.stand.themeTrackColor : "transparent"
                indeterminate: tile.hasStand && tile.stand.deskDriver.moving

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    source: tile.hasStand ? tile.stand.postureIcon : ""
                    isMask: true
                    color: tile.hasStand ? tile.stand.themeTextColor : "transparent"
                    opacity: tile.hasStand && tile.stand.idle ? 0.5 : 1
                }
            }
        }
    }
}
