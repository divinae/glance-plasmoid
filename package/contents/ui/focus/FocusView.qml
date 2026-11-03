import "./lib"
import "./lib/tasks.js" as Tasks
import "./lib/timer.js" as TimerLogic
import QtQml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The Focus tab: Fokus's popup (Timer, Tasks, Stats), over its controller (`root`)
Item {
    required property Item root
    readonly property var settings: root.settings

        id: fullRoot

        // Whether the stats page has been asked for. A latch rather than a live test of
        // the tab index: unloading the page on every tab change would rebuild the chart
        // from scratch each time it is opened.
        property bool statsRequested: false

        // The popup is what makes the tab reachable, so an index left on Stats from the
        // last time cannot load the page while the applet is still collapsed.
        readonly property bool statsTabOpen: root.expanded && !root.focusMode && tabBar.currentIndex === 2

        onStatsTabOpenChanged: if (statsTabOpen)
            statsRequested = true

        // The tab's page gives it its size
        implicitHeight: Kirigami.Units.gridUnit * 20

        HoverHandler {
            id: fullRepMouse
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            cursorShape: Qt.PointingHandCursor
        }

        PlasmaComponents.TabBar {
            id: tabBar

            visible: !root.focusMode

            anchors {
                top: fullRoot.top
                left: fullRoot.left
                right: fullRoot.right
                // Room for the toggle, which would otherwise sit on top of the last tab.
                rightMargin: focusModeButton.width
            }

            PlasmaComponents.TabButton {
                text: i18n("Timer")
                icon.name: "chronometer"
            }

            PlasmaComponents.TabButton {
                text: i18n("Tasks")
                icon.name: "view-task"
            }

            PlasmaComponents.TabButton {
                text: i18n("Stats")
                icon.name: "office-chart-bar"
            }
        }

        PlasmaComponents.ToolButton {
            id: focusModeButton

            // Above the pages, so it stays reachable as the way back out.
            z: 10
            flat: true
            display: QQC2.AbstractButton.IconOnly
            icon.name: root.focusMode ? "view-restore" : "view-fullscreen"
            text: root.focusMode ? i18n("Show the full popup") : i18n("Focus mode")
            onClicked: root.focusMode = !root.focusMode

            anchors {
                top: fullRoot.top
                right: fullRoot.right
            }

            PlasmaComponents.ToolTip {
                text: focusModeButton.text
                visible: focusModeHover.hovered
            }

            HoverHandler {
                id: focusModeHover
            }
        }

        QQC2.SwipeView {
            id: pages

            // Focus mode is the timer, whichever tab was last open.
            currentIndex: root.focusMode ? 0 : tabBar.currentIndex
            clip: true
            // Interactive swiping would fight the scroll-to-adjust gesture on the
            // timer page, so pages change only through the tab bar.
            interactive: false

            anchors {
                top: root.focusMode ? fullRoot.top : tabBar.bottom
                left: fullRoot.left
                right: fullRoot.right
                bottom: fullRoot.bottom
                topMargin: Kirigami.Units.smallSpacing
            }

            Item {
                id: timerPage

        // Chosen, not typed: tasks are created on the Tasks page, and this only
        // picks which of them the session is for.
        PlasmaComponents.ComboBox {
            id: taskPicker

            visible: !root.focusMode
            model: root.taskChoices
            textRole: "text"
            // displayText rather than a currentIndex binding. Binding currentIndex
            // to a value derived from the model means a model rebuild re-enters
            // the control's own index handling, which is a known recursion hazard
            // - one segfault was seen with that shape before this was changed.
            displayText: settings.focus_task_label || i18n("No task")
            // onActivated fires only on a real choice, so rebuilding the model
            // when the task list changes cannot overwrite the current task.
            onActivated: index => {
                root.setTask(root.taskChoices[index].value);
            }

            anchors {
                top: timerPage.top
                left: timerPage.left
                right: timerPage.right
                margins: Kirigami.Units.smallSpacing
            }
        }

        PlasmaComponents.Label {
            id: dailyLabel

            visible: !root.focusMode
            text: root.doneTodayText()
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: root.themeDimColor
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter

            anchors {
                bottom: buttonsRow.top
                left: timerPage.left
                right: timerPage.right
                bottomMargin: Kirigami.Units.smallSpacing
            }
        }

        Item {
            anchors {
                // Anchoring to a hidden item still uses its geometry, so focus mode has
                // to re-anchor rather than rely on the chrome being invisible.
                top: root.focusMode ? timerPage.top : taskPicker.bottom
                left: timerPage.left
                right: timerPage.right
                bottom: root.focusMode ? timerPage.bottom : dailyLabel.top
            }

            MouseArea {
                property int wheelDelta: 0

                anchors.fill: parent
                onWheel: wheel => {
                    if (!root.wheelAdjustsTime()) {
                        wheel.accepted = false;
                        return;
                    }
                    wheelDelta = root.scrollByWheel(wheelDelta, wheel.angleDelta.y);
                }
            }

            TimerFace {
                anchors.fill: parent

                // Larger with the chrome gone, which is the point of the mode.
                sizeDivisor: root.focusMode ? 1.15 : 1.4
                progress: root.progressFraction()
                // The ring used to be hidden during a flow for want of anything to
                // draw; the sweep is what to draw instead.
                showProgress: true
                indeterminate: root.progressIndeterminate
                timeText: root.timeText
                showTime: settings.focus_show_dial_time
                statusText: root.statusText
                sessionCount: root.numberOfSessions
                sessionIndex: (root.stateVal - 1) / 2
                showSessionDots: !root.flowmodoroModeEnabled && root.numberOfSessions > 1
                fontFamily: root.clock_fontfamily
                fontBold: settings.focus_clock_bold
                circleColor: root.getCircleColor()
                captionColor: root.getTextColor()
            }
        }

        RowLayout {
            id: buttonsRow
            spacing: 10
            height: Kirigami.Units.gridUnit * 2
            visible: !root.focusMode
                     && (!settings.focus_show_buttons_on_hover || fullRepMouse.hovered)

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
            }

            PlasmaComponents.Button {
                text: i18n("Sk&ip")
                icon.name: "media-skip-forward"
                visible: !root.flowmodoroModeEnabled
                onClicked: root.skip()
            }

            PlasmaComponents.Button {
                id: sessionBtn
                text: root.sessionBtnText
                icon.name: root.sessionBtnIconSource
                onClicked: root.toggleSession()
            }

            PlasmaComponents.Button {
                // Halts the timer and resets the counter to zero in both modes, so it is
                // Stop in both. Calling it Reset in flowmodoro only made sense while the
                // other button was misnamed Stop.
                //
                // During a break it is renamed rather than joined by a second button:
                // ending a break is the point at which "stop" means "that is me done",
                // since the alternative - Skip - carries on into the next session.
                //
                // endForToday() wraps interruptSession(), not stop(): what was worked
                // before the press is still worked, and in flowmodoro this is the only way
                // out of a flow besides Break, so a bare stop() dropped whole flows on the
                // floor. stop() itself stays silent because the config handlers call it
                // while the applet is still loading.
                text: (root.isBreak() || root.breakOvertime) ? i18n("&End for today") : i18n("St&op")
                icon.name: "media-playback-stop"
                onClicked: root.endForToday()
            }
        }

            }

            TaskListView {
                dimColor: root.themeDimColor
                textColor: root.themeTextColor
                tasksJson: settings.focus_task_list
                activeTask: settings.focus_task_label
                onSaveRequested: json => root.writeTaskList(json)
                onRenameRequested: (id, title) => root.renameTask(id, title)
                // Picking a task names the session and puts it on the dial.
                onTaskPicked: title => root.setTask(title)
            }

            // Behind a Loader, and built only once the tab is actually opened. The stats
            // page is by far the largest tree the applet makes - a bar per day, a legend
            // row per task, and a block with a tooltip per recorded session - and
            // SwipeView builds every page eagerly, so it used to be constructed while the
            // popup was being reparented into its window. plasmashell died there: a
            // SIGSEGV inside KirigamiPlasmaStyle, pushing a highlight colour through
            // Kirigami's PlatformTheme as the tree attached to the window, with no frame
            // of this applet's own in the backtrace. An empty history never crashed; a
            // real one crashed every time.
            //
            // Same lesson as the overlay windows in #59: keep the heavy tree off the path
            // that runs while the shell is still assembling things.
            Loader {
                id: statsPage

                // Not just currentIndex: once the page has been opened it stays loaded, so
                // switching tabs back and forth does not rebuild the chart every time.
                active: fullRoot.statsRequested
                // Off the reparenting path entirely - the tree is built after the window
                // exists, not during the property write that attaches it.
                asynchronous: true

                sourceComponent: StatsView {
                    entries: root.historyEntries
                    today: root.today
                    workdaySeconds: settings.focus_workday_hours * 3600
                    accentColor: root.themeAccentColor
                    dimColor: root.themeDimColor
                    textColor: root.themeTextColor
                    surfaceColor: root.themeSurfaceColor
                }
            }
        }
    }
