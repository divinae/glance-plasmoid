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
    Component.onCompleted: appMenu.buttonGrid = bar
    Component.onDestruction: {
        if (appMenu.buttonGrid === bar) {
            appMenu.buttonGrid = null;
        }
    }

    function activate(index) {
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

            onClicked: bar.appMenu.trigger(menuButton, index)
            onHoveredChanged: {
                if (hovered && bar.appMenu.menuOpen && bar.appMenu.currentIndex !== index) {
                    bar.appMenu.trigger(menuButton, index);
                }
            }
        }
    }
}
