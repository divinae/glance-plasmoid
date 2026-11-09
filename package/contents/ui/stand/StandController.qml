import "../common"
import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Shift's sit/stand cycle inside Glance: everything Shift's main.qml held but its
// representations, reading Glance's stand_* settings through `cfg`. Its view is StandView.
Item {
    id: root

    // Plasmoid.configuration, handed in by Glance
    required property var settings

    readonly property var workHours: ({
        enabled: settings.stand_work_hours_enabled,
        startMinutes: settings.stand_work_start_minutes,
        endMinutes: settings.stand_work_end_minutes,
        weekdaysOnly: Cycle.weekendsOff(settings.stand_weekends, settings.stand_work_hours_enabled,
                                        settings.stand_work_weekdays_only)
    })
    // "weekend", "hours", or "" inside the working hours
    readonly property string offReason: Cycle.offReason(new Date(nowMs), workHours)
    readonly property bool offHours: offReason !== ""
    readonly property var cfg: ({
        sitMinutes: settings.stand_sit_minutes,
        standMinutes: settings.stand_stand_minutes,
        offHours: offHours
    })
    readonly property bool deskEnabled: settings.stand_desk_enabled
    readonly property int goalMinutes: settings.stand_daily_goal_minutes

    // The cycle and the standing history are plain objects from cycle.js. Each change
    // assigns a new object, which is what makes the bindings below re-evaluate.
    property var cycle: Cycle.fresh("sit")
    property var history: ({})
    property real nowMs: Date.now()
    property real lastTickMs: Date.now()
    // Standing time not yet written to config. Writing every second would rewrite the
    // applet's config file every second.
    property real unsavedStandMs: 0

    // Do Not Disturb, as the notification server reports it. Reminders wait while it is on.
    property bool dndActive: false
    // A focus block is running (set by Glance when Focus is on and the two are linked):
    // reminders and desk moves wait for its break, like they do for Do Not Disturb.
    property bool holdForFocus: false
    // A focus break (or its overrun) is on: away from the desk, so the cycle stands still -
    // the break counts as neither sitting nor standing.
    property bool focusBreak: false
    // A meeting is on (from Event Calendar, set by Glance): reminders and desk moves wait for
    // its end, and a switch due soon is made then
    property bool holdForMeeting: false
    // Either reason to keep quiet
    readonly property bool quiet: dndActive || holdForFocus || holdForMeeting
    // A reminder held back by Do Not Disturb or a focus block, shown once it ends.
    property bool pendingRemind: false
    readonly property string dndCmd: "dbus-send --session --print-reply=literal --dest=org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.DBus.Properties.Get string:org.freedesktop.Notifications string:Inhibited"
    readonly property string lockCmd: "dbus-send --session --print-reply=literal --dest=org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive"

    readonly property string status: Cycle.status(cycle, nowMs, { offHours: offHours })
    // Not counting toward a switch: the panel drops the ring and dims the figure.
    readonly property bool idle: status === "away" || status === "paused" || status === "off"
    readonly property bool switchDue: status === "due"
    readonly property real remainingMs: Cycle.remainingMs(cycle, cfg)
    // Changes once a day, unlike nowMs, so what depends on the day alone - the streak,
    // the chart's days - is not recomputed every second.
    readonly property string todayKey: Cycle.dayKey(new Date(nowMs))
    readonly property real todayMinutes: Cycle.minutesOn(history, todayKey) + unsavedStandMs / 60000
    readonly property int streakDays: Cycle.streak(history, Cycle.parseDayKey(todayKey), goalMinutes)
    // The last week for the chart. Today's bar takes the live todayMinutes separately, so
    // the chart's delegates are not rebuilt every second.
    readonly property var weekDays: Cycle.lastDays(history, Cycle.parseDayKey(todayKey), 7)

    property real lastNotifiedMs: 0
    // While a switch is due and ignored, ask again this often.
    readonly property real renotifyMs: 10 * 60 * 1000

    // Theme colours are read here and only here, then handed to the views; see
    // tests/theme_audit.py for why per-delegate reads are not allowed.
    property bool paletteReady: false
    readonly property color themeTextColor: paletteReady ? Kirigami.Theme.textColor : "transparent"
    readonly property color themeDimColor: paletteReady ? Kirigami.Theme.disabledTextColor : "transparent"
    readonly property color themeAccentColor: paletteReady ? Kirigami.Theme.highlightColor : "transparent"
    readonly property color themeDueColor: paletteReady ? Kirigami.Theme.neutralTextColor : "transparent"
    readonly property color themeBackgroundColor: paletteReady ? Kirigami.Theme.backgroundColor : "transparent"
    readonly property color themeTrackColor: Qt.alpha(themeTextColor, 0.25)
    readonly property color ringColor: switchDue ? themeDueColor : themeAccentColor
    // The panel is translucent, and the accent blue measured 1.18:1 against it, so the
    // panel ring is drawn in the text colour like the other panel icons.
    readonly property color panelRingColor: switchDue ? themeDueColor : themeTextColor

    readonly property string iconName: {
        if (status === "away")
            return "system-lock-screen";
        if (status === "paused" || status === "off")
            return "media-playback-pause";
        // Installed into the icon theme by `make install`; see the Makefile.
        return cycle.position === "stand" ? "com.dv.stand-stand" : "com.dv.stand-sit";
    }

    // The posture now. Once a switch is due, the panel shows where to go instead.
    readonly property url postureIcon: Qt.resolvedUrl(cycle.position === "stand" ? "icons/person-stand.svg" : "icons/person-sit.svg")
    readonly property url nextArrowIcon: Qt.resolvedUrl("icons/arrow-next.svg")
    // A switch asked for while the desk was out of reach: the user has to make it with the
    // desk's own buttons, so the count carries on in the old position until they confirm.
    property string pendingPosition: ""
    readonly property bool deskOffline: deskEnabled && !desk.reachable
    readonly property bool showNextArrow: switchDue || status === "snoozed" || pendingPosition !== ""

    function statusText() {
        switch (status) {
        case "away":
            return i18n("Away");
        case "paused":
            return i18n("Paused");
        case "off":
            return offReason === "weekend" ? i18n("Weekend") : i18n("Outside working hours");
        case "due":
        case "snoozed":
            return cycle.position === "stand" ? i18n("Time to sit down") : i18n("Time to stand up");
        case "stand":
            return i18n("Standing");
        default:
            return i18n("Sitting");
        }
    }

    function countdownText() {
        if (focusBreak && !switchDue && !idle)
            return i18n("On hold during the focus break");
        if (status === "away")
            return i18n("Paused while the screen is locked");
        if (status === "paused")
            return cycle.pausedUntilMs === Cycle.UNTIL_RESUMED
                ? i18n("Until you resume")
                : i18n("Until %1", Qt.formatTime(new Date(cycle.pausedUntilMs), Locale.ShortFormat));
        if (status === "off" && offReason === "weekend")
            return workHours.enabled
                ? i18n("Reminders start again on Monday at %1", formatClock(workHours.startMinutes))
                : i18n("Reminders start again on Monday");
        if (status === "off")
            return i18n("Reminders start again at %1", formatClock(workHours.startMinutes));
        if (status === "snoozed")
            return i18n("Snoozed for %1", Cycle.formatMinutes(cycle.snoozeUntil - nowMs));
        if (cycle.dueSinceMs && holdForMeeting)
            return i18n("Due for %1, waits for the meeting to end", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        if (cycle.dueSinceMs && holdForFocus)
            return i18n("Due for %1, waits for the focus break", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        if (cycle.dueSinceMs && dndActive)
            return i18n("Due for %1, reminder waits for Do Not Disturb to end", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        if (cycle.dueSinceMs)
            return i18n("Due for %1", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        return cycle.position === "stand"
            ? i18n("Sit down in %1", Cycle.formatMinutes(remainingMs))
            : i18n("Stand up in %1", Cycle.formatMinutes(remainingMs));
    }

    function formatClock(minutes) {
        return Qt.formatTime(new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60), Locale.ShortFormat);
    }

    function todayText() {
        var stood = Cycle.formatMinutes(todayMinutes * 60000);
        if (goalMinutes <= 0)
            return i18n("Stood %1 today", stood);
        return i18n("Stood %1 of %2 today", stood, Cycle.formatMinutes(goalMinutes * 60000));
    }

    function heightText() {
        return isNaN(desk.heightCm) ? i18n("Desk height unknown") : i18n("Desk at %1 cm", Math.round(desk.heightCm));
    }

    // The user asked to be in `position`. With a desk, the desk moves and its height,
    // read back afterwards, moves the cycle. Without one, the click is the record.
    // A desk that does not answer cannot be the record, and neither can the request: the
    // switch waits for the user to say they made it.
    function goTo(position) {
        if (!deskEnabled)
            setPosition(position);
        else if (desk.reachable)
            desk.moveTo(position);
        else
            awaitManualSwitch(position);
    }

    function awaitManualSwitch(position) {
        if (position === cycle.position) {
            pendingPosition = "";
            return;
        }
        pendingPosition = position;
        if (!settings.stand_notification_enabled)
            return;
        notifications.notifyActions(position === "stand"
            ? i18n("The desk is not reachable. Raise it with its own buttons, then press Done.")
            : i18n("The desk is not reachable. Lower it with its own buttons, then press Done."), [
            { label: i18n("Done"), action: root.confirmPending },
            { label: i18n("Cancel"), action: root.cancelPending }
        ], position === "stand" ? "go-up" : "go-down");
    }

    function confirmPending() {
        if (pendingPosition)
            setPosition(pendingPosition);
        pendingPosition = "";
    }

    function cancelPending() {
        pendingPosition = "";
    }

    function setPosition(position) {
        pendingPosition = "";
        if (position === cycle.position)
            return;
        flushStanding();
        cycle = Cycle.moveTo(cycle, position);
        lastNotifiedMs = 0;
        saveCycle();
    }

    // The switch to the other position, as the reminder and the pill's card offer it: a desk that
    // moves, the button moves it; otherwise you switch yourself, and Done records it there and
    // then (no second confirmation). { label, run }
    function switchAction() {
        var target = Cycle.opposite(cycle.position);
        return deskEnabled && desk.reachable
            ? { label: i18n("Move the desk"), run: function() { root.goTo(target); } }
            : { label: i18n("Done"), run: function() { root.setPosition(target); } };
    }

    function snooze() {
        cycle = Cycle.snooze(cycle, Date.now(), settings.stand_snooze_minutes);
        saveCycle();
    }

    // minutes <= 0 pauses until resume().
    function pause(minutes) {
        cycle = Cycle.pause(cycle, Date.now(), minutes);
        saveCycle();
    }

    function resume() {
        cycle = Cycle.resume(cycle);
        saveCycle();
    }

    function saveCycle() {
        settings.stand_cycle_state = Cycle.serialize(cycle, Date.now());
    }

    function flushStanding() {
        if (unsavedStandMs <= 0)
            return;
        // Credited to the day it is flushed on. Flushed every minute, so at most a
        // minute of a session spanning midnight lands on the wrong day.
        history = Cycle.addStanding(history, Cycle.dayKey(new Date()), unsavedStandMs, 90);
        unsavedStandMs = 0;
        settings.stand_stand_history = JSON.stringify(history);
    }

    function tick() {
        var now = Date.now();
        var dt = now - lastTickMs;
        lastTickMs = now;
        if (focusBreak) {
            // The cycle stands still, but a due switch is still re-announced
            nowMs = now;
            if (switchDue && !pendingPosition && lastNotifiedMs && now - lastNotifiedMs >= renotifyMs)
                remind();
            return;
        }
        if (Cycle.countsStanding(cycle, now, offHours) && dt > 0 && dt <= Cycle.MAX_TICK_MS)
            unsavedStandMs += dt;
        cycle = Cycle.advance(cycle, now, dt, cfg);
        nowMs = now;
        // Not while a switch is waiting for its Done: the user is already on it.
        if (switchDue && !pendingPosition && lastNotifiedMs && now - lastNotifiedMs >= renotifyMs)
            remind();
    }

    function remind() {
        lastNotifiedMs = Date.now();
        if (quiet) {
            pendingRemind = true;
            return;
        }
        var standing = cycle.position === "stand";
        if (settings.stand_sfx_enabled && settings.stand_sfx_filepath)
            sfx.play(settings.stand_sfx_filepath, settings.stand_sound_volume / 100);
        if (!settings.stand_notification_enabled)
            return;
        var next = switchAction();
        notifications.notifyActions(standing ? i18n("Time to sit down.") : i18n("Time to stand up."), [
            { label: next.label, action: next.run },
            { label: i18n("Snooze %1 min", settings.stand_snooze_minutes), action: root.snooze }
        ], standing ? "go-down" : "go-up");
    }

    onSwitchDueChanged: {
        if (!switchDue) {
            pendingRemind = false;
            return;
        }
        actOnDue();
    }

    onQuietChanged: {
        if (quiet || !pendingRemind)
            return;
        pendingRemind = false;
        if (switchDue)
            actOnDue();
    }

    // Stand up for a meeting ("Stand up for meetings"): the desk rises at its start, and goes
    // back down at its end if it rose for it
    property bool roseForMeeting: false
    function meetingStarted() {
        if (!settings.stand_stand_for_meetings || idle || cycle.position === "stand")
            return;
        if (deskEnabled && desk.reachable && desk.moveTo("stand"))
            roseForMeeting = true;
    }
    // switchDueSoon: also make a switch due within 10 minutes now ("Wait for meetings")
    function meetingEnded(switchDueSoon) {
        if (roseForMeeting && deskEnabled && desk.reachable && cycle.position === "stand")
            desk.moveTo("sit");
        else if (switchDueSoon)
            switchAtBreak(10 * 60 * 1000);
        roseForMeeting = false;
    }

    // A focus break has started and the next switch is close: make it now rather than a few
    // minutes into the next block. Moves the desk when it moves by itself, reminds otherwise.
    function switchAtBreak(withinMs) {
        if (idle || pendingPosition || switchDue || remainingMs > withinMs)
            return;
        if (deskEnabled && desk.reachable && settings.stand_auto_move_enabled
                && desk.moveTo(Cycle.opposite(cycle.position))) {
            lastNotifiedMs = Date.now();
            return;
        }
        remind();
    }

    function actOnDue() {
        // A desk moving by itself mid-presentation is worse than a notification.
        if (quiet) {
            pendingRemind = true;
            return;
        }
        // Counted as the reminder, so a move that fails or leaves the desk where it was
        // is followed by the usual nagging rather than a switch due forever in silence.
        if (deskEnabled && desk.reachable && settings.stand_auto_move_enabled && desk.moveTo(Cycle.opposite(cycle.position))) {
            lastNotifiedMs = Date.now();
            return;
        }
        remind();
    }

    // A desk that is off or out of range fails every poll, so a read failure notifies once
    // per run of failures, and only as a notification would: not with notifications off,
    // and not during Do Not Disturb. A failed move was asked for, so it always says so -
    // and when the switch is due, it is followed by the reminder the move stood in for.
    // A desk out of reach is shown on the panel and in the popup, not announced as an
    // error. A move the desk never got waits for the user to make it by hand and confirm.
    // What still notifies is a desk that answers but will not go: stopped short by
    // something in the way, or a command that does not exist.
    function reportDeskFailure(what, detail) {
        console.warn("Stand:", what, "failed:", detail);
        if (what === "height")
            return;
        if (!desk.reachable) {
            awaitManualSwitch(desk.target);
            return;
        }
        if (settings.stand_notification_enabled && !dndActive)
            errorNotifications.notify(i18n("Could not move the desk: %1", detail), "", null, "dialog-warning");
        if (switchDue)
            remind();
    }

    onOffHoursChanged: {
        if (!offHours) {
            cycle = Cycle.startDay(cycle);
            saveCycle();
        }
    }

    // The desk driver, for the view
    readonly property alias deskDriver: desk

    // Tooltip lines, for Glance's status segment
    readonly property string tooltipText: statusText() + "\n" + countdownText() + "\n" + todayText()
        + (pendingPosition ? "\n" + (pendingPosition === "stand"
            ? i18n("Waiting for you to confirm you are standing")
            : i18n("Waiting for you to confirm you are sitting")) : "")
        + (deskOffline ? "\n" + i18n("Desk not reachable") : "")

    Component.onCompleted: {
        // A pass later, so nothing reads the theme while the shell is still attaching
        // the representations.
        Qt.callLater(function() {
            root.paletteReady = true;
        });
        var now = Date.now();
        cycle = Cycle.restore(settings.stand_cycle_state, now);
        history = Cycle.parseHistory(settings.stand_stand_history);
        nowMs = now;
        lastTickMs = now;
        if (deskEnabled)
            desk.readHeight();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    // Flushes the standing time and the cycle, so a crash or restart loses at most a minute.
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            root.flushStanding();
            root.saveCycle();
        }
    }

    // GetSessionIdleTime would be the better signal, but KDE's Wayland session answers it
    // with NotSupported, so the lock is what marks the user as gone. Plasma locks after
    // its own idle timeout, so in practice this follows idleness too.
    Timer {
        interval: 15 * 1000
        running: settings.stand_away_on_lock_enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.exec(root.lockCmd, function(cmd, exitCode, exitStatus, stdout) {
            if (exitCode !== 0)
                return;
            var locked = /true/.test(stdout);
            if (locked && !root.cycle.awaySinceMs) {
                root.flushStanding();
                root.cycle = Cycle.leave(root.cycle, Date.now());
            } else if (!locked && root.cycle.awaySinceMs) {
                root.cycle = Cycle.returnAt(root.cycle, Date.now());
                root.lastNotifiedMs = 0;
                if (root.deskEnabled)
                    desk.readHeight();
            }
        })
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.exec(root.dndCmd, function(cmd, exitCode, exitStatus, stdout) {
            // No notification server, or one without the property: nothing to wait for.
            root.dndActive = exitCode === 0 && /true/.test(stdout);
        })
    }

    onCycleChanged: {
        // Turning the lock check off mid-absence must not leave the cycle paused for good.
        if (cycle.awaySinceMs && !settings.stand_away_on_lock_enabled)
            cycle = Cycle.returnAt(cycle, Date.now());
    }

    Timer {
        interval: settings.stand_desk_poll_seconds * 1000
        running: root.deskEnabled && !root.cycle.awaySinceMs
        repeat: true
        onTriggered: desk.readHeight()
    }

    Desk {
        id: desk

        sitCmd: settings.stand_desk_sit_cmd
        standCmd: settings.stand_desk_stand_cmd
        heightCmd: settings.stand_desk_height_cmd
        sitHeightCm: settings.stand_sit_height_cm
        standHeightCm: settings.stand_stand_height_cm
        // The height is the truth, so it settles any switch still waiting for a Done.
        onHeightRead: cm => root.setPosition(Cycle.positionFromHeight(cm, sitHeightCm, standHeightCm))
        onFailed: (what, detail) => root.reportDeskFailure(what, detail)
    }

    ExecUtil {
        id: executable
    }

    Sfx {
        id: sfx
    }

    NotificationManager {
        id: notifications
    }

    // Its own notification, so an error does not replace a reminder and take its
    // Stand now / Snooze buttons with it.
    NotificationManager {
        id: errorNotifications
    }
}
