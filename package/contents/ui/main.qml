/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import com.dv.island.private as Island

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
    readonly property bool hasPlayer: player !== null && player !== undefined
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
    readonly property var stripEvent: cfg.calendarEnabled ? calendarSource.stripEvent : null
    readonly property string stripMode: noticeText !== "" ? "notice"
        : showMediaInPanel ? "media"
        : stripEvent ? "event"
        : "window"
    readonly property string stripText: {
        switch (stripMode) {
        case "notice": return noticeText;
        case "media": return mediaText;
        case "event": return truncate(calendarSource.label(stripEvent));
        default: return windowText;
        }
    }

    // ---- hover / popup state --------------------------------------------------
    property bool pinnedByClick: false
    property bool compactHovered: false
    property bool flyoutHovered: false
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

    toolTipMainText: ""
    toolTipSubText: ""
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    // Hover-opened popup must survive the app menu popup taking focus;
    // a click-pinned popup behaves like a normal applet popup.
    hideOnWindowDeactivate: pinnedByClick && !menuModel.menuOpen

    // Another window became active (a click into an app or on the desktop): close, as a popup
    // does on losing focus. The drawer opened by hover never has the focus to lose.
    // Only another application counts: the drawer taking the focus leaves no active task.
    property Item taskWhenOpened: null
    onActiveTaskChanged: {
        if (open && activeTask !== null && activeTask !== taskWhenOpened
                && !flyoutHovered && !compactHovered && !menuModel.menuOpen) {
            setOpen(false);
        }
    }

    onOpenChanged: {
        if (root.open) {
            taskWhenOpened = activeTask;
        } else {
            pinnedByClick = false;
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
            if (root.compactHovered && !root.hoverSuppressed) {
                root.setOpen(true);
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.cfg.closeDelay
        onTriggered: {
            if (!root.pinnedByClick && !root.compactHovered && !root.flyoutHovered && !menuModel.menuOpen) {
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
            if (cfg.openOnHover && !open) {
                openTimer.restart();
            }
        } else {
            openTimer.stop();
            if (open) {
                closeTimer.restart();
            }
        }
    }

    onFlyoutHoveredChanged: {
        if (flyoutHovered) {
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
    }

    MediaState {
        id: mediaStateItem
        player: root.player
    }

    NotificationWatcher {
        id: notificationWatcher
        pulseEnabled: root.cfg.pulseEnabled
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

    Timer {
        id: noticeTimer
        interval: 4000
        onTriggered: root.noticeText = ""
    }

    PrivacyMonitor {
        id: privacyMonitor
    }

    SystemMonitor {
        id: systemMonitor
        active: root.open && root.cfg.showSystem
    }

    CalendarSource {
        id: calendarSource
        active: root.cfg.calendarEnabled
        leadMinutes: root.cfg.calendarLeadMinutes
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
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Open Dashboard")
            icon.name: "view-grid"
            visible: root.cfg.showDashboard
            onTriggered: root.openOn("dashboard", true)
        },
        PlasmaCore.Action {
            text: i18n("Open Media")
            icon.name: "media-playback-start"
            visible: root.cfg.showMedia && root.hasPlayer
            onTriggered: root.openOn("media", true)
        },
        PlasmaCore.Action {
            text: i18n("Open Notifications")
            icon.name: "notifications"
            visible: root.cfg.showNotifications
            onTriggered: root.openOn("notifications", true)
        },
        PlasmaCore.Action {
            text: i18n("Open System Monitor")
            icon.name: "view-statistics"
            visible: root.cfg.showSystem
            onTriggered: root.openOn("system", true)
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
