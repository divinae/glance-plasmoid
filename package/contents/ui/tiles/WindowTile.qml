/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import ".."

// The active window: icon, name and title, its buttons, and its application menu.
Tile {
    id: tile

    required property var island
    required property Item tasks
    required property QtObject appMenu
    readonly property Item task: island.activeTask

    implicitHeight: column.implicitHeight + padding * 2

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: tile.task && tile.task.icon ? tile.task.icon : "preferences-desktop"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: tile.task ? tile.task.appName : tile.island.cfg.placeholder
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tile.task && tile.task.title !== tile.task.appName ? tile.task.title : ""
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }
            WindowButtons {
                visible: tile.island.cfg.showWindowButtons && tile.task !== null
                island: tile.island
                tasks: tile.tasks
            }
        }

        AppMenuBar {
            id: menuBar
            Layout.fillWidth: true
            appMenu: tile.appMenu
            visible: tile.island.cfg.showAppMenu && tile.appMenu.menuAvailable && count > 0
        }
    }
}
