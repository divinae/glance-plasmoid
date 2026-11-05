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
import "stand" as Stand
import "focus" as Focus
import "common" as Common

// What Glance opens: the tabs and their pages. Shared by the classic Plasma popup
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
    // The drawer's look: icon tabs with a sliding indicator instead of Plasma's TabBar
    property bool drawerStyle: false

    readonly property Item task: island.activeTask
    // For what opens inside (DrawerMenu, the search): the drawer stays while it's up
    function hold(key) {
        island.hold(key);
    }
    function release(key) {
        island.release(key);
    }

    // ---- tabs ----------------------------------------------------------------
    readonly property var tabs: {
        const t = [];
        // The dashboard always; the window's menus and buttons are in the strip on top
        t.push({key: "dashboard", label: i18n("Dashboard"), icon: "view-grid"});
        if (island.cfg.showMedia && (island.hasPlayer || island.playerCount > 1)) {
            t.push({key: "media", label: i18n("Media"), icon: "media-playback-start"});
        }
        if (island.cfg.showNotifications) {
            t.push({key: "notifications", label: i18n("Notifications"), icon: "notifications"});
        }
        if (island.cfg.showShelf) {
            t.push({key: "shelf", label: i18n("Shelf"), icon: "folder-download"});
        }
        if (content.workTab) {
            // Focus and Shift together, in one tab
            t.push({key: "work", label: i18n("Work"), icon: "chronometer"});
        } else if (island.focusTimer) {
            t.push({key: "focus", label: i18n("Focus"), icon: "chronometer"});
        } else if (island.stand) {
            // The posture you're in, sitting or standing
            t.push({key: "stand", label: island.stand.cycle.position === "stand" ? i18n("Standing") : i18n("Sitting"),
                icon: Qt.resolvedUrl(island.stand.cycle.position === "stand" ? "stand/icons/person-stand.svg" : "stand/icons/person-sit.svg")});
        }
        if (island.cfg.showSystem) {
            t.push({key: "system", label: i18n("System"), icon: "view-statistics"});
        }
        return t;
    }
    // Both on: Focus and Shift share the "work" tab, and their own keys lead there
    readonly property bool workTab: !!island.focusTimer && !!island.stand
    function tabKey(key: string): string {
        return workTab && (key === "focus" || key === "stand") ? "work" : key;
    }
    readonly property string homeKey: "dashboard"
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
        return "dashboard";
    }

    function pickTab() {
        const k = tabKey(defaultKey());
        currentKey = hasTab(k) ? k : homeKey;
        island.requestedTab = "";
    }

    Connections {
        target: content.island
        function onOpenChanged() {
            if (content.island.open) {
                content.pickTab();
            } else {
                content.searching = false;
                if (content.currentKey === "notifications") {
                    content.notifications.markRead();
                }
            }
        }
        // Asked for while open: switch now. While closed, opening picks it (openOn() asks
        // first and opens after; picking here too would spend the request before that)
        function onRequestedTabChanged() {
            if (content.island.requestedTab !== "" && content.island.open) {
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
    // Created as the drawer opens: pick now if it already is, else on opening (so a tab asked
    // for just before isn't spent while it is still closed)
    Component.onCompleted: if (island.open) pickTab()

    // The window has menus to show on the bar
    readonly property bool hasMenus: island.cfg.showAppMenu && appMenu.menuAvailable && stripMenu.count > 0
    // Searching them: the field takes the menus' place across the bar (MenuSearch). Typing takes
    // the keyboard, which read as leaving and closed the drawer: it's held while searching
    property bool searching: false
    onSearchingChanged: searching ? hold("menuSearch") : release("menuSearch")
    Component.onDestruction: release("menuSearch")
    function openMenuSearch() {
        if (hasMenus) {
            searching = true;
        }
    }
    // Keys while the drawer has the keyboard: Alt+letter opens that menu (its mnemonic),
    // Alt+/ (or Ctrl+F) searches them. True when used
    function menuKey(event): bool {
        if (!hasMenus) {
            return false;
        }
        const alt = (event.modifiers & Qt.AltModifier) && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier));
        if ((alt && event.key === Qt.Key_Slash) || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
            openMenuSearch();
            return true;
        }
        if (alt && event.text.length === 1 && /\S/.test(event.text)) {
            return stripMenu.activateMnemonic(event.text);
        }
        return false;
    }

    // KWin's shortcut acts on its active window. Opened by hover, the drawer never took the focus,
    // so that's the app; opened by a click it has (KWin's active window is then plasmashell), so
    // the app is made active first, a moment before. The drawer stays under the menu either way
    function showWindowMenu() {
        island.holdForWindowMenu();
        if (island.pinnedByClick) {
            content.tasks.requestActivate();
            windowMenuLater.restart();
            return;
        }
        invokeWindowMenu();
    }
    function invokeWindowMenu() {
        windowMenuExec.exec(["gdbus", "call", "--session", "--dest", "org.kde.kglobalaccel",
            "--object-path", "/component/kwin", "--method", "org.kde.kglobalaccel.Component.invokeShortcut",
            "Window Operations Menu"], (cmd, exitCode) => {
            // No menu came: don't hold the drawer for one
            if (exitCode !== 0) {
                island.release("windowMenu");
            }
        });
    }
    Timer {
        id: windowMenuLater
        interval: 150
        onTriggered: content.invokeWindowMenu()
    }
    Common.ExecUtil {
        id: windowMenuExec
    }

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
            visible: content.task !== null
                && (content.island.cfg.showAppMenu || content.island.cfg.showWindowButtons)
            spacing: Kirigami.Units.smallSpacing

            // A click: KWin's menu for the window (Desktops, Activities, Keep Above…), as Alt+F3,
            // at the pointer; the drawer stays open under it
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: content.task && content.task.icon ? content.task.icon : "preferences-desktop"
                scale: windowMenuTap.pressed ? 0.85 : 1
                Behavior on scale {
                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                }
                HoverHandler {
                    id: windowMenuHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: windowMenuTap
                    onTapped: content.showWindowMenu()
                }
                PlasmaComponents.ToolTip.text: i18n("Window menu")
                PlasmaComponents.ToolTip.visible: windowMenuHover.hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            // The whole name when there are no menus beside it; capped when there are. A click:
            // the app's own About, Settings and Quit, as macOS's app menu (found in its menus)
            PlasmaComponents.Label {
                id: appName
                Layout.fillWidth: !content.hasMenus
                Layout.maximumWidth: content.hasMenus ? Kirigami.Units.gridUnit * 10 : -1
                text: content.task ? content.task.appName : ""
                textFormat: Text.PlainText
                font.weight: Font.Bold
                elide: Text.ElideRight
                opacity: appNameHover.hovered && content.appMenu.menuAvailable ? 0.75 : 1
                HoverHandler {
                    id: appNameHover
                    cursorShape: content.appMenu.menuAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    onTapped: {
                        appMenuItems.model = content.appMenu.menuAvailable ? content.appMenu.appActions(appName.text) : [];
                        if (appMenuItems.count > 0) {
                            appNameMenu.popup(appName, 0, appName.height);
                        }
                    }
                }
                Common.DrawerMenu {
                    id: appNameMenu
                    Repeater {
                        id: appMenuItems
                        // Filled on a click (it walks the whole tree), not on every window switch
                        model: []
                        delegate: PlasmaComponents.MenuItem {
                            required property var modelData
                            text: modelData.text
                            icon.name: modelData.kind === "about" ? "help-about"
                                : modelData.kind === "settings" ? "configure" : "application-exit"
                            onTriggered: {
                                modelData.action.trigger();
                                content.island.setOpen(false);
                            }
                        }
                    }
                }
            }
            // The menus, or the search in their place: the field grows out of the magnifier
            // (from the right, across) as the menus fade, and back
            Item {
                id: menuArea
                Layout.fillWidth: true
                visible: content.hasMenus || content.searching
                implicitHeight: Math.max(stripMenu.implicitHeight, menuSearch.implicitHeight)

                AppMenuBar {
                    id: stripMenu
                    anchors.fill: parent
                    appMenu: content.appMenu
                    opacity: content.searching ? 0 : 1
                    visible: content.hasMenus && opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                }
                // Back to the menus, at the field's start
                Common.PillButton {
                    id: backButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: content.searching ? 1 : 0
                    visible: opacity > 0
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Back to the menus")
                    icon.name: "go-previous-symbolic"
                    onClicked: menuSearch.finish()
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                }
                MenuSearch {
                    id: menuSearch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Out of the magnifier's place to the whole bar after the back arrow
                    width: content.searching ? parent.width - backButton.width - Kirigami.Units.smallSpacing : height
                    opacity: content.searching ? 1 : 0
                    visible: opacity > 0
                    active: content.searching
                    appMenu: content.appMenu
                    onFinished: content.searching = false
                    onRan: content.island.setOpen(false)
                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }
            }
            // Search the menus (as the old HUD)
            Common.PillButton {
                id: searchButton
                visible: content.hasMenus && !content.searching
                bare: true
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Search the menus")
                icon.name: "search"
                onClicked: content.openMenuSearch()
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
                    cava: content.cava
                    mediaState: content.mediaState
                    notifications: content.notifications
                    calendar: content.calendar
                    monitor: content.monitor
                    onOpenTab: key => {
                        const k = content.tabKey(key);
                        if (content.hasTab(k)) {
                            content.currentKey = k;
                        }
                    }
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
                key: "focus"
                sourceComponent: Focus.FocusView {
                    root: content.island.focusTimer
                }
            }
            Page {
                key: "stand"
                sourceComponent: Stand.StandView {
                    root: content.island.stand
                }
            }
            Page {
                key: "work"
                sourceComponent: WorkTab {
                    focusTimer: content.island.focusTimer
                    stand: content.island.stand
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
