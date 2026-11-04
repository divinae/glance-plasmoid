import "../common"
import "./lib/tasks.js" as Tasks
import "./lib/timer.js" as TimerLogic
import QtQml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore

// Fokus's pomodoro/flowmodoro timer inside Glance: everything Fokus's main.qml held but its
// representations and applet properties, reading Glance's focus_* settings through `settings`.
// Its view is FocusView; Glance's panel and menu show its state.
Item {
    id: root

    // Plasmoid.configuration, handed in by Glance
    required property var settings
    // Whether Glance's drawer is open (Fokus's own popup's "expanded")
    property bool expanded: false

    property ExecUtil executable
    property string clock_fontfamily: settings.focus_clock_fontfamily || "Noto Sans"
    property int stateVal: 1
    property int initialSeconds: setInitialSeconds()

    // counterMilliseconds is the only stored countdown value; everything the UI
    // shows is derived from it. Keeping a second copy in seconds is what let
    // postpone() set the two to different lengths.
    property real counterMilliseconds: initialSeconds * 1000
    readonly property int counterSeconds: Math.ceil(counterMilliseconds / 1000)
    readonly property string timeText: TimerLogic.formatCounter(counterSeconds)
    // A panel column has room for about five glyphs, which the hours field breaks, so the
    // panel gets its own format. The popup and the tooltip keep timeText.
    readonly property string panelTimeText: TimerLogic.formatCounterPanel(counterSeconds)

    // Set while a break has run past its end and is counting the overrun. It has
    // to be a latched flag rather than a derived binding, because the
    // end-of-break notification and script must fire exactly once.
    property bool breakOvertime: false

    property int tickingSeconds: settings.focus_ticking_time
    property string sessionBtnText: i18n("St&art")
    property string sessionBtnIconSource: "media-playback-start"
    property string statusText: i18n("focus")
    property date previousTime: new Date()
    property int numberOfSessions: settings.focus_number_of_sessions
    readonly property string inhibitCmd: "kde-inhibit --notifications sleep 99999"
    // Every MPRIS player on the session bus is told to pause; one that is not playing
    // ignores it, so there is nothing to check first. dbus-send rather than the
    // private Plasma MPRIS module, which has no stable API. KDE Connect players are
    // somebody's phone, not this desk, and are left alone.
    readonly property string pauseMediaCmd: "for p in $(dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep -o 'org\\.mpris\\.MediaPlayer2\\.[^\"]*' | grep -v '\\.kdeconnect\\.'); do dbus-send --session --type=method_call --dest=\"$p\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause; done"
    readonly property bool flowmodoroModeEnabled: settings.focus_flowmodoro_mode_enabled // to update counter seconds when flowmode is enabled
    readonly property int focusTime: settings.focus_focus_time

    // The countdown crossing a second boundary is the only trigger for the
    // ticking sound; it used to be driven by an explicit updateTime() call that
    // every state transition had to remember to make.
    onCounterSecondsChanged: {
        if (!timer.running || !settings.focus_timer_tick_sfx_enabled)
            return;
        if (!TimerLogic.shouldTick(counterSeconds, initialSeconds, tickingSeconds, isBreak()))
            return;
        // Volume lives on the AudioOutput in Qt6, not on MediaPlayer; Sfx.play
        // takes it so callers cannot reintroduce the throw that once stopped the
        // ticking sound from playing at all.
        playSound(settings.focus_timer_tick_sfx_filepath, TimerLogic.tickVolume(counterSeconds, tickingSeconds));
    }

    onFlowmodoroModeEnabledChanged: {
        stop();
    }
    onFocusTimeChanged: {
        stop();
    }

    function setInitialSeconds() {
        // sets default value for counter
        if (flowmodoroModeEnabled && !isBreak()) {
            return 0;
        } else {
            return settings.focus_focus_time * 60;
        }
    }

    function shiftCounter(seconds) {
        if (counterSeconds + seconds > 0) {
            counterMilliseconds += seconds * 1000;
            initialSeconds += seconds;
        }
    }

    // When the wheel does nothing here, the handlers pass it on rather than swallow
    // it, so whatever sits behind the applet - the desktop switching virtual
    // desktops, say - still gets it (#33). A flow counts up and has no length to
    // adjust.
    function wheelAdjustsTime() {
        return settings.focus_scroll_adjusts_time_enabled && !flowmodoroModeEnabled;
    }

    // Scroll wheel adds or removes whole minutes. Takes the caller's leftover
    // delta, returns the new leftover.
    // magic number 120 for common "one click"
    // See: http://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
    function scrollByWheel(wheelDelta, eventDelta) {
        wheelDelta += eventDelta;
        while (wheelDelta >= 120) {
            wheelDelta -= 120;
            shiftCounter(60);
        }
        while (wheelDelta <= -120) {
            wheelDelta += 120;
            shiftCounter(-60);
        }
        return wheelDelta;
    }

    readonly property real soundVolume: settings.focus_sound_volume / 100

    function playSound(path, factor) {
        if (path)
            sfx.play(path, soundVolume * (factor === undefined ? 1 : factor));
    }

    // Whether this event should show a popup. Focus and breaks are configured
    // separately; the existing timer_* keys are the focus ones.
    function wantsNotification(breakEvent, atEnd) {
        if (breakEvent)
            return atEnd ? settings.focus_break_end_notification_enabled : settings.focus_break_start_notification_enabled;
        return atEnd ? settings.focus_timer_end_notification_enabled : settings.focus_timer_start_notification_enabled;
    }

    // The sound file for this event, or "" for silence.
    function soundFor(breakEvent, atEnd) {
        if (breakEvent) {
            if (atEnd)
                return settings.focus_break_end_sfx_enabled ? settings.focus_break_end_sfx_filepath : "";
            return settings.focus_break_start_sfx_enabled ? settings.focus_break_start_sfx_filepath : "";
        }
        if (atEnd)
            return settings.focus_timer_stop_sfx_enabled ? settings.focus_timer_stop_sfx_filepath : "";
        return settings.focus_timer_start_sfx_enabled ? settings.focus_timer_start_sfx_filepath : "";
    }

    // The next meeting (Glance passes Event Calendar's), for a warning before a session that
    // would run into it
    property var nextMeeting: null
    // A clock for the warning, ticking only while there is a meeting to warn about
    property real meetingClockMs: Date.now()
    Timer {
        interval: 30 * 1000
        repeat: true
        running: root.nextMeeting !== null
        triggeredOnStart: true
        onTriggered: root.meetingClockMs = Date.now()
    }
    readonly property string meetingWarning: {
        if (!nextMeeting || timer.running || isBreak())
            return "";
        var minutes = Math.round((nextMeeting.start.getTime() - meetingClockMs) / 60000);
        if (minutes <= 0 || (!flowmodoroModeEnabled && minutes * 60 >= counterSeconds) || minutes > 120)
            return "";
        return i18np("A meeting starts in %1 minute", "A meeting starts in %1 minutes", minutes);
    }

    // Paused for a meeting (Glance pauses the block at its start): offered back at its end
    property bool pausedForMeeting: false
    function pauseForMeeting() {
        if (!timer.running || isBreak())
            return;
        pause(); // A flow too: it goes on after the meeting, as a pomodoro does
        pausedForMeeting = true;
    }
    function meetingEnded() {
        if (!pausedForMeeting)
            return;
        pausedForMeeting = false;
        if (timer.running)
            return;
        notificationManager.notifyActions(i18n("The meeting is over."), [
            { label: i18n("Resume focus"), action: function() { if (!timer.running) root.start(); } }
        ], "chronometer");
    }

    // The popup and the sound are independent: either, both or neither. Previously
    // the sound rode along inside the notification, so it could not play alone.
    function announce(breakEvent, atEnd, summary, actionLabel, action) {
        if (wantsNotification(breakEvent, atEnd))
            notificationManager.notify(summary, actionLabel, action);
        playSound(soundFor(breakEvent, atEnd));
    }

    // Caption for the state that is about to run, shared by the tooltip and the
    // start notification.
    function stateHeadline() {
        if (!isBreak())
            return i18n("Focus on your work!");
        if (isLongBreak())
            return i18n("Take a long break!");
        return i18n("Go for a walk.");
    }

    // The tooltip is the one place the whole state is visible at a glance, so it
    // reports where in the cycle the session is rather than a fixed sentence.
    function doneTodayText() {
        if (focusDoneToday === 0)
            return i18n("Nothing finished today yet.");
        return i18np("%1 focus session today, %2 in total", "%1 focus sessions today, %2 in total", focusDoneToday, TimerLogic.formatCounter(focusSecondsToday));
    }

    function getToolTipText() {
        if (breakOvertime)
            return i18n("Break ended %1 ago.", TimerLogic.formatCounter(-counterSeconds)) + "\n" + doneTodayText();
        if (!timer.running)
            return doneTodayText();
        if (flowmodoroModeEnabled)
            return isBreak() ? i18n("Flow break, %1 left", timeText) : i18n("Flow, %1 so far", timeText);
        if (isLongBreak())
            return i18n("Long break, %1 left", timeText);
        if (isBreak())
            return i18n("Short break, %1 left", timeText);
        if (numberOfSessions > 1)
            return i18n("Focus, session %1 of %2, %3 left", TimerLogic.sessionNumber(stateVal), numberOfSessions, timeText) + "\n" + doneTodayText();
        return i18n("Focus, %1 left", timeText) + "\n" + doneTodayText();
    }

    // The primary action, shared by the popup button and the compact
    // middle-click. During a break overrun it means "I am done, start focus".
    function toggleSession() {
        if (breakOvertime)
            finishBreak();
        else if (!timer.running)
            start();
        else if (flowmodoroModeEnabled)
            skip();
        else
            pause();
    }

    function start() {
        claimStartup();
        announce(isBreak(), false, stateHeadline());
        if (!isBreak())
            doNotDisturbEnable();
        else
            pauseMedia();
        previousTime = new Date();
        executeScript(1);
        timer.start();
        if (flowmodoroModeEnabled) {
            // "Break", not "Stop": in flowmodoro this button ends the flow and begins
            // the break it earned. It was labelled Stop while calling skip(), which is
            // the opposite of stopping.
            sessionBtnText = i18n("&Break");
            sessionBtnIconSource = "chronometer-pause";
        } else {
            sessionBtnText = i18n("Pa&use");
            sessionBtnIconSource = "media-playback-pause";
        }
        /* applet status: Glance shows the running state */
        syncBreakDialog();
        saveSession();
    }

    function pause() {
        doNotDisturbDisable();
        timer.stop();
        sessionBtnText = i18n("St&art");
        sessionBtnIconSource = "media-playback-start";
        syncBreakDialog();
        saveSession();
    }

    function end() {
        doNotDisturbDisable();
        // The state has not advanced yet, so isBreak() still describes the session
        // that just finished and the button names the next one. The guard matters
        // because auto-start may have begun it already by the time it is pressed.
        announce(isBreak(), true, isBreak() ? i18n("End of break.") : i18n("End of focus time."), isBreak() ? i18n("Start focus") : i18n("Start break"), function() {
            if (!timer.running)
                start();
        });
        executeScript(2);
        timer.stop();
        // Recorded before nextState()/resetTime() overwrite the lengths. Reaching
        // zero means it ran its full planned length - unless the task was switched
        // part-way, in which case the earlier stretches are already recorded and
        // only the last one is left to file.
        var wholeSession = isBreak() || taskSegmentStartSeconds === 0;
        var actual = wholeSession ? initialSeconds : initialSeconds - taskSegmentStartSeconds;
        recordSession(currentKind(), wholeSession ? initialSeconds : actual, actual);
        pulseOnEnd();
        sessionBtnText = i18n("St&art");
        sessionBtnIconSource = "media-playback-start";
        nextState();
        resetTime();
        if ((isBreak() && settings.focus_timer_auto_pause_enabled) || (!isBreak() && settings.focus_timer_auto_focus_enabled)) {
            start();
        } else {
            syncBreakDialog();
        saveSession();
            /* applet status: Glance shows the running state */
        }
    }

    // A break that runs out with auto-start-focus off keeps counting, so the
    // overrun stays visible as a negative time until focus is started by hand.
    // The break is genuinely over, so everything that normally happens at the end
    // of one happens now; only the state change waits for the user. Staying on
    // the break state is what keeps the overlay up and the break colours in use.
    function beginBreakOvertime() {
        breakOvertime = true;
        pulseOnEnd();
        // The overrun keeps running until the user acts, so the button is the way
        // out of it. This is a break ending, so it uses the break keys.
        announce(true, true, i18n("End of break."), i18n("Start focus"), finishBreak);
        executeScript(2);
        statusText = i18n("break overrun");
        sessionBtnText = i18n("St&art");
        sessionBtnIconSource = "media-playback-start";
        saveSession();
    }

    // Leaving an overrun: advance out of the break the user has been sitting in,
    // then begin the focus session.
    function finishBreak() {
        // An overrunning break is not finished until now, so this is where its
        // real length is known: the planned length plus however far it ran over.
        // counterSeconds is negative during an overrun.
        recordSession(currentKind(), initialSeconds, initialSeconds - counterSeconds);
        nextState();
        resetTime();
        start();
    }

    function skip() {
        claimStartup();
        // A flow session counts up and never reaches zero, so skipping out of it
        // is the only point its length is known. It has no planned length.
        if (timer.running && flowmodoroModeEnabled && !isBreak())
            recordSession("flow", 0, TimerLogic.segmentSeconds(counterSeconds, taskSegmentStartSeconds));
        nextState();
        resetTime();
        syncBreakDialog();
        saveSession();
        if (!isBreak()) {
            doNotDisturbEnable();
        } else {
            doNotDisturbDisable();
            // Only a break that is under way: skipping through idle states is not one.
            if (timer.running)
                pauseMedia();
        }
        if (flowmodoroModeEnabled && !isBreak()) {
            sessionBtnText = i18n("&Break");
            sessionBtnIconSource = "chronometer-pause";
        } else if (flowmodoroModeEnabled && isBreak()) {
            sessionBtnText = i18n("Sk&ip");
            sessionBtnIconSource = "media-skip-forward";
        }
    }

    function postpone() {
        claimStartup();
        breakOvertime = false;
        prevState();
        statusText = i18n("focus");
        initialSeconds = 60 * 5;
        previousTime = new Date();
        counterMilliseconds = initialSeconds * 1000;
        syncBreakDialog();
        saveSession();
        if (!isBreak()) {
            doNotDisturbEnable();
        } else {
            doNotDisturbDisable();
        }
    }

    function stop() {
        claimStartup();
        doNotDisturbDisable();
        executeScript(0);
        timer.stop();
        stateVal = 1;
        resetTime();
        sessionBtnText = i18n("St&art");
        sessionBtnIconSource = "media-playback-start";
        /* applet status: Glance shows the running state */
        syncBreakDialog();
        saveSession();
    }

    // Caption for a session kind. Shared so the restore path does not need its own
    // copy of this mapping, which would be one more thing to keep in step.
    function captionFor(kind) {
        switch (kind) {
        case "flow":
            return i18n("flow");
        case "flowBreak":
            return i18n("flow break");
        case "longBreak":
            return i18n("long break");
        case "shortBreak":
            return i18n("short break");
        default:
            return i18n("focus");
        }
    }

    // Written down on every transition, so a plasmashell restart - an update, a
    // crash - does not discard a session in progress.
    function saveSession() {
        // Nothing is written until startup has settled. The config-change handlers
        // for focus_time and flowmodoro fire stop() while the applet is still being
        // built, and that stop() would otherwise save a fresh, stopped session over
        // the one being restored - which is exactly the state this feature exists to
        // keep.
        if (!sessionReady)
            return;
        var now = new Date().getTime();
        var countingUp = flowmodoroModeEnabled && !isBreak();
        settings.focus_session_state = TimerLogic.serializeSession({
            "stateVal": stateVal,
            "initialSeconds": initialSeconds,
            "running": timer.running,
            "breakOvertime": breakOvertime,
            "countingUp": countingUp,
            // A deadline rather than a remaining time, so the seconds Plasma was
            // down are counted the same way a suspend already is.
            "deadline": timer.running && !countingUp ? now + counterMilliseconds : 0,
            "remainingMs": timer.running ? 0 : counterMilliseconds,
            "startedAt": countingUp ? now - counterMilliseconds : 0,
            "taskSegmentStart": taskSegmentStartSeconds,
            "savedAt": now,
            // Which boot this belongs to, so the restore can refuse a session the
            // machine was rebooted out of. See sessionIsStale().
            "bootId": bootId
        });
    }

    // Returns whether a RUNNING session was picked up, so the caller knows not to autostart
    // on top of one already counting. A stopped session is still restored - its state and
    // what was left on the clock - but it does not count as picked up: nothing is running,
    // so autostart has nothing to overwrite and every reason to fire.
    function restoreSession() {
        var session = TimerLogic.parseSession(settings.focus_session_state);
        var now = new Date().getTime();
        if (!session || TimerLogic.sessionIsStale(session, now, bootId))
            return false;
        stateVal = session.stateVal;
        initialSeconds = session.initialSeconds;
        breakOvertime = session.breakOvertime === true;
        taskSegmentStartSeconds = session.taskSegmentStart || 0;
        statusText = breakOvertime ? i18n("break overrun") : captionFor(TimerLogic.sessionKind(stateVal, numberOfSessions, flowmodoroModeEnabled));
        previousTime = new Date();
        counterMilliseconds = TimerLogic.restoredCounterMs(session, now);
        // Restored, but not running: "Start the timer when Plasma starts" is what autostart
        // promises, and a stopped session left over from the last login is not a running
        // timer. Reporting it as picked up is why autostart did nothing whenever anything at
        // all was stored - which is most logins (gitlab #47).
        if (!session.running)
            return false;
        // Deliberately not start(): resuming must not re-fire the start
        // notification or the start script, which already ran before the restart.
        timer.start();
        if (flowmodoroModeEnabled) {
            // "Break", not "Stop": in flowmodoro this button ends the flow and begins
            // the break it earned. It was labelled Stop while calling skip(), which is
            // the opposite of stopping.
            sessionBtnText = i18n("&Break");
            sessionBtnIconSource = "chronometer-pause";
        } else {
            sessionBtnText = i18n("Pa&use");
            sessionBtnIconSource = "media-playback-pause";
        }
        if (!isBreak())
            doNotDisturbEnable();
        /* applet status: Glance shows the running state */
        syncBreakDialog();
        saveSession();
        return true;
    }

    function resetTime() {
        // Every transition ends up here, so this is the one place an overrun can
        // be cleared - except postpone(), which sets its own time.
        breakOvertime = false;
        // A new session starts a new stretch, whatever the task was before.
        taskSegmentStartSeconds = 0;
        var kind = TimerLogic.sessionKind(stateVal, numberOfSessions, flowmodoroModeEnabled);
        switch (kind) {
        case "flow":
            // A flow session counts up, so it has no length to run down.
            initialSeconds = 0;
            break;
        case "flowBreak":
            initialSeconds = Math.max(1, Math.floor(counterSeconds / settings.focus_flow_divisor));
            break;
        case "longBreak":
            initialSeconds = settings.focus_long_break_time * 60;
            break;
        case "shortBreak":
            initialSeconds = settings.focus_short_break_time * 60;
            break;
        default:
            initialSeconds = settings.focus_focus_time * 60;
            break;
        }
        statusText = captionFor(kind);
        previousTime = new Date();
        counterMilliseconds = initialSeconds * 1000;
    }

    // Driven by wall clock rather than by the tick count, so the countdown stays
    // correct if the timer fires late or the machine suspends.
    // Ends a session early, keeping the part that really ran. Two callers: a gap the
    // machine slept through, and the Stop the user pressed. Either way the time before
    // it was worked, so it is recorded; the gap itself is not, which is the whole point.
    //
    // From setTime() this runs before the counter has seen the gap, so the elapsed figure
    // here is the state as at the last tick.
    function interruptSession() {
        if (!isBreak()) {
            var segment = TimerLogic.segmentSeconds(elapsedSeconds(), taskSegmentStartSeconds);
            // A flow has no length to plan, so it is filed with a planned zero - the same
            // shape skip() writes, which is the other way out of one.
            var planned = (flowmodoroModeEnabled && !isBreak()) ? 0 : segment;
            if (segment > 0)
                recordSession(currentKind(), planned, segment);
        }
        // stop() resets to the first focus session and leaves the panel showing Start, so the
        // interruption is visible rather than silently rolled into the next session.
        stop();
    }

    // Ends the day rather than the session: the break stops and nothing follows it, so
    // the flowmodoro chain is broken instead of advanced the way skip() advances it. The
    // work already done is filed; a break that has not run its length is not, which is
    // interruptSession()'s existing rule.
    //
    // A thin wrapper on purpose: the two buttons that call it read as what they do, and
    // stop() alone - which is what they used to call - would have dropped the flow.
    function endForToday() {
        interruptSession();
    }

    function setTime() {
        var currentTime = new Date();
        var timeDiff = currentTime.getTime() - previousTime.getTime();
        previousTime = currentTime;
        // A jump this large is the machine having been away, not time spent working.
        if (TimerLogic.isTimeGap(timeDiff)) {
            interruptSession();
            return;
        }
        if (flowmodoroModeEnabled && !isBreak()) {
            counterMilliseconds += timeDiff;
        } else {
            counterMilliseconds -= timeDiff;
            if (counterMilliseconds <= 0 && !breakOvertime) {
                if (isBreak() && !settings.focus_timer_auto_focus_enabled)
                    beginBreakOvertime();
                else
                    end();
            }
        }
    }

    function doNotDisturbEnable() {
        if (settings.focus_do_not_disturb_enabled)
            executable.exec(inhibitCmd);
    }

    function pauseMedia() {
        if (settings.focus_break_pause_media_enabled)
            executable.exec(pauseMediaCmd);
    }

    function doNotDisturbDisable() {
        // Unconditional: the inhibitor must be released even if the setting was
        // turned off while a session was already running.
        executable.stopExec(inhibitCmd);
    }

    // --- session history ---------------------------------------------------
    //
    // False until Component.onCompleted has finished, so startup churn cannot
    // overwrite the stored session. See saveSession().
    property bool sessionReady: false

    // Strips the popup back to the dial alone: no tabs, no task picker, no buttons, no
    // daily line. Runtime only rather than a config key - it is a way to look at the
    // timer for a moment, not a setting to carry across restarts.
    property bool focusMode: false

    // Bumped when a session finishes, to flash the panel icon for people who run
    // without notification sound and miss the moment (gitlab #17).
    property int endPulse: 0

    function pulseOnEnd() {
        if (settings.focus_flash_on_end)
            endPulse++;
    }

    // Bumped whenever the stored history changes, so the counts below recompute.
    // plasmoid.configuration is not itself a notifying source for this purpose.
    property int historyRevision: 0

    readonly property var historyEntries: {
        historyRevision; // establish the dependency
        return TimerLogic.parseHistory(settings.focus_session_history);
    }
    // Kept current by dayTurnover below: a binding on new Date() is evaluated once
    // and would hold the day the applet loaded on until the next restart (#67).
    property string today: TimerLogic.dayKey(new Date())
    readonly property int focusDoneToday: TimerLogic.countFocusOn(historyEntries, today)
    readonly property int focusSecondsToday: TimerLogic.focusSecondsOn(historyEntries, today)

    // Called at the point a session is known to have finished. plannedSeconds is
    // what it was set to run for; actualSeconds is what it really took, which
    // differ after a break overrun or a scroll adjustment.
    // task defaults to the current one; a task switch passes the outgoing task, so
    // the stretch is filed under the task it was actually worked on.
    // Where the current task's stretch began, as elapsed seconds into this session.
    // Non-zero only after a mid-session task switch.
    property int taskSegmentStartSeconds: 0

    function elapsedSeconds() {
        return TimerLogic.elapsedSeconds(initialSeconds, counterSeconds,
                                         flowmodoroModeEnabled && !isBreak());
    }

    // The single way the task changes, so switching it can never silently
    // re-attribute time already worked. Changing task mid-session closes the stretch
    // that ran under the old task as a finished session, then starts counting the
    // new one from here - the session itself keeps running.
    function setTask(title) {
        if (title === settings.focus_task_label)
            return;
        // Breaks are not filed against a task, and a session that has not started
        // has nothing to close: both fall out of the segment being zero.
        if (!isBreak()) {
            var elapsed = elapsedSeconds();
            var segment = TimerLogic.segmentSeconds(elapsed, taskSegmentStartSeconds);
            // The base advances only when the stretch was actually recorded. A stretch
            // too short to record leaves it where it is, so those minutes carry into the
            // next task's stretch rather than being lost - they end up filed under
            // whichever task is current once the total clears the minimum.
            if (segment > 0 && recordSession(currentKind(), segment, segment, settings.focus_task_label))
                taskSegmentStartSeconds = elapsed;
        }
        settings.focus_task_label = title;
        saveSession();
    }

    // Returns whether the stretch was recorded, so a task switch knows whether the
    // time has been accounted for or still needs carrying.
    function recordSession(kind, plannedSeconds, actualSeconds, task) {
        // A focus stretch shorter than the configured minimum is not recorded, so the
        // totals and the per-task breakdown are not littered with two-minute fragments.
        if (!TimerLogic.countsAsSession(kind, actualSeconds, settings.focus_min_session_minutes * 60))
            return false;
        var now = new Date();
        var entry = TimerLogic.makeEntry(kind, plannedSeconds, actualSeconds, now,
                                         task === undefined ? settings.focus_task_label : task);
        settings.focus_session_history = TimerLogic.appendHistory(settings.focus_session_history, entry, now);
        historyRevision++;
        return true;
    }

    // Todo list, read through the same revision trick as history.
    property int taskListRevision: 0

    // Visible tasks only: deleting a task archives it, so that the sessions recorded
    // against its name keep that name on the stats page. Nothing user-facing should
    // see an archived row.
    readonly property var taskList: {
        taskListRevision;
        return Tasks.visibleTasks(Tasks.parseTasks(settings.focus_task_list));
    }

    // Options for the timer page's task dropdown: no task, then every open task.
    readonly property var taskChoices: {
        var choices = [{ "text": i18n("No task"), "value": "" }];
        for (var i = 0; i < taskList.length; i++) {
            if (!taskList[i].done)
                choices.push({ "text": taskList[i].title, "value": taskList[i].title });
        }
        return choices;
    }

    function writeTaskList(json) {
        settings.focus_task_list = json;
        taskListRevision++;
    }

    // Renaming carries the recorded sessions with it, because history names its task
    // by title rather than by id: without the rewrite, a rename would leave every past
    // session under the old name and split one task's work in two on the stats page.
    function renameTask(id, newTitle) {
        var title = ("" + newTitle).trim();
        if (!title)
            return;
        var all = Tasks.parseTasks(settings.focus_task_list);
        var index = Tasks.indexOfTask(all, id);
        if (index < 0)
            return;
        var oldTitle = all[index].title;
        if (oldTitle === title)
            return;

        writeTaskList(Tasks.renameTask(settings.focus_task_list, id, title));
        settings.focus_session_history =
            TimerLogic.renameTaskInHistory(settings.focus_session_history, oldTitle, title);
        historyRevision++;

        // Deliberately not setTask(): that closes the current stretch and records a
        // session, which is right for switching task and wrong for renaming one. The
        // session carries on untouched under its new name.
        if (settings.focus_task_label === oldTitle)
            settings.focus_task_label = title;
    }

    // The kind of the session that is finishing right now, before nextState().
    function currentKind() {
        return TimerLogic.sessionKind(stateVal, numberOfSessions, flowmodoroModeEnabled);
    }

    // Stopped part-way rather than not started: stop() resets the counter to the
    // full session length, pause() leaves it where it was. A flow counts up, so
    // for it any progress at all means paused.
    readonly property bool sessionPaused: {
        if (timer.running || breakOvertime)
            return false;
        return initialSeconds > 0 ? counterSeconds < initialSeconds : counterSeconds > 0;
    }

    function progressFraction() {
        return TimerLogic.progressFraction(counterSeconds, initialSeconds);
    }

    function nextState() {
        stateVal = TimerLogic.nextState(stateVal, numberOfSessions, {
            "flowmodoro": flowmodoroModeEnabled,
            "skipShortBreak": settings.focus_short_break_time === 0,
            "skipLongBreak": settings.focus_long_break_time === 0
        });
    }

    function prevState() {
        stateVal = TimerLogic.prevState(stateVal);
    }

    // --- the palette, read once ---------------------------------------------------
    //
    // The applet root is never in a window itself; only its representations are. A theme
    // read here therefore drives libplasma's Kirigami style - PlasmaTheme::syncColors() -
    // with no on-screen item owning the result, and that path took plasmashell down with
    // a SIGSEGV, notifying a change event to a null receiver:
    //
    //   QCoreApplication::notifyInternal2 (receiver=0x0)
    //   Kirigami::Platform::PlatformTheme::setHighlightColor
    //   PlasmaTheme::syncColors  (libplasma 6.7.4, plasmatheme.cpp:150)
    //
    // So the theme is read once, a pass after construction, and every caller takes the
    // cached value. A plasmoid has no sandbox - it runs inside plasmashell - so staying
    // off that path is the applet's own responsibility.
    property bool paletteReady: false
    readonly property color themeTextColor: paletteReady ? Kirigami.Theme.textColor : "transparent"
    readonly property color themeDimColor: paletteReady ? Kirigami.Theme.disabledTextColor : "transparent"
    readonly property color themeAccentColor: paletteReady ? Kirigami.Theme.highlightColor : "transparent"
    readonly property color themeSurfaceColor: paletteReady ? Kirigami.Theme.backgroundColor : "transparent"

    // --- break overlay palette -------------------------------------------
    //
    // The overlay can keep its own light or dark palette regardless of the desktop
    // scheme: a dark overlay over a light desktop is much less of a jolt when a
    // break starts, which is the whole point of the thing. 0 follows Plasma.
    readonly property bool overlayThemeForced: settings.focus_break_overlay_theme !== 0
    readonly property bool overlayThemeDark: settings.focus_break_overlay_theme === 1

    // Read out of Breeze's own scheme files rather than guessed, so a forced palette
    // looks like the desktop it sits on. The dim colour is Breeze's ForegroundInactive:
    // an earlier guess of #7f8c8d was far too dark against the dark background, which
    // left the caption and the break ring muddy.
    readonly property color overlayBackgroundColor: overlayThemeForced
        ? (overlayThemeDark ? "#202326" : "#eff0f1")
        : root.themeSurfaceColor
    readonly property color overlayTextColor: overlayThemeForced
        ? (overlayThemeDark ? "#fcfcfc" : "#232629")
        : root.themeTextColor
    readonly property color overlayDimColor: overlayThemeForced
        ? (overlayThemeDark ? "#a1a9b1" : "#707d8a")
        : root.themeDimColor
    readonly property color overlayHighlightColor: overlayThemeForced
        ? "#3daee9"
        : root.themeAccentColor

    // The overlay's equivalents of getCircleColor()/getTextColor(), which stay as
    // they are for the popup - only the overlay takes a palette of its own.
    function overlayCircleColor() {
        return isBreak() ? overlayDimColor : overlayHighlightColor;
    }

    function overlayCaptionColor() {
        return isBreak() ? overlayDimColor : overlayTextColor;
    }

    // Nothing to fill: a flow counts up with no target, and an overrunning break has
    // already spent its length, which the fraction reports as an empty ring. Both are
    // still actively running, so the ring sweeps instead of sitting at 0 or 100%.
    readonly property bool progressIndeterminate: timer.running
        && ((flowmodoroModeEnabled && !isBreak()) || breakOvertime)

    function getCircleColor() {
        return isBreak() ? themeDimColor : themeAccentColor;
    }

    function getTextColor() {
        return isBreak() ? themeDimColor : themeTextColor;
    }

    // Walks whichever set of overlays exists. Only one Instantiator is active at a
    // time, but iterating both means no caller has to know which.
    function forEachOverlay(fn) {
        // The layer sets live behind Loaders, so their item is null until loaded.
        var sets = [breakOverlays, breakOverlaysPlain,
                    breakOverlaysLayer.item, breakOverlaysPlainLayer.item];
        for (var s = 0; s < sets.length; s++) {
            if (!sets[s])
                continue;
            for (var i = 0; i < sets[s].count; i++) {
                var overlay = sets[s].objectAt(i);
                if (overlay)
                    fn(overlay);
            }
        }
    }

    function hideBreakOverlays() {
        forEachOverlay(function(overlay) {
            overlay.hide();
        });
    }

    // Single entry point for the fullscreen overlay: every state transition calls
    // this, so the overlay can never be left up after the break it belongs to.
    function syncBreakDialog() {
        var wanted = breakOverlayWanted;
        forEachOverlay(function(overlay) {
            if (wanted)
                overlay.showOnItsScreen();
            else
                overlay.hide();
        });
    }

    function executeScript(state) {
        switch (state) {
        case 0:
            if (settings.focus_stop_script_enabled)
                executable.exec(["sh", settings.focus_stop_script_filepath]);
            break;
        case 1:
            if (isBreak()) {
                if (settings.focus_start_break_script_enabled)
                    executable.exec(["sh", settings.focus_start_break_script_filepath]);
            } else if (settings.focus_start_focus_script_enabled) {
                executable.exec(["sh", settings.focus_start_focus_script_filepath]);
            }
            break;
        case 2:
            if (isBreak()) {
                if (settings.focus_end_break_script_enabled)
                    executable.exec(["sh", settings.focus_end_break_script_filepath]);
            } else if (settings.focus_end_focus_script_enabled) {
                executable.exec(["sh", settings.focus_end_focus_script_filepath]);
            }
            break;
        }
    }

    function isBreak() {
        return TimerLogic.isBreak(stateVal);
    }

    function isLongBreak() {
        return TimerLogic.isLongBreak(stateVal, numberOfSessions);
    }

    // Which of the shared presets the configured durations amount to, or
    // presetCount() for a custom set. Same derivation the config page uses.
    readonly property int currentPreset: TimerLogic.matchPreset(settings.focus_focus_time, settings.focus_short_break_time, settings.focus_long_break_time)

    function applyPreset(index) {
        var preset = TimerLogic.presetAt(index);
        settings.focus_focus_time = preset.focus;
        settings.focus_short_break_time = preset.shortBreak;
        settings.focus_long_break_time = preset.longBreak;
        // focus_time changing already routes through onFocusTimeChanged -> stop(),
        // so the timer restarts on the new durations rather than finishing the old.
    }

    function presetLabel(index) {
        var preset = TimerLogic.presetAt(index);
        return i18n("%1 / %2 min", preset.focus, preset.shortBreak);
    }

    // A session going (or a break counting past its end): Glance's strip shows it
    readonly property bool active: timer.running || breakOvertime
    // Stopped part-way through a session (not at its start): the panel keeps the pill to resume
    readonly property bool paused: !timer.running && !breakOvertime
        && Math.abs(counterMilliseconds - initialSeconds * 1000) >= 1000

    // Tooltip text, for Glance's panel
    readonly property string tooltipText: timeText + "\n" + getToolTipText()


    // Startup runs once both of these are true: the short deferral below has elapsed, and
    // the boot id has either arrived or been given up on. Restoring before the id is known
    // would resume a session the machine was rebooted out of.
    // False until Component.onCompleted has run. Everything that happens before that is the
    // applet building itself, not the user doing something.
    property bool constructed: false
    property bool startupDelayed: false
    property bool bootIdSettled: false
    property bool startupDone: false

    // The kernel boot id, empty until read. Identifies the boot the machine is on, which is
    // how a plasmashell restart is told apart from a reboot without the session having to
    // write itself down every few seconds to prove the machine stayed up.
    property string bootId: ""
    readonly property string bootIdCmd: "cat /proc/sys/kernel/random/boot_id"

    // The read is asynchronous, and a click in the moment before it answers saves a session
    // stamped with no boot id at all - which sessionIsStale() can only read as "cannot tell",
    // so that session would survive a reboot and be resumed on the other side. The state the
    // user was found with had exactly that: an empty bootId. Stamping it as soon as the id
    // arrives closes the window.
    onBootIdChanged: {
        if (sessionReady && bootId !== "")
            saveSession();
    }

    // Startup is deferred by a moment and by the boot id read, and the applet is live in the
    // meantime. Anyone who starts or stops a session inside that window has said what they
    // want, so the pending startup must not act on top of it: without this, restoreSession()
    // could replace the session just started, or autostart could start a second one - firing
    // the start notification and the start script twice and inhibiting do-not-disturb again.
    function claimStartup() {
        // Only a real interaction may claim startup. stop() is also called from the config
        // handlers - onFocusTimeChanged and onFlowmodoroModeEnabledChanged both fire while the
        // configuration loads - and those calls used to mark startup as spent before it had
        // run, so autostart never started anything. Nobody can click before construction ends,
        // so that is the line between the two (gitlab #47).
        if (!constructed)
            return;
        if (startupDone)
            return;
        startupDone = true;
        // The user's session is worth writing down; nothing else has been restored over it.
        sessionReady = true;
    }

    function beginStartup() {
        if (startupDone || !startupDelayed || !bootIdSettled)
            return;
        startupDone = true;
        // A picked-up session wins over autostart: replacing it with a fresh one
        // would be exactly the loss this is meant to prevent.
        var resumed = restoreSession();
        // Only now may anything be written back.
        sessionReady = true;
        if (resumed)
            return;
        if (settings.focus_autostart)
            start();
    }

    // Deferred rather than run from Component.onCompleted. Restoring can start a timer, show
    // fullscreen overlays, fire a notification and spawn the do-not-disturb inhibitor - all
    // while the applet is still being constructed and, at login, while plasmashell itself is
    // still coming up. That is the moment the shell was reported to crash on Fedora 44
    // (gitlab #59). A short wait costs an idle dial for half a second and takes the whole
    // sequence off the startup path.
    Timer {
        id: startupRestore

        interval: 600
        repeat: false
        onTriggered: {
            root.startupDelayed = true;
            root.beginStartup();
        }
    }

    // The boot id read is a few milliseconds, but the session must still come back if it
    // never answers at all: without an id the age of the state is the only test left.
    Timer {
        id: bootIdTimeout

        interval: 2500
        repeat: false
        onTriggered: {
            root.bootIdSettled = true;
            root.beginStartup();
        }
    }

    Component.onCompleted: {
        // A pass later, so nothing reads the theme while the shell is still building and
        // attaching the representations - which is when the null-receiver crash happened.
        Qt.callLater(function() {
            root.paletteReady = true;
        });
        constructed = true;
        executable.exec(bootIdCmd, function(cmd, exitCode, exitStatus, stdout) {
            if (exitCode === 0)
                root.bootId = ("" + stdout).trim();
            root.bootIdSettled = true;
            root.beginStartup();
        });
        bootIdTimeout.start();
        startupRestore.start();
    }

    // Removing the applet mid-session would otherwise leave the kde-inhibit child
    // holding notifications suppressed: nothing else on this path releases it.
    Component.onDestruction: {
        saveSession();
        doNotDisturbDisable();
    }

    NotificationManager {
        id: notificationManager
        defaultIcon: "chronometer"
    }

    Sfx {
        id: sfx
    }

    // Polled rather than aimed at midnight, so a machine that slept through it still
    // turns the day over within a minute of waking.
    Timer {
        id: dayTurnover

        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            var day = TimerLogic.dayKey(new Date());
            if (day !== root.today)
                root.today = day;
        }
    }

    // A break that has run out keeps counting, but the single sound at the moment it
    // ended is the easiest one to miss - that moment is usually the one spent away
    // from the desk. The reminder repeats the break-end sound until the overrun is
    // ended by hand, and respects the break-end sound setting: turning that off
    // means silence here too.
    Timer {
        id: overrunReminder

        interval: TimerLogic.overrunReminderMs(settings.focus_break_overrun_repeat_seconds)
        repeat: true
        running: root.breakOvertime && settings.focus_break_overrun_repeat_enabled
        onTriggered: root.playSound(root.soundFor(true, true))
    }

    // A flow counts up with no end, so there is nothing to stop it being left running
    // after the work stopped - a walk away with the timer still going is the failure mode
    // this mode has and the countdown does not. The reminder asks, and carries the way out
    // with it, so the flow can be ended from the notification instead of the panel.
    //
    // No sound, deliberately: this is a question, not a deadline, and the break-end sound
    // would announce something that has not happened.
    Timer {
        id: flowReminder

        interval: TimerLogic.flowReminderMs(settings.focus_flow_reminder_minutes)
        repeat: true
        running: timer.running && root.flowmodoroModeEnabled && !root.isBreak()
                 && settings.focus_flow_reminder_enabled
        // The interval counts from when the timer started running, so a flow picked up
        // after a plasmashell restart is asked about a full interval later rather than
        // immediately.
        onTriggered: notificationManager.notifyActions(i18n("Still in flow? %1 so far.", root.timeText),
                                                       [{
                                                           "label": i18n("Take a break"),
                                                           "action": root.skip
                                                       }, {
                                                           // Restarts the wait, so carrying on
                                                           // buys a full interval rather than
                                                           // leaving the original cadence to
                                                           // ask again moments later.
                                                           "label": i18n("Keep going"),
                                                           "action": function() {
                                                               flowReminder.restart();
                                                           }
                                                       }])
    }

    // Every running session, not only a flow. saveSession() is otherwise called at
    // transitions alone, so savedAt ages with the session and sessionIsStale() cannot tell a
    // session that has been running for an hour from one that was written an hour ago and
    // then abandoned - plasmashell gone, or the machine asleep. A write a minute is what lets
    // the age test stand on its own, without exemptions that invent time.
    Timer {
        id: sessionKeepalive

        interval: 60 * 1000
        repeat: true
        running: root.sessionReady && timer.running
        onTriggered: root.saveSession()
    }

    Timer {
        id: timer

        // The counter reads the wall clock, so the tick rate only bounds how
        // stale the display can be, not how accurate the countdown is.
        interval: 250
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: setTime()
    }

    // org.kde.layershell is optional: layer-shell-qt is not installed on every
    // distribution, and importing a missing module from a file the applet loads takes the
    // whole applet down - which is exactly what happened on Kubuntu 25.10 (gitlab #58).
    //
    // Created dynamically instead, so a missing module is a component status this can read
    // rather than a fatal load error. Without it the overlay is an ordinary window: it still
    // covers every screen, it just does not follow a virtual desktop switch.
    readonly property bool layerShellAvailable: {
        var probe = Qt.createComponent(Qt.resolvedUrl("LayerShellProbe.qml"), Component.PreferSynchronous);
        var ready = probe.status === Component.Ready;
        probe.destroy();
        return ready;
    }

    // One overlay per screen. A single window covers only its own display, so a
    // break left every other monitor visible (gitlab #19).
    //
    // Two Instantiators rather than one, because the blurred and plain overlays are
    // different window types and a QML root type cannot be switched at runtime. Only
    // one is ever active, so the loops below still see exactly one overlay per screen.
    readonly property bool blurredOverlay: settings.focus_break_overlay_blur

    // Whether an overlay belongs on screen at all. The Instantiators below key off this, so
    // the windows exist only during a break rather than from the moment the applet loads.
    //
    // They used to be built as soon as the applet did: one fullscreen window per screen,
    // created while plasmashell was still starting, hidden and waiting. That is a poor trade
    // at the best of times and a plausible cause of the shell crashing at login on Fedora 44
    // when a session was restored mid-startup (gitlab #59).
    readonly property bool breakOverlayWanted: settings.focus_show_fullscreen_break
                                               && isBreak()
                                               && timer.running

    Instantiator {
        id: breakOverlays

        active: breakOverlayWanted && blurredOverlay && !layerShellAvailable
        model: Qt.application.screens
        onObjectAdded: (index, object) => syncBreakDialog()

        delegate: BreakOverlay {
            applet: root
            screenGeometry: Qt.rect(modelData.virtualX, modelData.virtualY, modelData.width, modelData.height)
            onCloseRequested: root.hideBreakOverlays()
        }
    }

    Instantiator {
        id: breakOverlaysPlain

        active: breakOverlayWanted && !blurredOverlay && !layerShellAvailable
        model: Qt.application.screens
        onObjectAdded: (index, object) => syncBreakDialog()

        delegate: BreakOverlayPlain {
            applet: root
            screen: modelData
            screenGeometry: Qt.rect(modelData.virtualX, modelData.virtualY, modelData.width, modelData.height)
            onCloseRequested: root.hideBreakOverlays()
        }
    }

    // The layer-shell variants are reached by URL, never by type name. A static type
    // reference is an eager dependency - QML resolves every composite type a document names,
    // including in an inactive delegate - so naming them here made this file fail to load
    // wherever org.kde.layershell is absent, which is the failure #58 reported. The probe
    // above never got the chance to matter.
    //
    // A Loader source is resolved at runtime, so on a machine without the module these files
    // are never opened. Clearing the source unloads them, which also keeps the windows tied
    // to a break actually being on screen (gitlab #59).
    Loader {
        id: breakOverlaysLayer

        // No `active:` here. It is evaluated at completion, which would force the
        // layerShellAvailable probe - and with it the org.kde.layershell import - onto
        // plasmashell's startup path, which is what #59 was about. The source expression
        // below is false at startup, so the probe stays lazy until the first break.
        source: (breakOverlayWanted && blurredOverlay && layerShellAvailable)
            ? Qt.resolvedUrl("BreakOverlaySetLayer.qml") : ""
        onLoaded: {
            item.applet = root;
            item.closeRequested.connect(root.hideBreakOverlays);
            root.syncBreakDialog();
        }
    }

    Loader {
        id: breakOverlaysPlainLayer

        source: (breakOverlayWanted && !blurredOverlay && layerShellAvailable)
            ? Qt.resolvedUrl("BreakOverlaySetLayerPlain.qml") : ""
        onLoaded: {
            item.applet = root;
            item.closeRequested.connect(root.hideBreakOverlays);
            root.syncBreakDialog();
        }
    }

    executable: ExecUtil {
        id: executable
    }

    // Locking the screen pauses a running focus block (you have walked away), and unlocking
    // resumes it - only one this paused. Breaks run on: being away is what they are for.
    // Polled, as Shift does: the lock has no signal QML can reach without a plugin.
    property bool pausedByLock: false
    readonly property string lockCmd: "dbus-send --session --print-reply=literal --dest=org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive"
    Timer {
        interval: 5 * 1000
        repeat: true
        running: root.settings.focus_pause_on_lock_enabled
            && ((timer.running && !root.isBreak()) || root.pausedByLock)
        onTriggered: executable.exec(root.lockCmd, function(cmd, exitCode, exitStatus, stdout) {
            if (exitCode !== 0)
                return;
            var locked = /true/.test(stdout);
            if (locked && timer.running && !root.isBreak()) {
                root.pause();
                root.pausedByLock = true;
            } else if (!locked && root.pausedByLock) {
                root.pausedByLock = false;
                if (!timer.running)
                    root.start();
            }
        })
    }
}
