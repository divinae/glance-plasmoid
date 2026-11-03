import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The Stand tab: Shift's popup, over its controller (`root`)
Item {
    required property Item root
    readonly property var settings: root.settings

        // As tall as its rows: the tab's Page scrolls when they don't fit
        implicitHeight: content.implicitHeight + 2 * content.anchors.margins

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            // Room for the buttons' focus rings, which the popup edge would otherwise clip.
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                ProgressCircle {
                    size: Kirigami.Units.gridUnit * 4
                    lineWidth: Kirigami.Units.smallSpacing * 1.5
                    arcBegin: 0
                    arcEnd: 360 * Cycle.progress(root.cycle, root.cfg)
                    showBackground: true
                    colorCircle: root.ringColor
                    colorBackground: root.themeTrackColor
                    indeterminate: root.deskDriver.moving

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        source: root.postureIcon
                        isMask: true
                        color: root.themeTextColor
                        opacity: root.idle ? 0.5 : 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: root.statusText()
                        wrapMode: Text.Wrap
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.countdownText()
                        color: root.themeDimColor
                        wrapMode: Text.Wrap
                    }
                }
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

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 5
                text: i18n("Today")
                color: root.themeDimColor
            }

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
            }

            WeekChart {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.topMargin: Kirigami.Units.smallSpacing
                days: root.weekDays
                todayMinutes: root.todayMinutes
                goalMinutes: root.goalMinutes
                barColor: root.themeAccentColor
                trackColor: root.themeTrackColor
                lineColor: root.themeDimColor
                labelColor: root.themeDimColor
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: root.deskEnabled
                level: 5
                text: i18n("Desk")
                color: root.themeDimColor
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.deskEnabled

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
