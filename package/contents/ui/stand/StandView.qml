import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
import "../common"
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../tiles"

// The Stand tab, in Glance's cards: where you are and what's next on the left, today, the week
// and the desk on the right. Over its controller (`root`).
GridLayout {
    id: view

    required property Item root
    readonly property var settings: root.settings

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    // A card with a small heading
    component Card: Tile {
        id: card
        property string title
        default property alias body: column.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: column.implicitHeight + 2 * padding
        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: card.title !== ""
                text: card.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    // ---- where you are, and what's next ---------------------------------------------------
    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.rowSpan: view.root.deskEnabled ? 3 : 2

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Item {
                Layout.fillHeight: true
            }
            ProgressCircle {
                Layout.alignment: Qt.AlignHCenter
                size: Kirigami.Units.gridUnit * 6
                lineWidth: Kirigami.Units.smallSpacing * 1.5
                arcBegin: 0
                arcEnd: 360 * Cycle.progress(root.cycle, root.cfg)
                showBackground: true
                colorCircle: root.ringColor
                colorBackground: root.themeTrackColor
                indeterminate: root.deskDriver.moving

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    source: root.postureIcon
                    isMask: true
                    color: root.themeTextColor
                    opacity: root.idle ? 0.5 : 1
                }
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                level: 3
                text: root.statusText()
                wrapMode: Text.Wrap
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.countdownText()
                color: root.themeDimColor
                wrapMode: Text.Wrap
            }
            Item {
                Layout.fillHeight: true
            }
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.pendingPosition !== ""
                    type: Kirigami.MessageType.Information
                    text: root.pendingPosition === "stand"
                        ? i18n("The desk is not reachable. Raise it with its own buttons, then confirm.")
                        : i18n("The desk is not reachable. Lower it with its own buttons, then confirm.")
                    actions: [
                        Kirigami.Action {
                            text: i18n("Done")
                            icon.name: "dialog-ok"
                            onTriggered: root.confirmPending()
                        },
                        Kirigami.Action {
                            text: i18n("Cancel")
                            icon.name: "dialog-cancel"
                            onTriggered: root.cancelPending()
                        }
                    ]
                }
                RowLayout {
                    Layout.fillWidth: true

                    // Offline, these say where the user is rather than ask the desk to go there,
                    // so a click on one is its own confirmation.
                    PlasmaComponents.Button {
                        Layout.fillWidth: true
                        icon.source: Qt.resolvedUrl("icons/person-sit.svg")
                        icon.color: root.themeTextColor
                        text: root.deskOffline ? i18n("I'm sitting") : i18n("Sit")
                        highlighted: root.cycle.position === "sit"
                        enabled: !root.deskDriver.moving
                        onClicked: root.deskOffline ? root.setPosition("sit") : root.goTo("sit")
                    }

                    PlasmaComponents.Button {
                        Layout.fillWidth: true
                        icon.source: Qt.resolvedUrl("icons/person-stand.svg")
                        icon.color: root.themeTextColor
                        text: root.deskOffline ? i18n("I'm standing") : i18n("Stand")
                        highlighted: root.cycle.position === "stand"
                        enabled: !root.deskDriver.moving
                        onClicked: root.deskOffline ? root.setPosition("stand") : root.goTo("stand")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Button {
                        Layout.fillWidth: true
                        visible: root.switchDue
                        icon.name: "chronometer-pause"
                        text: i18n("Snooze %1 min", settings.stand_snooze_minutes)
                        onClicked: root.snooze()
                    }

                    PlasmaComponents.Button {
                        Layout.fillWidth: true
                        visible: root.status === "paused"
                        icon.name: "media-playback-start"
                        text: i18n("Resume")
                        onClicked: root.resume()
                    }

                    PlasmaComponents.Button {
                        id: pauseButton

                        Layout.fillWidth: true
                        visible: root.status !== "paused"
                        icon.name: "media-playback-pause"
                        text: i18n("Pause…")
                        onClicked: pauseMenu.open()

                        PlasmaComponents.Menu {
                            id: pauseMenu

                            y: pauseButton.height

                            PlasmaComponents.MenuItem {
                                text: i18n("For 30 minutes")
                                onTriggered: root.pause(30)
                            }

                            PlasmaComponents.MenuItem {
                                text: i18n("For 1 hour")
                                onTriggered: root.pause(60)
                            }

                            PlasmaComponents.MenuItem {
                                text: i18n("For 2 hours")
                                onTriggered: root.pause(120)
                            }

                            PlasmaComponents.MenuItem {
                                text: i18n("Until I resume")
                                onTriggered: root.pause(0)
                            }
                        }
                    }
                }
        }
    }

    // ---- today ----------------------------------------------------------------------------
    Card {
        title: i18n("Today")
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.todayText()
            wrapMode: Text.Wrap
        }
        PlasmaComponents.ProgressBar {
            Layout.fillWidth: true
            visible: root.goalMinutes > 0
            from: 0
            to: root.goalMinutes
            value: Math.min(root.todayMinutes, root.goalMinutes)
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.goalMinutes > 0
            text: i18np("Goal met %1 day in a row", "Goal met %1 days in a row", root.streakDays)
            color: root.themeDimColor
            font: Kirigami.Theme.smallFont
        }
    }

    // ---- the week ---------------------------------------------------------------------------
    Card {
        title: i18n("This week")
        WeekChart {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: implicitHeight
            days: root.weekDays
            todayMinutes: root.todayMinutes
            goalMinutes: root.goalMinutes
            barColor: root.themeAccentColor
            trackColor: root.themeTrackColor
            lineColor: root.themeDimColor
            labelColor: root.themeDimColor
        }
    }

    // ---- the desk: its height on a scale between the two positions, where it's going ------
    Card {
        id: deskCard
        visible: view.root.deskEnabled
        title: i18n("Desk")

        readonly property var d: root.deskDriver
        readonly property real sit: settings.stand_sit_height_cm
        readonly property real standH: settings.stand_stand_height_cm
        readonly property bool known: !isNaN(d.heightCm)
        // Within 2 cm of a position counts as there
        readonly property string at: !known ? ""
            : Math.abs(d.heightCm - sit) <= 2 ? "sit"
            : Math.abs(d.heightCm - standH) <= 2 ? "stand" : "between"
        readonly property real lo: Math.min(sit, standH) - 5
        readonly property real hi: Math.max(sit, standH) + 5
        function frac(cm) {
            return Math.max(0, Math.min(1, (cm - lo) / (hi - lo)));
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.Label {
                text: deskCard.known ? i18nc("desk height", "%1 cm", Math.round(deskCard.d.heightCm)) : "—"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                font.weight: Font.Bold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: !deskCard.d.reachable && !deskCard.d.moving ? i18n("Not reachable")
                    : deskCard.d.moving ? (deskCard.d.target === "stand" ? i18n("Rising to standing…") : i18n("Lowering to sitting…"))
                    : deskCard.at === "sit" ? i18n("At sitting height")
                    : deskCard.at === "stand" ? i18n("At standing height")
                    : deskCard.at === "between" ? i18n("Between the two heights")
                    : i18n("Height not read yet")
                color: !deskCard.d.reachable && !deskCard.d.moving ? Kirigami.Theme.negativeTextColor : root.themeDimColor
                wrapMode: Text.Wrap
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                visible: !deskCard.d.moving
                enabled: !deskCard.d.reading
                text: i18n("Read the height again")
                display: PlasmaComponents.AbstractButton.IconOnly
                onClicked: deskCard.d.readHeight()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }
        }

        // The scale: sitting and standing marked, the desk's height on it, the target while moving
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                y: Kirigami.Units.smallSpacing
                height: 6
                radius: 3
                color: root.themeTrackColor
            }
            // From where the move started to the desk now
            Rectangle {
                visible: deskCard.d.moving && !isNaN(deskCard.d.startCm) && deskCard.known
                readonly property real a: deskCard.frac(Math.min(deskCard.d.startCm, deskCard.d.heightCm))
                readonly property real b: deskCard.frac(Math.max(deskCard.d.startCm, deskCard.d.heightCm))
                x: track.width * a
                y: track.y
                width: Math.max(2, track.width * (b - a))
                height: track.height
                radius: 3
                color: root.themeAccentColor
                opacity: 0.5
            }
            Repeater {
                model: [
                    {cm: deskCard.sit, label: i18nc("sitting height mark", "Sit %1", Math.round(deskCard.sit))},
                    {cm: deskCard.standH, label: i18nc("standing height mark", "Stand %1", Math.round(deskCard.standH))},
                ]
                delegate: Item {
                    required property var modelData
                    x: track.width * deskCard.frac(modelData.cm)
                    Rectangle {
                        x: -1
                        y: track.y - 3
                        width: 2
                        height: track.height + 6
                        color: root.themeDimColor
                    }
                    PlasmaComponents.Label {
                        x: -width / 2
                        y: track.y + track.height + 4
                        text: modelData.label
                        font: Kirigami.Theme.smallFont
                        color: root.themeDimColor
                    }
                }
            }
            // The target, while moving
            Rectangle {
                visible: deskCard.d.moving && !isNaN(deskCard.d.targetCm)
                x: track.width * deskCard.frac(deskCard.d.targetCm) - width / 2
                y: track.y - 3
                width: 12
                height: 12
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: root.themeAccentColor
            }
            // The desk now
            Rectangle {
                visible: deskCard.known
                x: track.width * deskCard.frac(deskCard.d.heightCm) - width / 2
                y: track.y - 3
                width: 12
                height: 12
                radius: 6
                color: root.themeAccentColor
                Behavior on x {
                    NumberAnimation { duration: Kirigami.Units.longDuration }
                }
            }
        }

        // Moving or retrying: from and to, the attempt; or how to bring it back
        RowLayout {
            Layout.fillWidth: true
            visible: deskCard.d.moving || !deskCard.d.reachable
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: !deskCard.d.reachable && !deskCard.d.moving ? i18n("Switches wait for you to confirm them.")
                    : deskCard.d.attempt > 1 ? i18n("Stopped short, trying again (%1 of %2)", deskCard.d.attempt, deskCard.d.maxAttempts)
                    : !isNaN(deskCard.d.startCm) && !isNaN(deskCard.d.targetCm)
                        ? i18nc("desk move from → to", "%1 → %2 cm", Math.round(deskCard.d.startCm), Math.round(deskCard.d.targetCm))
                    : i18n("Moving…")
                font: Kirigami.Theme.smallFont
                color: root.themeDimColor
                wrapMode: Text.Wrap
            }
            PlasmaComponents.Button {
                visible: !deskCard.d.reachable && !deskCard.d.moving
                enabled: !deskCard.d.reading
                icon.name: "view-refresh"
                text: i18n("Try again")
                onClicked: deskCard.d.readHeight()
            }
            PlasmaComponents.Button {
                visible: deskCard.d.moving && deskCard.d.attempt > 1
                icon.name: "process-stop"
                text: i18n("Stop retrying")
                onClicked: deskCard.d.cancel()
            }
        }
    }
}
