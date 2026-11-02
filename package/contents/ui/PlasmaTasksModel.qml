/*
    Active window tracking, adapted from org.kde.windowtitle.Fork (applet-window-title,
    SPDX-FileCopyrightText: 2018 Michail Vourlakos <mvourlakos@gmail.com>).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

Item {
    id: plasmaTasksItem

    property rect screenGeometry
    property bool filterByScreen: true

    // Last window that was active. Kept while a Plasma popup (e.g. our own flyout) has focus,
    // because TasksModel does not list plasmashell windows.
    property Item activeTaskItem: null
    readonly property bool existsWindowActive: activeTaskItem !== null

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: plasmaTasksItem.screenGeometry
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop

        filterByScreen: plasmaTasksItem.filterByScreen
        filterByVirtualDesktop: true
        filterByActivity: true
    }

    // Desktop/activity switch: the remembered window may no longer be visible here
    Connections {
        target: virtualDesktopInfo
        function onCurrentDesktopChanged() {
            plasmaTasksItem.activeTaskItem = null;
            plasmaTasksItem.pickActive();
        }
    }
    Connections {
        target: activityInfo
        function onCurrentActivityChanged() {
            plasmaTasksItem.activeTaskItem = null;
            plasmaTasksItem.pickActive();
        }
    }

    function pickActive() {
        for (let i = 0; i < tasksRepeater.count; ++i) {
            const t = tasksRepeater.itemAt(i);
            if (t && t.isActive) {
                activeTaskItem = t;
                return;
            }
        }
    }

    Repeater {
        id: tasksRepeater
        model: tasksModel

        Item {
            id: task

            required property int index
            required property var model

            readonly property string appName: modelAppName !== "" ? modelAppName : discoveredAppName
            readonly property bool isMinimized: model.IsMinimized === true
            readonly property bool isMaximized: model.IsMaximized === true
            readonly property bool isActive: model.IsActive === true
            readonly property bool isKeepAbove: model.IsKeepAbove === true
            readonly property bool isFullScreen: model.IsFullScreen === true
            readonly property bool isOnAllDesktops: model.IsOnAllVirtualDesktops === true
            readonly property var icon: model.decoration
            readonly property string menuService: model.ApplicationMenuServiceName ?? ""
            readonly property string menuPath: model.ApplicationMenuObjectPath ?? ""

            readonly property string modelAppName: model.AppName ?? ""
            readonly property string modelDisplay: model.display ?? ""

            property string title: ""
            property string discoveredAppName: ""

            function cleanupTitle() {
                const t = modelDisplay;
                const separators = [" —– ", " -- ", " — ", " - "];
                let sep = -1;
                let spacer = 0;
                for (const s of separators) {
                    sep = t.lastIndexOf(s);
                    if (sep > -1) {
                        spacer = s.length;
                        break;
                    }
                }

                if (sep > -1) {
                    let dTitle = t.substring(0, sep);
                    discoveredAppName = t.substring(sep + spacer);
                    // if title starts with application name, swap
                    if (modelAppName !== "" && dTitle.startsWith(modelAppName)) {
                        const firstPart = dTitle;
                        dTitle = discoveredAppName;
                        discoveredAppName = firstPart;
                    }
                    title = dTitle;
                } else {
                    discoveredAppName = "";
                    title = t;
                }
            }

            onIsActiveChanged: {
                if (isActive) {
                    plasmaTasksItem.activeTaskItem = task;
                }
            }
            // Minimized away with nothing else taking focus: show the placeholder
            onIsMinimizedChanged: {
                if (isMinimized && plasmaTasksItem.activeTaskItem === task) {
                    plasmaTasksItem.activeTaskItem = null;
                }
            }

            onModelAppNameChanged: cleanupTitle()
            onModelDisplayChanged: cleanupTitle()
            Component.onCompleted: {
                cleanupTitle();
                if (isActive) {
                    plasmaTasksItem.activeTaskItem = task;
                }
            }
            Component.onDestruction: {
                if (plasmaTasksItem.activeTaskItem === task) {
                    plasmaTasksItem.activeTaskItem = null;
                    Qt.callLater(plasmaTasksItem.pickActive);
                }
            }

            function modelIndex() {
                return tasksModel.makeModelIndex(index);
            }
            function toggleMaximized() {
                tasksModel.requestToggleMaximized(modelIndex());
            }
            function toggleMinimized() {
                tasksModel.requestToggleMinimized(modelIndex());
            }
            function requestClose() {
                tasksModel.requestClose(modelIndex());
            }
            function toggleKeepAbove() {
                tasksModel.requestToggleKeepAbove(modelIndex());
            }
            function activate() {
                tasksModel.requestActivate(modelIndex());
            }
        }
    }

    function toggleMaximized() {
        activeTaskItem?.toggleMaximized();
    }
    function toggleMinimized() {
        activeTaskItem?.toggleMinimized();
    }
    function requestClose() {
        activeTaskItem?.requestClose();
    }
    function toggleKeepAbove() {
        activeTaskItem?.toggleKeepAbove();
    }
    function activate() {
        activeTaskItem?.activate();
    }
}
