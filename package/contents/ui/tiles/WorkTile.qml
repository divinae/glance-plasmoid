/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"
import "../stand/lib/cycle.js" as Cycle

// Focus and Shift in one card, a row each (whichever is on), alike: a badge, two lines with a
// progress line under them, and a button (start/pause; sit/stand). A row opens its tab; a switch that's due tints the edge.
Tile {
    id: tile

    property var timer: null
    property var stand: null
    readonly property bool hasTimer: timer !== null && timer !== undefined
    readonly property bool hasStand: stand !== null && stand !== undefined
    readonly property real ring: Kirigami.Units.gridUnit * 2

    signal openTab(string key)

    border.width: hasStand && stand.switchDue ? 2 : 0
    border.color: "#c9a227"

    // A round, softly tinted badge with the row's icon; tinted stronger when it asks for you
    component Badge: Rectangle {
        property string iconSource
        property color tint: Kirigami.Theme.textColor
        property bool lit: false
        anchors.centerIn: parent
        width: tile.ring * 0.92
        height: width
        radius: width / 2
        color: Qt.alpha(tint, lit ? 0.25 : 0.08)
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            source: parent.iconSource
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }

    component WorkRow: Item {
        id: row
        property string key
        default property alias ringData: ringSlot.data
        // A button at the row's end
        property alias trailing: trailSlot.data
        property string title
        property string detail
        // 0..1 drawn as a line under the text; below 0, none
        property real progress: -1
        property color progressColor: Kirigami.Theme.highlightColor
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
            spacing: Kirigami.Units.smallSpacing * 1.5
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
                Item {
                    visible: row.progress >= 0
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing / 2
                    implicitHeight: 3
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    }
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, row.progress))
                        height: parent.height
                        radius: height / 2
                        color: row.progressColor
                    }
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
            // "24:31 · focus" while it runs; ready, with the length a pomodoro will run
            detail: !tile.hasTimer ? ""
                : tile.timer.active || tile.timer.paused
                    ? i18nc("time left · kind of session", "%1 · %2", tile.timer.panelTimeText, tile.timer.statusText)
                : tile.timer.flowmodoroModeEnabled ? i18n("Ready")
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

            // A flow counts up with no end: an empty line rather than a full one
            progress: !tile.hasTimer ? -1
                : tile.timer.flowmodoroModeEnabled && !tile.timer.isBreak() ? 0
                : tile.timer.progressFraction()
            progressColor: tile.hasTimer ? tile.timer.getCircleColor() : "transparent"

            Badge {
                iconSource: tile.hasTimer && tile.timer.isBreak() ? "chronometer-pause-symbolic" : "chronometer-symbolic"
                tint: Kirigami.Theme.highlightColor
                lit: tile.hasTimer && tile.timer.active
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
            // Short while counting down ("Sit in 11 min"), the full text otherwise
            detail: !tile.hasStand ? ""
                : (tile.stand.status === "sit" || tile.stand.status === "stand") && !tile.stand.focusBreak
                    ? (tile.stand.cycle.position === "stand"
                        ? i18nc("short: sit down in", "Sit in %1", Cycle.formatMinutes(tile.stand.remainingMs))
                        : i18nc("short: stand up in", "Stand in %1", Cycle.formatMinutes(tile.stand.remainingMs)))
                : tile.stand.countdownText()
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

            progress: tile.hasStand ? Cycle.progress(tile.stand.cycle, tile.stand.cfg) : -1
            progressColor: !tile.hasStand ? "transparent" : tile.stand.switchDue ? "#c9a227" : tile.stand.ringColor

            // The posture as a badge (amber when it's time), its time as the line
            Badge {
                iconSource: tile.hasStand ? tile.stand.postureIcon : ""
                tint: tile.hasStand && tile.stand.switchDue ? "#c9a227" : Kirigami.Theme.textColor
                lit: tile.hasStand && tile.stand.switchDue
            }
        }
    }
}
