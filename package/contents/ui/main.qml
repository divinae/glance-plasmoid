/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import com.dv.island.private as Island

PlasmoidItem {
    id: root

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
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

    function truncate(text: string): string {
        const max = cfg.maxTitleLength;
        return text.length > max ? text.slice(0, max - 1) + "…" : text;
    }

    function openOn(tab: string, pin: bool) {
        requestedTab = tab;
        if (pin) {
            pinnedByClick = true;
        }
        expanded = true;
    }

    toolTipMainText: ""
    toolTipSubText: ""
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    // Hover-opened popup must survive the app menu popup taking focus;
    // a click-pinned popup behaves like a normal applet popup.
    hideOnWindowDeactivate: pinnedByClick && !menuModel.menuOpen

    onExpandedChanged: {
        if (!root.expanded) {
            pinnedByClick = false;
            closeTimer.stop();
            menuModel.closeMenu();
        }
    }

    Timer {
        id: openTimer
        interval: root.cfg.hoverDelay
        onTriggered: {
            if (root.compactHovered) {
                root.expanded = true;
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.cfg.closeDelay
        onTriggered: {
            if (!root.pinnedByClick && !root.compactHovered && !root.flyoutHovered && !menuModel.menuOpen) {
                root.expanded = false;
            }
        }
    }

    onCompactHoveredChanged: {
        if (compactHovered) {
            closeTimer.stop();
            if (cfg.openOnHover && !expanded) {
                openTimer.restart();
            }
        } else {
            openTimer.stop();
            if (expanded) {
                closeTimer.restart();
            }
        }
    }

    onFlyoutHoveredChanged: {
        if (flyoutHovered) {
            closeTimer.stop();
        } else if (expanded) {
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

        onMenuOpenChanged: {
            if (!menuOpen && root.expanded) {
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
            && (root.expanded || (root.cfg.cavaInPanel && root.cfg.mediaInPanel))
    }

    compactRepresentation: CompactIsland {
        island: root
        cava: cavaSource
        mediaState: mediaStateItem
        notifications: notificationWatcher
        calendar: calendarSource
    }

    fullRepresentation: Flyout {
        island: root
        tasks: windowTasks
        appMenu: menuModel
        cava: cavaSource
        mpris: mprisModel
        mediaState: mediaStateItem
        notifications: notificationWatcher
        calendar: calendarSource
    }
}
