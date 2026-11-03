import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
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

    // ---- the desk -------------------------------------------------------------------------------
    Card {
        visible: view.root.deskEnabled
        title: i18n("Desk")
        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: !root.deskDriver.moving && !root.deskDriver.reachable ? i18n("Desk not reachable. Switches wait for you to confirm them.")
                    : !root.deskDriver.moving ? root.heightText()
                    : root.deskDriver.attempt > 1 ? i18n("Desk stopped short, trying again (%1 of %2)…", root.deskDriver.attempt, root.deskDriver.maxAttempts)
                    : isNaN(root.deskDriver.startCm) ? i18n("Desk moving…")
                    : i18n("Moving %1 → %2 cm…", Math.round(root.deskDriver.startCm), Math.round(root.deskDriver.targetCm))
                wrapMode: Text.Wrap
            }

            PlasmaComponents.Button {
                visible: !root.deskDriver.reachable && !root.deskDriver.moving
                enabled: !root.deskDriver.reading
                icon.name: "view-refresh"
                text: i18n("Try again")
                onClicked: root.deskDriver.readHeight()
            }

            PlasmaComponents.Button {
                visible: root.deskDriver.moving && root.deskDriver.attempt > 1
                icon.name: "process-stop"
                text: i18n("Stop retrying")
                onClicked: root.deskDriver.cancel()
            }
        }
    }
}
