/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import com.dv.glance.private as Island

import "stand" as Stand
import "focus" as Focus
import "common" as Common

PlasmoidItem {
    id: root

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int panelLocation: Plasmoid.location
    readonly property var cfg: Plasmoid.configuration

    // ---- active window -------------------------------------------------------
    readonly property Item activeTask: windowTasks.activeTaskItem
    readonly property bool hasWindow: activeTask !== null
    readonly property bool fullScreen: hasWindow && activeTask.isFullScreen && activeTask.isActive

    readonly property string windowText: {
        if (!activeTask) {
            return cfg.placeholder;
        }
        let text;
        switch (cfg.compactStyle) {
        case 1:
            text = activeTask.title || activeTask.appName;
            break;
        case 2:
            text = activeTask.appName === activeTask.title || activeTask.title === ""
                ? activeTask.appName
                : activeTask.appName + " — " + activeTask.title;
            break;
        default:
            text = activeTask.appName || activeTask.title;
        }
        return truncate(text);
    }

    // ---- media ---------------------------------------------------------------
    readonly property var player: mprisModel.currentPlayer
    // A player with something to show: a track, an artist or album, or playing. A browser keeps
    // one registered for as long as it's open, with nothing in it: that's "nothing playing"
    readonly property bool hasPlayer: player !== null && player !== undefined
        && (!!player.track || !!player.artist || !!player.album
            || player.playbackStatus === Mpris.PlaybackStatus.Playing)
    // More than one: the Media tab stays even when this one is empty, to switch to another
    readonly property int playerCount: mprisModel.count
    readonly property bool playing: mediaStateItem.playing
    readonly property bool showMediaInPanel: cfg.showMedia && cfg.mediaInPanel && playing
    readonly property string mediaText: {
        if (!hasPlayer) {
            return "";
        }
        const track = player.track || player.identity || "";
        return truncate(player.artist ? track + " — " + player.artist : track);
    }

    // ---- panel strip: what the text shows, highest priority first ------------
    property string noticeText: ""
    // A meeting is on (timed, with a link or guests, not declined): Focus and Shift give way
    readonly property bool inMeeting: cfg.calendarEnabled && calendarSource.meetingNow !== null
    // The events, for the pills' cards
    readonly property Item calendar: calendarSource
    // At a meeting's real start and end (CalendarSource tells them apart from one that merely
    // appears or vanishes)
    Connections {
        target: calendarSource
        enabled: root.cfg.calendarEnabled
        function onMeetingStarted(ev) {
            // The strip flashes once, as for a notification (not during Do Not Disturb)
            if (!notificationWatcher.doNotDisturb) {
                root.pulseRequested(ev.color || Kirigami.Theme.highlightColor);
            }
            if (root.focusTimer && root.cfg.focus_meeting_pause) {
                root.focusTimer.pauseForMeeting();
            }
            if (root.stand) {
                root.stand.meetingStarted();
            }
        }
        function onMeetingEnded(ev) {
            if (root.focusTimer) {
                root.focusTimer.meetingEnded();
            }
            // A beat later: Shift's hold for the meeting lifts first, so a reminder isn't held back
            Qt.callLater(() => {
                if (root.stand) {
                    root.stand.meetingEnded(root.cfg.stand_meeting_hold);
                }
            });
        }
    }

    // The meeting on now, or starting within the lead: the panel's text and its pill
    readonly property var meeting: cfg.calendarEnabled ? calendarSource.meeting : null
    // Before a meeting: its name and countdown in the strip, no pill. While it's on: only the
    // pill, and the strip goes back to the window
    readonly property var meetingOn: cfg.calendarEnabled ? calendarSource.meetingNow : null
    readonly property var meetingSoon: meeting !== null && meeting !== meetingOn ? meeting : null
    readonly property bool meetingInStrip: meetingSoon !== null && cfg.meetingInStrip
    readonly property bool meetingPill: meetingOn !== null && cfg.pillMeeting
    // The pill's text, while the meeting is on: the time left in it ("25 min", "1h05")
    readonly property string meetingCountdown: {
        if (!meetingOn) {
            return "";
        }
        const m = calendarSource.minutesLeft(meetingOn);
        return m < 60 ? i18nc("minutes left in the meeting", "%1 min", m)
            : i18nc("hours and minutes left in the meeting", "%1h%2", Math.floor(m / 60), String(m % 60).padStart(2, "0"));
    }
    // Event Calendar's popup, in place of Glance's drawer: on an event's details when given one
    // False when there's no Event Calendar in the shell (Glance then stays as it was)
    // Glance closes first: closing after, its focus going back could hide Event Calendar's popup
    function openEventCalendar(ev): bool {
        setOpen(false);
        return Island.CalendarBus.openEventCalendar(Plasmoid, ev ? ev.calendarId : "", ev ? ev.id : "");
    }
    // Event Calendar is there to show an event (its events come over D-Bus, from the widget itself)
    readonly property bool eventCalendarLinked: Island.CalendarBus.connected
    // The meeting given, else the one on now or next
    function joinMeeting(ev) {
        calendarSource.join(ev || meeting);
    }
    readonly property var stripEvent: !cfg.calendarEnabled ? null
        : meetingInStrip ? meetingSoon
        : meetingPill && calendarSource.stripEvent && calendarSource.stripEvent.id === meetingOn.id ? null
        : calendarSource.stripEvent
    // Time to sit down or stand up asks for something: it goes before media and the window
    readonly property bool standDue: stand !== null && stand !== undefined && stand.switchDue && !stand.pendingPosition
    readonly property bool focusActive: focusTimer !== null && focusTimer !== undefined && focusTimer.active
    readonly property string stripMode: noticeText !== "" ? "notice"
        : standDue ? "stand"
        : meetingInStrip ? "event"
        : showMediaInPanel ? "media"
        : stripEvent ? "event"
        : "window"
    readonly property string stripText: {
        switch (stripMode) {
        case "notice": return noticeText;
        case "stand": return stand.cycle.position === "stand" ? i18n("Time to sit down") : i18n("Time to stand up");
        case "media": return mediaText;
        case "event": return calendarSource.label(stripEvent, root.truncate);
        default: return windowText;
        }
    }

    // ---- hover / popup state --------------------------------------------------
    property bool pinnedByClick: false
    property bool compactHovered: false
    // The pointer is on a pill with a hover card: that opens, not the drawer
    property bool overCardPill: false
    onOverCardPillChanged: {
        if (overCardPill) {
            openTimer.stop();
        } else {
            // Off the pill, still on the strip: the drawer as usual
            maybeStartOpen();
        }
    }
    // Hovering opens the drawer after a moment, unless it's open, suppressed, or on a card pill
    function maybeStartOpen() {
        if (compactHovered && cfg.openOnHover && !open && !hoverSuppressed && !overCardPill) {
            openTimer.restart();
        }
    }
    property bool flyoutHovered: false
    // KWin's window menu (from the drawer's app icon) is up: the drawer stays under it. KWin
    // doesn't say when it closes, so this ends when the pointer comes back to the drawer, another
    // window becomes active, or after a while
    property bool windowMenuOpen: false
    // The window it's for: its becoming active (made so for the menu) doesn't end the hold
    property Item windowMenuTask: null
    // Glance's own menus open in the drawer (DrawerMenu, counted by IslandContent)
    property int menusOpen: 0
    // Something over the drawer that's part of it: it doesn't close under it
    readonly property bool holdOpen: menuModel.menuOpen || windowMenuOpen || menusOpen > 0
    onWindowMenuOpenChanged: if (windowMenuOpen) windowMenuTimeout.restart()
    Timer {
        id: windowMenuTimeout
        interval: 30000
        onTriggered: root.windowMenuOpen = false
    }
    // Tab to show next time the popup opens (e.g. "shelf" after a drag onto the strip)
    property string requestedTab: ""

    // ---- popup or drawer --------------------------------------------------------
    // The drawer is a layer-shell window of its own (drawer/Drawer.qml); Plasma's popup is the
    // fallback when it is turned off or org.kde.layershell is missing. `open` is the one state
    // both follow: Plasma's `expanded` for the popup, `drawerOpen` for the drawer.
    property var moduleProbes: ({})
    function moduleAvailable(probeFile: string): bool {
        if (!(probeFile in moduleProbes)) {
            const probe = Qt.createComponent(Qt.resolvedUrl(probeFile), Component.PreferSynchronous);
            moduleProbes[probeFile] = probe.status === Component.Ready;
            if (probe.status === Component.Error) {
                console.warn("Glance:", probe.errorString());
            }
            probe.destroy();
        }
        return moduleProbes[probeFile];
    }
    readonly property bool useDrawer: cfg.popupStyle === 0 && moduleAvailable("LayerShellProbe.qml")
    property bool drawerOpen: false
    readonly property bool open: useDrawer ? drawerOpen : expanded

    function setOpen(value: bool) {
        if (useDrawer) {
            drawerOpen = value;
        } else {
            expanded = value;
        }
    }
    onUseDrawerChanged: {
        drawerOpen = false;
        expanded = false;
    }

    function truncate(text: string): string {
        const max = cfg.maxTitleLength;
        return text.length > max ? text.slice(0, max - 1) + "…" : text;
    }

    // Keep files on the shelf: only their URLs are stored, the files stay where they are
    function shelve(urls): int {
        const list = (cfg.shelfItems || []).slice();
        let added = 0;
        for (const u of urls) {
            const s = String(u);
            if (s && list.indexOf(s) === -1) {
                list.push(s);
                ++added;
            }
        }
        if (added > 0) {
            Plasmoid.configuration.shelfItems = list;
        }
        return added;
    }
    // A drop of files: always as a copy, so the source never deletes what it "moved" here
    // (org.kde.draganddrop's DropArea: Qt Quick's never gets the drop of another app's drag here)
    function dropHasFiles(event): bool {
        return !!(event && event.mimeData && event.mimeData.urls && event.mimeData.urls.length > 0);
    }
    function acceptFiles(event): bool {
        if (!dropHasFiles(event)) {
            return false;
        }
        event.accept(Qt.CopyAction);
        shelve(event.mimeData.urls);
        return true;
    }

    function openOn(tab: string, pin: bool) {
        requestedTab = tab;
        if (pin) {
            pinnedByClick = true;
        }
        setOpen(true);
    }

    // ---- keep awake: no screen-off, lock or sleep while focusing (its break too, but not one
    // run past its end: nobody may be there) or in a meeting
    readonly property bool keepAwake: (cfg.focus_keep_awake && !!focusTimer && focusTimer.active && !focusTimer.breakOvertime)
        || (cfg.keepAwakeMeetings && inMeeting)
    Common.Inhibitor {
        what: "--power --screenSaver"
        active: root.keepAwake
    }

    toolTipMainText: ""
    toolTipSubText: ""
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    // Hover-opened popup must survive the app menu popup taking focus;
    // a click-pinned popup behaves like a normal applet popup.
    hideOnWindowDeactivate: pinnedByClick && !holdOpen

    // Another window became active (a click into an app or on the desktop): close, as a popup
    // does on losing focus. The drawer opened by hover never has the focus to lose.
    // Only another application counts: the drawer taking the focus leaves no active task.
    property Item taskWhenOpened: null
    onActiveTaskChanged: {
        if (activeTask !== windowMenuTask) {
            windowMenuOpen = false;
        }
        if (open && activeTask !== null && activeTask !== taskWhenOpened
                && !flyoutHovered && !compactHovered && !holdOpen) {
            setOpen(false);
        }
    }

    onOpenChanged: {
        if (root.open) {
            taskWhenOpened = activeTask;
        } else {
            pinnedByClick = false;
            windowMenuOpen = false;
            closeTimer.stop();
            menuModel.closeMenu();
        }
    }
    // With the drawer, Plasma's own expansion (the widget's shortcut) toggles the drawer instead
    onExpandedChanged: () => {
        if (root.useDrawer && root.expanded) {
            root.expanded = false;
            root.pinnedByClick = !root.drawerOpen;
            root.drawerOpen = !root.drawerOpen;
        }
    }

    Timer {
        id: openTimer
        interval: root.cfg.hoverDelay
        onTriggered: {
            if (root.compactHovered && !root.hoverSuppressed && !root.overCardPill) {
                root.setOpen(true);
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.cfg.closeDelay
        onTriggered: {
            if (!root.pinnedByClick && !root.compactHovered && !root.flyoutHovered && !root.holdOpen) {
                root.setOpen(false);
            }
        }
    }

    // A right-click (Plasma's context menu) keeps the drawer away until the pointer leaves: it
    // opening on hover took the focus and closed the menu
    property bool hoverSuppressed: false
    // Only keeps the drawer from opening: closing an open one as the menu appeared (its window
    // going, maybe with the keyboard focus) took Plasma's menu with it
    function suppressHover() {
        hoverSuppressed = true;
        openTimer.stop();
    }
    // Plasma says so just before it shows the menu (the right-click itself stays Plasma's)
    Connections {
        target: Plasmoid
        function onContextualActionsAboutToShow() {
            root.suppressHover();
        }
    }

    onCompactHoveredChanged: {
        if (!compactHovered) {
            hoverSuppressed = false;
        }
        if (compactHovered && hoverSuppressed) {
            return;
        }
        if (compactHovered) {
            closeTimer.stop();
            maybeStartOpen();
        } else {
            openTimer.stop();
            if (open) {
                closeTimer.restart();
            }
        }
    }

    onFlyoutHoveredChanged: {
        if (flyoutHovered) {
            // Back from the window menu (it covered the drawer while up)
            windowMenuOpen = false;
            closeTimer.stop();
        } else if (open) {
            closeTimer.restart();
        }
    }

    // ---- data -----------------------------------------------------------------
    PlasmaTasksModel {
        id: windowTasks
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByScreen: root.cfg.filterByScreen
    }

    Mpris.Mpris2Model {
        id: mprisModel
        // The players, which the model doesn't count itself (an Instantiator over it does; its
        // own C++ has slots named onRowsInserted…, so no handlers of that name here). Row 0 is
        // Plasma's multiplexer ("choose automatically"), not a player
        readonly property int count: Math.max(0, playerRows.count - 1)
    }
    Instantiator {
        id: playerRows
        model: mprisModel
        delegate: QtObject {}
    }

    MediaState {
        id: mediaStateItem
        player: root.player
    }

    NotificationWatcher {
        id: notificationWatcher
        pulseEnabled: root.cfg.pulseEnabled
        jobsEnabled: root.cfg.pillJobs
        pulseOnJobs: root.cfg.pulseOnJobs
        ignoredApps: root.cfg.pulseIgnoreApps
        onPulse: (color, summary) => {
            if (root.fullScreen) {
                return;
            }
            pulseRequested(color);
            if (root.cfg.pulseShowSummary && summary) {
                root.noticeText = root.truncate(summary);
                noticeTimer.restart();
            }
        }
    }
    signal pulseRequested(color color)

    // While a switch is due, the strip flashes now and then, until it's done or snoozed
    Timer {
        interval: 20000
        repeat: true
        triggeredOnStart: true
        running: root.standDue && !root.fullScreen
        onTriggered: root.pulseRequested("#c9a227")
    }

    Timer {
        id: noticeTimer
        interval: 4000
        onTriggered: root.noticeText = ""
    }

    PrivacyMonitor {
        id: privacyMonitor
    }

    // Stand (from Shift): the sit/stand cycle, only while turned on
    Loader {
        id: standLoader
        active: root.cfg.standEnabled
        sourceComponent: Component {
            Stand.StandController {
                settings: root.cfg
                // Focus and Stand together: switches wait for the focus break
                holdForFocus: root.cfg.stand_focus_sync_enabled && root.focusInBlock
                holdForMeeting: root.cfg.stand_meeting_hold && root.inMeeting
                // A focus break is time away from the desk: neither sitting nor standing
                focusBreak: root.cfg.stand_focus_sync_enabled && root.focusOnBreak
            }
        }
    }
    readonly property var stand: standLoader.item

    // Focus (from Fokus): the timer, only while turned on
    Loader {
        id: focusLoader
        active: root.cfg.focusEnabled
        sourceComponent: Component {
            Focus.FocusController {
                settings: root.cfg
                nextMeeting: root.cfg.calendarEnabled ? calendarSource.meetingNext : null
                expanded: root.open
            }
        }
    }
    readonly property var focusTimer: focusLoader.item
    // A focus block (not a break) is running
    readonly property bool focusInBlock: focusTimer !== null && focusTimer !== undefined
        && focusTimer.active && !focusTimer.breakOvertime && !focusTimer.isBreak()

    // A break is running (or running over)
    readonly property bool focusOnBreak: focusActive && !focusInBlock
    // A break has begun: a posture switch due within 10 minutes is made now, not mid-block.
    // Only on a running break, and a beat later so Shift's hold has lifted by then; not for a
    // session restored at startup.
    property real loadedAtMs: Date.now()
    onFocusOnBreakChanged: {
        if (!focusOnBreak || !stand || !cfg.stand_focus_sync_enabled || Date.now() - loadedAtMs < 15000)
            return;
        Qt.callLater(() => {
            if (root.focusOnBreak && root.stand)
                root.stand.switchAtBreak(10 * 60 * 1000);
        });
    }

    SystemMonitor {
        id: systemMonitor
        active: root.open && root.cfg.showSystem
    }

    CalendarSource {
        id: calendarSource
        active: root.cfg.calendarEnabled
        leadMinutes: root.cfg.calendarLeadMinutes
        applet: Plasmoid
    }

    Island.AppMenuModel {
        id: menuModel
        enabled: root.cfg.showAppMenu
        serviceName: root.activeTask ? root.activeTask.menuService : ""
        objectPath: root.activeTask ? root.activeTask.menuPath : ""

        // A menu item chosen: done here, close (as macOS's menu bar)
        onActionTriggered: root.setOpen(false)

        onMenuOpenChanged: {
            if (!menuOpen && root.open) {
                closeTimer.restart();
            }
        }
    }

    Island.CavaSource {
        id: cavaSource
        bars: root.cfg.cavaBars
        framerate: root.cfg.cavaFramerate
        monstercat: root.cfg.cavaMonstercat
        noiseReduction: root.cfg.cavaNoiseReduction
        running: root.playing && root.cfg.showMedia
            && !(root.cfg.pauseOnFullscreen && root.fullScreen)
            && (root.open || (root.cfg.cavaInPanel && root.cfg.mediaInPanel))
    }

    // ---- the widget's right-click menu ---------------------------------------------------------
    Plasmoid.contextualActions: [
        // Focus (from Fokus): what its own menu offered
        // Named and drawn as the timer's, so they don't read as a second set of media controls
        PlasmaCore.Action {
            readonly property string mode: !root.focusTimer ? ""
                : root.focusTimer.sessionBtnIconSource === "media-playback-start" ? "start"
                : root.focusTimer.sessionBtnIconSource === "chronometer-pause" ? "break"
                : root.focusTimer.sessionBtnIconSource === "media-skip-forward" ? "endBreak" : "pause"
            text: mode === "start" ? i18n("Start Focus") : mode === "break" ? i18n("Take a Break")
                : mode === "endBreak" ? i18n("End Break") : i18n("Pause Focus")
            icon.name: mode === "start" ? "chronometer-start" : mode === "endBreak" ? "chronometer-lap" : "chronometer-pause"
            visible: !!root.focusTimer
            onTriggered: root.focusTimer.toggleSession()
        },
        PlasmaCore.Action {
            text: root.focusTimer && root.focusTimer.isBreak() ? i18n("Skip Break") : i18n("Skip to Break")
            icon.name: "chronometer-lap"
            visible: !!root.focusTimer && !root.focusTimer.flowmodoroModeEnabled
            onTriggered: root.focusTimer.skip()
        },
        PlasmaCore.Action {
            text: root.focusTimer && (root.focusTimer.isBreak() || root.focusTimer.breakOvertime) ? i18n("End Focus for Today") : i18n("Stop Focus")
            icon.name: "chronometer-reset"
            visible: !!root.focusTimer
            onTriggered: root.focusTimer.endForToday()
        },
        PlasmaCore.Action {
            text: i18n("Flowmodoro Mode")
            checkable: true
            checked: root.cfg.focus_flowmodoro_mode_enabled
            visible: !!root.focusTimer
            onTriggered: root.cfg.focus_flowmodoro_mode_enabled = !root.cfg.focus_flowmodoro_mode_enabled
        },
        PlasmaCore.Action {
            isSeparator: true
            visible: !!root.focusTimer
        },
        // Shift: switch to the other posture (the desk moves when it's controlled)
        PlasmaCore.Action {
            readonly property bool standing: !!root.stand && root.stand.cycle.position === "stand"
            text: standing ? i18n("Sit Down") : i18n("Stand Up")
            icon.name: standing ? "go-down-symbolic" : "go-up-symbolic"
            visible: !!root.stand
            onTriggered: {
                if (root.stand.pendingPosition) {
                    root.stand.confirmPending();
                } else {
                    root.stand.goTo(standing ? "sit" : "stand");
                }
            }
        },
        PlasmaCore.Action {
            isSeparator: true
            visible: !!root.stand
        },
        PlasmaCore.Action {
            text: root.meeting ? i18n("Join %1", root.truncate(root.meeting.summary)) : ""
            icon.name: "camera-video-symbolic"
            visible: !!root.meeting && !!root.meeting.meetingUrl
            onTriggered: root.joinMeeting()
        },
        PlasmaCore.Action {
            text: i18n("Do Not Disturb")
            icon.name: "notifications-disabled-symbolic"
            checkable: true
            checked: notificationWatcher.doNotDisturb
            visible: root.cfg.showNotifications
            onTriggered: notificationWatcher.toggleDoNotDisturb()
        },
        PlasmaCore.Action {
            text: i18n("Clear All Notifications")
            icon.name: "edit-clear-history"
            visible: root.cfg.showNotifications
            enabled: notificationWatcher.count > 0
            onTriggered: notificationWatcher.clearHistory()
        },
        PlasmaCore.Action {
            isSeparator: true
            visible: root.cfg.showMedia && root.hasPlayer
        },
        PlasmaCore.Action {
            text: root.playing ? i18nc("media", "Pause") : i18nc("media", "Play")
            icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
            visible: root.cfg.showMedia && root.hasPlayer
            enabled: root.hasPlayer && (root.playing ? root.player.canPause : root.player.canPlay)
            onTriggered: root.player.PlayPause()
        },
        PlasmaCore.Action {
            text: i18nc("media", "Previous Track")
            icon.name: "media-skip-backward"
            visible: root.cfg.showMedia && root.hasPlayer
            enabled: root.hasPlayer && root.player.canGoPrevious
            onTriggered: root.player.Previous()
        },
        PlasmaCore.Action {
            text: i18nc("media", "Next Track")
            icon.name: "media-skip-forward"
            visible: root.cfg.showMedia && root.hasPlayer
            enabled: root.hasPlayer && root.player.canGoNext
            onTriggered: root.player.Next()
        }
    ]

    compactRepresentation: CompactIsland {
        island: root
        cava: cavaSource
        mediaState: mediaStateItem
        notifications: notificationWatcher
        calendar: calendarSource
        privacy: privacyMonitor
    }

    // Always set: without a full representation Plasma lays the applet out as a bare icon. With
    // the drawer it's an empty item: Plasma makes it (hidden) anyway, and a second copy of the
    // content there opened the application menus from that hidden window.
    fullRepresentation: useDrawer ? emptyFullComponent : flyoutComponent

    Component {
        id: emptyFullComponent
        Item {}
    }

    Component {
        id: flyoutComponent
        Flyout {
            island: root
            tasks: windowTasks
            appMenu: menuModel
            cava: cavaSource
            mpris: mprisModel
            mediaState: mediaStateItem
            notifications: notificationWatcher
            calendar: calendarSource
            monitor: systemMonitor
        }
    }

    // The drawer exists only while open or closing: no window made at plasmashell's start.
    property bool drawerLoaded: false
    onDrawerOpenChanged: {
        if (drawerOpen) {
            drawerLoaded = true;
        }
    }
    Loader {
        id: drawerLoader
        active: root.useDrawer && root.drawerLoaded && root.compactRepresentationItem !== null
        source: Qt.resolvedUrl("drawer/Drawer.qml")
        onLoaded: {
            item.island = root;
            item.anchorItem = Qt.binding(() => root.compactRepresentationItem);
            item.tasks = windowTasks;
            item.appMenu = menuModel;
            item.cava = cavaSource;
            item.mpris = mprisModel;
            item.mediaState = mediaStateItem;
            item.notifications = notificationWatcher;
            item.calendar = calendarSource;
            item.monitor = systemMonitor;
            item.ready = true;
        }
        Connections {
            target: drawerLoader.item
            function onFullyClosed() {
                if (!root.drawerOpen) {
                    root.drawerLoaded = false;
                }
            }
        }
    }
}
