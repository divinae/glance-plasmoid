/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

import ".."

ColumnLayout {
    id: tab

    required property PlasmoidItem island
    required property QtObject appMenu

    spacing: Kirigami.Units.smallSpacing

    AppMenuBar {
        id: menuBar
        Layout.fillWidth: true
        appMenu: tab.appMenu
        visible: tab.island.cfg.showAppMenu && tab.appMenu.menuAvailable && count > 0
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        visible: !menuBar.visible
        text: !tab.island.cfg.showAppMenu
            ? i18n("Application menu is turned off.")
            : (tab.island.hasWindow ? i18n("%1 has no application menu.", tab.island.activeTask.appName) : i18n("No active window."))
        opacity: 0.6
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        Layout.fillHeight: true
    }
}
