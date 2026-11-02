/*
    Global menu bar, after plasma-workspace applets/appmenu/qml/main.qml
    (SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents

Flow {
    id: bar

    required property QtObject appMenu
    readonly property int count: repeater.count

    spacing: 0
    // The dashboard tile and the Window tab each have a bar: the one on show gets the menus
    Component.onCompleted: if (visible) appMenu.buttonGrid = bar
    onVisibleChanged: if (visible) appMenu.buttonGrid = bar
    Component.onDestruction: {
        if (appMenu.buttonGrid === bar) {
            appMenu.buttonGrid = null;
        }
    }

    // Only the bar on show opens menus (a hidden window's bar would place them nowhere)
    readonly property bool onShow: visible && Window.window !== null && Window.window.visible

    function activate(index) {
        if (!onShow) {
            return;
        }
        const n = repeater.count;
        if (n === 0) {
            return;
        }
        // wrap around for Left/Right navigation, skipping hidden entries
        for (let step = 0; step < n; ++step) {
            const i = ((index % n) + n) % n;
            const button = repeater.itemAt(i);
            if (button && button.visible) {
                bar.appMenu.trigger(button, i);
                return;
            }
            index += index < bar.appMenu.currentIndex ? -1 : 1;
        }
    }

    Connections {
        target: bar.appMenu
        function onRequestActivateIndex(index) {
            bar.activate(index);
        }
    }

    Repeater {
        id: repeater
        model: bar.appMenu

        PlasmaComponents.ToolButton {
            id: menuButton

            required property int index
            required property string activeMenu
            required property var activeActions

            readonly property int buttonIndex: index

            text: activeMenu
            visible: text !== "" && (!activeActions || activeActions.visible)
            down: bar.appMenu.currentIndex === index
            Accessible.description: i18nc("@info:usagetip", "Open a menu")

            onClicked: if (bar.onShow) bar.appMenu.trigger(menuButton, index)
            onHoveredChanged: {
                if (hovered && bar.onShow && bar.appMenu.menuOpen && bar.appMenu.currentIndex !== index) {
                    bar.appMenu.trigger(menuButton, index);
                }
            }
        }
    }
}
