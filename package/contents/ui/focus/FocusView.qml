import "./lib"
import QtQml
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../tiles"

// The Focus tab, in Glance's cards: the timer on the left, its stats on the right. Over its
// controller (`root`).
GridLayout {
    id: view

    required property Item root
    readonly property var settings: root.settings

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    // ---- the timer ------------------------------------------------------------------------
    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: Kirigami.Units.gridUnit * 18

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MouseArea {
                    property int wheelDelta: 0

                    anchors.fill: parent
                    onWheel: wheel => {
                        if (!view.root.wheelAdjustsTime()) {
                            wheel.accepted = false;
                            return;
                        }
                        wheelDelta = view.root.scrollByWheel(wheelDelta, wheel.angleDelta.y);
                    }
                }

                TimerFace {
                    anchors.fill: parent
                    sizeDivisor: 1.25
                    progress: view.root.progressFraction()
                    showProgress: true
                    indeterminate: view.root.progressIndeterminate
                    timeText: view.root.timeText
                    showTime: view.settings.focus_show_dial_time
                    statusText: view.root.statusText
                    sessionCount: view.root.numberOfSessions
                    sessionIndex: (view.root.stateVal - 1) / 2
                    showSessionDots: !view.root.flowmodoroModeEnabled && view.root.numberOfSessions > 1
                    fontFamily: view.root.clock_fontfamily
                    fontBold: view.settings.focus_clock_bold
                    circleColor: view.root.getCircleColor()
                    captionColor: view.root.getTextColor()
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: view.root.doneTodayText()
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    text: view.root.isBreak() ? i18n("Skip Break") : i18n("Skip to Break")
                    icon.name: "chronometer-lap"
                    visible: !view.root.flowmodoroModeEnabled
                    onClicked: view.root.skip()
                }
                PlasmaComponents.Button {
                    text: view.root.sessionBtnText
                    icon.name: view.root.sessionBtnIconSource
                    onClicked: view.root.toggleSession()
                }
                PlasmaComponents.Button {
                    // endForToday() keeps what was worked; see FocusController
                    text: (view.root.isBreak() || view.root.breakOvertime) ? i18n("&End for today") : i18n("St&op")
                    icon.name: "chronometer-reset"
                    onClicked: view.root.endForToday()
                }
            }
        }
    }

    // ---- today's figures ------------------------------------------------------------------
    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        // Built once the tab is up rather than while the drawer assembles: the stats tree is
        // the largest the timer makes, and Fokus crashed building it on the reparenting path.
        Loader {
            id: statsLoader
            anchors.fill: parent
            active: false
            asynchronous: true
            // Latched on once the drawer is open and this page is shown in a window, a beat
            // later: never while the drawer is still being built and reparented
            Timer {
                interval: 250
                running: !statsLoader.active && view.root.expanded && view.visible && view.Window.window !== null
                onTriggered: statsLoader.active = true
            }

            sourceComponent: StatsView {
                entries: view.root.historyEntries
                today: view.root.today
                workdaySeconds: view.settings.focus_workday_hours * 3600
                accentColor: view.root.themeAccentColor
                dimColor: view.root.themeDimColor
                textColor: view.root.themeTextColor
                surfaceColor: view.root.themeSurfaceColor
            }
        }
    }
}
