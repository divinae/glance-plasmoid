/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "tabs"

// What the island opens: the tabs and their pages. Shared by the classic Plasma popup
// (Flyout.qml) and the drawer that slides out of the screen edge (drawer/Drawer.qml).
Item {
    id: content

    required property PlasmoidItem island
    required property Item tasks
    required property QtObject appMenu
    required property QtObject cava
    required property QtObject mpris
    required property Item mediaState
    required property Item notifications
    required property Item calendar
    required property Item monitor
    required property Item privacy
    // The drawer's look: icon tabs with a sliding indicator instead of Plasma's TabBar
    property bool drawerStyle: false

    readonly property Item task: island.activeTask

    // ---- tabs ----------------------------------------------------------------
    readonly property var tabs: {
        const t = [];
        if (island.cfg.showDashboard) {
            t.push({key: "dashboard", label: i18n("Dashboard"), icon: "view-grid"});
        }
        // The dashboard's window tile has the buttons and the menu: the tab only without it
        if (!island.cfg.showDashboard) {
            t.push({key: "window", label: i18n("Window"), icon: "window"});
        }
        if (island.cfg.showMedia && island.hasPlayer) {
            t.push({key: "media", label: i18n("Media"), icon: "media-playback-start"});
        }
        if (island.cfg.showNotifications) {
            t.push({key: "notifications", label: i18n("Notifications"), icon: "notifications"});
        }
        if (island.cfg.calendarEnabled && calendar.available) {
            t.push({key: "agenda", label: i18n("Agenda"), icon: "view-calendar-day"});
        }
        if (island.cfg.showShelf) {
            t.push({key: "shelf", label: i18n("Shelf"), icon: "folder-download"});
        }
        if (island.cfg.showSystem) {
            t.push({key: "system", label: i18n("System"), icon: "view-statistics"});
        }
        return t;
    }
    readonly property string homeKey: island.cfg.showDashboard ? "dashboard" : "window"
    property string currentKey: homeKey
    readonly property int currentIndex: Math.max(0, tabs.findIndex(t => t.key === currentKey))

    function hasTab(key: string): bool {
        return tabs.some(t => t.key === key);
    }

    function defaultKey(): string {
        if (island.requestedTab !== "") {
            return island.requestedTab;
        }
        // The dashboard shows media, unread notifications and the next event itself
        if (island.cfg.showDashboard) {
            return "dashboard";
        }
        if (island.playing && island.cfg.showMedia) {
            return "media";
        }
        if (island.cfg.showNotifications && notifications.unreadCount > 0) {
            return "notifications";
        }
        if (island.cfg.calendarEnabled && calendar.stripEvent) {
            return "agenda";
        }
        return "window";
    }

    function pickTab() {
        const k = defaultKey();
        currentKey = hasTab(k) ? k : homeKey;
        island.requestedTab = "";
    }

    Connections {
        target: content.island
        function onOpenChanged() {
            if (content.island.open) {
                content.pickTab();
            } else if (content.currentKey === "notifications") {
                content.notifications.markRead();
            }
        }
        function onRequestedTabChanged() {
            if (content.island.requestedTab !== "") {
                content.pickTab();
            }
        }
    }
    onTabsChanged: {
        if (!hasTab(currentKey)) {
            currentKey = homeKey;
        }
    }
    onCurrentKeyChanged: {
        if (currentKey === "notifications") {
            notifications.markRead();
        }
    }
    Component.onCompleted: pickTab()

    Timer {
        id: hoverSwitch
        property string target
        interval: 150
        onTriggered: content.currentKey = target
    }

    // Drop files anywhere to shelve them
    DragDrop.DropArea {
        anchors.fill: parent
        enabled: content.island.cfg.showShelf
        onDragEnter: event => {
            if (content.island.dropHasFiles(event)) {
                event.accept(Qt.CopyAction);
                content.currentKey = "shelf";
            }
        }
        onDrop: event => content.island.acceptFiles(event)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: content.drawerStyle ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing
        clip: true

        // ---- the active window's menu bar, as macOS's: its icon and name, its menus, and the
        // window buttons on the right; on every tab ----------------------------------------
        RowLayout {
            id: menuStrip
            Layout.fillWidth: true
            visible: content.island.cfg.showDashboard && content.task !== null
                && (content.island.cfg.showAppMenu || content.island.cfg.showWindowButtons)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: content.task && content.task.icon ? content.task.icon : "preferences-desktop"
            }
            // The whole name when there are no menus beside it; capped when there are
            PlasmaComponents.Label {
                Layout.fillWidth: !stripMenu.visible
                Layout.maximumWidth: stripMenu.visible ? Kirigami.Units.gridUnit * 10 : -1
                text: content.task ? content.task.appName : ""
                textFormat: Text.PlainText
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            AppMenuBar {
                id: stripMenu
                Layout.fillWidth: true
                appMenu: content.appMenu
                visible: content.island.cfg.showAppMenu && content.appMenu.menuAvailable && count > 0
            }
            WindowButtons {
                visible: content.island.cfg.showWindowButtons
                island: content.island
                tasks: content.tasks
            }
        }

        // ---- tabs: drawer style on top, before the header ------------------
        TabStrip {
            Layout.fillWidth: true
            visible: content.drawerStyle && content.tabs.length > 1
            tabs: content.tabs
            currentIndex: content.currentIndex
            badgeKey: content.notifications.unreadCount > 0 ? "notifications" : ""
            hoverSwitch: content.island.cfg.switchTabOnHover
            onActivated: key => content.currentKey = key
        }

        // ---- window header + buttons: only on the Window tab (the dashboard has a window tile) --
        RowLayout {
            id: header
            Layout.fillWidth: true
            visible: content.currentKey === "window"
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: content.task && content.task.icon ? content.task.icon : "preferences-desktop"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: content.task ? content.task.appName : content.island.cfg.placeholder
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: content.task && content.task.title !== content.task.appName ? content.task.title : ""
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }

            WindowButtons {
                visible: content.island.cfg.showWindowButtons && content.task !== null
                island: content.island
                tasks: content.tasks
            }
        }

        PlasmaComponents.TabBar {
            id: tabBar
            Layout.fillWidth: true
            visible: !content.drawerStyle && content.tabs.length > 1
            currentIndex: content.currentIndex

            Repeater {
                model: content.drawerStyle ? [] : content.tabs
                PlasmaComponents.TabButton {
                    required property var modelData
                    readonly property bool badge: modelData.key === "notifications" && content.notifications.unreadCount > 0
                    icon.name: modelData.icon
                    text: badge ? modelData.label + " (" + content.notifications.unreadCount + ")" : modelData.label
                    display: content.tabs.length > 3 ? PlasmaComponents.AbstractButton.IconOnly : PlasmaComponents.AbstractButton.TextBesideIcon
                    onClicked: content.currentKey = modelData.key
                    // short dwell so sweeping across the bar doesn't flip through every tab
                    onHoveredChanged: {
                        if (hovered && content.island.cfg.switchTabOnHover) {
                            hoverSwitch.target = modelData.key;
                            hoverSwitch.restart();
                        } else if (hoverSwitch.target === modelData.key) {
                            hoverSwitch.stop();
                        }
                    }
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered && display === PlasmaComponents.AbstractButton.IconOnly
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

                    Rectangle {
                        visible: parent.badge && parent.display === PlasmaComponents.AbstractButton.IconOnly
                        width: Kirigami.Units.smallSpacing * 2
                        height: width
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Kirigami.Units.smallSpacing
                    }
                }
            }
        }

        // ---- pages: fill the fixed area, scroll when taller; crossfade on switch --
        Item {
            id: pageArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            component Page: Flickable {
                id: page
                required property string key
                property alias sourceComponent: loader.sourceComponent
                readonly property bool current: content.currentKey === key
                anchors.fill: parent
                contentWidth: width
                contentHeight: loader.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {
                    visible: page.interactive
                }
                // keep pages loaded after first view so switching back is instant
                property bool shown: false
                onCurrentChanged: if (current) shown = true
                Component.onCompleted: if (current) shown = true
                opacity: current ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                }

                Loader {
                    id: loader
                    width: page.width
                    // at least the page height, so tabs can lay out to fill it
                    height: Math.max(item ? item.implicitHeight : 0, page.height)
                    active: page.current || page.shown
                }
            }

            Page {
                key: "dashboard"
                sourceComponent: DashboardTab {
                    island: content.island
                    tasks: content.tasks
                    appMenu: content.appMenu
                    cava: content.cava
                    mediaState: content.mediaState
                    notifications: content.notifications
                    calendar: content.calendar
                    monitor: content.monitor
                    onOpenTab: key => {
                        if (content.hasTab(key)) {
                            content.currentKey = key;
                        }
                    }
                }
            }
            Page {
                key: "window"
                sourceComponent: WindowTab {
                    island: content.island
                    appMenu: content.appMenu
                }
            }
            Page {
                key: "media"
                sourceComponent: MediaTab {
                    island: content.island
                    mpris: content.mpris
                    mediaState: content.mediaState
                    cava: content.cava
                }
            }
            Page {
                key: "notifications"
                sourceComponent: NotificationsTab {
                    watcher: content.notifications
                }
            }
            Page {
                key: "agenda"
                sourceComponent: AgendaTab {
                    calendar: content.calendar
                }
            }
            Page {
                key: "system"
                sourceComponent: SystemTab {
                    monitor: content.monitor
                }
            }
            Page {
                key: "shelf"
                sourceComponent: ShelfTab {
                    island: content.island
                }
            }
        }
    }
}
