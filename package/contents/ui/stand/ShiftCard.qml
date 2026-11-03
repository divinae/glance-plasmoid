import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"
import "../tiles"

// Shift in a compact card, for the tab it shares with Focus: the posture beside where you are
// and what's next, the time to the switch as a line, Sit / Stand, snooze or pause, and the desk in a line (with what to do
// when it's out of reach or retrying). Over Shift's controller (`root`).
Tile {
    id: card

    required property Item root
    // The Focus controller when it's on: a switch nearly due waits for its break
    property var focusTimer: null
    readonly property var settings: root.settings
    readonly property var d: root.deskDriver

    implicitHeight: column.implicitHeight + 2 * padding

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // The posture as an icon: the timer beside it already has the tab's ring
            // The posture in a soft round badge (amber when a switch is due)
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: Qt.alpha(card.root.switchDue ? "#c9a227" : card.root.themeTextColor, card.root.switchDue ? 0.25 : 0.08)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: card.root.postureIcon
                    isMask: true
                    color: card.root.themeTextColor
                    opacity: card.root.idle ? 0.5 : 1
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: card.root.statusText()
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.settings.stand_focus_sync_enabled && card.focusTimer && card.focusTimer.active
                            && !card.focusTimer.isBreak() && !card.root.idle && !card.root.switchDue
                            && card.root.remainingMs <= 10 * 60 * 1000
                        ? i18n("Switches at the next break") : card.root.countdownText()
                    color: card.root.themeDimColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        // Time to the next switch, as a line
        Item {
            id: line
            Layout.fillWidth: true
            implicitHeight: 4
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: card.root.themeTrackColor
            }
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Cycle.progress(card.root.cycle, card.root.cfg)))
                height: parent.height
                radius: height / 2
                color: card.root.switchDue ? "#c9a227" : card.root.ringColor
                opacity: card.root.idle ? 0.5 : 1
                Behavior on width {
                    NumberAnimation { duration: Kirigami.Units.longDuration }
                }
            }
            // The desk on its way: a sweep along the line
            Rectangle {
                visible: card.d.moving
                width: parent.width * 0.25
                height: parent.height
                radius: height / 2
                color: card.root.ringColor
                opacity: 0.6
                SequentialAnimation on x {
                    running: card.d.moving
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: line.width * 0.75; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: line.width * 0.75; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: card.root.pendingPosition !== ""
            type: Kirigami.MessageType.Information
            text: card.root.pendingPosition === "stand"
                ? i18n("The desk is not reachable. Raise it with its own buttons, then confirm.")
                : i18n("The desk is not reachable. Lower it with its own buttons, then confirm.")
            actions: [
                Kirigami.Action {
                    text: i18n("Done")
                    icon.name: "dialog-ok"
                    onTriggered: card.root.confirmPending()
                },
                Kirigami.Action {
                    text: i18n("Cancel")
                    icon.name: "dialog-cancel"
                    onTriggered: card.root.cancelPending()
                }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Sit | Stand as one segmented control, where you are lit. Offline they say where you
            // are rather than ask the desk to go there.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: segments.implicitHeight + 4
                radius: height / 2
                color: Qt.alpha(card.root.themeTextColor, 0.07)

                component Segment: PlasmaComponents.ToolButton {
                    id: segment
                    property string position
                    Layout.fillWidth: true
                    readonly property bool here: card.root.cycle.position === position
                    icon.source: Qt.resolvedUrl(position === "stand" ? "icons/person-stand.svg" : "icons/person-sit.svg")
                    icon.color: card.root.themeTextColor
                    enabled: !card.d.moving
                    background: Rectangle {
                        radius: height / 2
                        color: segment.here ? Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
                            : segment.hovered ? Qt.alpha(card.root.themeTextColor, 0.08) : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }
                    font.weight: here ? Font.DemiBold : Font.Normal
                    onClicked: card.root.deskOffline ? card.root.setPosition(position) : card.root.goTo(position)
                }

                RowLayout {
                    id: segments
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2
                    Segment {
                        position: "sit"
                        text: card.root.deskOffline ? i18n("I'm sitting") : i18n("Sit")
                    }
                    Segment {
                        position: "stand"
                        text: card.root.deskOffline ? i18n("I'm standing") : i18n("Stand")
                    }
                }
            }
            PlasmaComponents.ToolButton {
                visible: card.root.switchDue
                icon.name: "chronometer-pause"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Snooze %1 min", card.settings.stand_snooze_minutes)
                onClicked: card.root.snooze()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PlasmaComponents.ToolButton {
                visible: card.root.status === "paused"
                icon.name: "media-playback-start"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Resume")
                onClicked: card.root.resume()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PlasmaComponents.ToolButton {
                id: pauseButton
                visible: card.root.status !== "paused"
                icon.name: "media-playback-pause"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Pause…")
                onClicked: pauseMenu.open()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered && !pauseMenu.visible
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                PlasmaComponents.Menu {
                    id: pauseMenu
                    y: pauseButton.height
                    PlasmaComponents.MenuItem {
                        text: i18n("For 30 minutes")
                        onTriggered: card.root.pause(30)
                    }
                    PlasmaComponents.MenuItem {
                        text: i18n("For 1 hour")
                        onTriggered: card.root.pause(60)
                    }
                    PlasmaComponents.MenuItem {
                        text: i18n("For 2 hours")
                        onTriggered: card.root.pause(120)
                    }
                    PlasmaComponents.MenuItem {
                        text: i18n("Until I resume")
                        onTriggered: card.root.pause(0)
                    }
                }
            }
        }

        // ---- the desk, in a line ----------------------------------------------------------
        Rectangle {
            visible: card.root.deskEnabled
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            implicitHeight: 1
            color: Kirigami.Theme.textColor
            opacity: 0.12
        }
        RowLayout {
            visible: card.root.deskEnabled
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            readonly property bool known: !isNaN(card.d.heightCm)
            readonly property real sit: card.settings.stand_sit_height_cm
            readonly property real standH: card.settings.stand_stand_height_cm
            readonly property string at: !known ? ""
                : Math.abs(card.d.heightCm - sit) <= 2 ? "sit"
                : Math.abs(card.d.heightCm - standH) <= 2 ? "stand" : "between"

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "zoom-fit-height-symbolic"
            }
            PlasmaComponents.Label {
                visible: parent.known
                text: i18nc("desk height", "%1 cm", Math.round(card.d.heightCm))
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: !card.d.reachable && !card.d.moving ? i18n("Desk not reachable")
                    : card.d.moving && card.d.attempt > 1 ? i18n("Stopped short, trying again (%1 of %2)", card.d.attempt, card.d.maxAttempts)
                    : card.d.moving ? (card.d.target === "stand" ? i18n("Rising to standing…") : i18n("Lowering to sitting…"))
                    : parent.at === "sit" ? i18n("At sitting height")
                    : parent.at === "stand" ? i18n("At standing height")
                    : parent.at === "between" ? i18n("Between the two heights")
                    : i18n("Height not read yet")
                color: !card.d.reachable && !card.d.moving ? Kirigami.Theme.negativeTextColor : card.root.themeDimColor
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            PlasmaComponents.ToolButton {
                visible: !card.d.moving
                enabled: !card.d.reading
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: card.d.reachable ? i18n("Read the height again") : i18n("Try again")
                onClicked: card.d.readHeight()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PlasmaComponents.ToolButton {
                visible: card.d.moving && card.d.attempt > 1
                icon.name: "process-stop"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Stop retrying")
                onClicked: card.d.cancel()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
