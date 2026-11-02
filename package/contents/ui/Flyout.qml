/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "tabs"

Item {
    id: flyout

    required property PlasmoidItem island
    required property Item tasks
    required property QtObject appMenu
    required property QtObject cava
    required property QtObject mpris
    required property Item mediaState
    required property Item notifications
    required property Item calendar

    readonly property Item task: island.activeTask

    // ---- tabs ----------------------------------------------------------------
    readonly property var tabs: {
        const t = [{key: "window", label: i18n("Window"), icon: "window"}];
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
        return t;
    }
    property string currentKey: "window"
    readonly property int currentIndex: Math.max(0, tabs.findIndex(t => t.key === currentKey))

    function defaultKey(): string {
        if (island.requestedTab !== "") {
            return island.requestedTab;
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
        currentKey = tabs.some(t => t.key === k) ? k : "window";
        island.requestedTab = "";
    }

    Connections {
        target: flyout.island
        function onExpandedChanged() {
            if (flyout.island.expanded) {
                flyout.pickTab();
            } else if (flyout.currentKey === "notifications") {
                flyout.notifications.markRead();
            }
        }
        function onRequestedTabChanged() {
            if (flyout.island.requestedTab !== "") {
                flyout.pickTab();
            }
        }
    }
    onTabsChanged: {
        if (!tabs.some(t => t.key === currentKey)) {
            currentKey = "window";
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
        onTriggered: flyout.currentKey = target
    }

    // ---- size: fixed, so the popup never jumps between tabs ------------------
    readonly property real fixedHeight: Kirigami.Units.gridUnit * island.cfg.popupHeight

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.maximumWidth: Kirigami.Units.gridUnit * 40
    Layout.minimumHeight: fixedHeight
    Layout.preferredHeight: fixedHeight
    Layout.maximumHeight: fixedHeight

    HoverHandler {
        onHoveredChanged: flyout.island.flyoutHovered = hovered
    }
    Component.onDestruction: island.flyoutHovered = false

    // Drop files anywhere on the popup to shelve them
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: flyout.island.cfg.showShelf && flyout.currentKey !== "shelf"
        onEntered: flyout.currentKey = "shelf"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        clip: true

        // ---- window header + buttons ---------------------------------------
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: flyout.task && flyout.task.icon ? flyout.task.icon : "preferences-desktop"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: flyout.task ? flyout.task.appName : flyout.island.cfg.placeholder
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: flyout.task && flyout.task.title !== flyout.task.appName ? flyout.task.title : ""
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }

            RowLayout {
                visible: flyout.island.cfg.showWindowButtons && flyout.task !== null
                spacing: 0

                PlasmaComponents.ToolButton {
                    icon.name: "window-pin"
                    checkable: true
                    checked: flyout.task ? flyout.task.isKeepAbove : false
                    onClicked: flyout.tasks.toggleKeepAbove()
                    PlasmaComponents.ToolTip.text: i18n("Keep Above Others")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents.ToolButton {
                    icon.name: "window-minimize"
                    onClicked: {
                        flyout.tasks.toggleMinimized();
                        flyout.island.expanded = false;
                    }
                    PlasmaComponents.ToolTip.text: i18n("Minimize")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents.ToolButton {
                    icon.name: flyout.task && flyout.task.isMaximized ? "window-restore" : "window-maximize"
                    onClicked: flyout.tasks.toggleMaximized()
                    PlasmaComponents.ToolTip.text: flyout.task && flyout.task.isMaximized ? i18n("Restore") : i18n("Maximize")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents.ToolButton {
                    icon.name: "window-close"
                    onClicked: {
                        flyout.tasks.requestClose();
                        flyout.island.expanded = false;
                    }
                    PlasmaComponents.ToolTip.text: i18n("Close")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        PlasmaComponents.TabBar {
            id: tabBar
            Layout.fillWidth: true
            visible: flyout.tabs.length > 1
            currentIndex: flyout.currentIndex

            Repeater {
                model: flyout.tabs
                PlasmaComponents.TabButton {
                    required property var modelData
                    readonly property bool badge: modelData.key === "notifications" && flyout.notifications.unreadCount > 0
                    icon.name: modelData.icon
                    text: badge ? modelData.label + " (" + flyout.notifications.unreadCount + ")" : modelData.label
                    display: flyout.tabs.length > 3 ? PlasmaComponents.AbstractButton.IconOnly : PlasmaComponents.AbstractButton.TextBesideIcon
                    onClicked: flyout.currentKey = modelData.key
                    // short dwell so sweeping across the bar doesn't flip through every tab
                    onHoveredChanged: {
                        if (hovered && flyout.island.cfg.switchTabOnHover) {
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
                readonly property bool current: flyout.currentKey === key
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
                id: windowPage
                key: "window"
                sourceComponent: WindowTab {
                    island: flyout.island
                    appMenu: flyout.appMenu
                }
            }
            Page {
                id: mediaPage
                key: "media"
                sourceComponent: MediaTab {
                    island: flyout.island
                    mpris: flyout.mpris
                    mediaState: flyout.mediaState
                    cava: flyout.cava
                }
            }
            Page {
                id: notificationsPage
                key: "notifications"
                sourceComponent: NotificationsTab {
                    watcher: flyout.notifications
                }
            }
            Page {
                id: agendaPage
                key: "agenda"
                sourceComponent: AgendaTab {
                    calendar: flyout.calendar
                }
            }
            Page {
                id: shelfPage
                key: "shelf"
                sourceComponent: ShelfTab {
                    island: flyout.island
                }
            }
        }
    }
}
