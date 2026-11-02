/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

// Keep above, minimize, maximize, close for the active window.
RowLayout {
    id: buttons

    required property PlasmoidItem island
    required property Item tasks
    readonly property Item task: island.activeTask

    spacing: 0

    component WindowButton: PlasmaComponents.ToolButton {
        PlasmaComponents.ToolTip.text: text
        PlasmaComponents.ToolTip.visible: hovered
        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        display: PlasmaComponents.AbstractButton.IconOnly
    }

    WindowButton {
        icon.name: "window-pin"
        text: i18n("Keep Above Others")
        checkable: true
        checked: buttons.task ? buttons.task.isKeepAbove : false
        onClicked: buttons.tasks.toggleKeepAbove()
    }
    WindowButton {
        icon.name: "window-minimize"
        text: i18n("Minimize")
        onClicked: {
            buttons.tasks.toggleMinimized();
            buttons.island.setOpen(false);
        }
    }
    WindowButton {
        icon.name: buttons.task && buttons.task.isMaximized ? "window-restore" : "window-maximize"
        text: buttons.task && buttons.task.isMaximized ? i18n("Restore") : i18n("Maximize")
        onClicked: buttons.tasks.toggleMaximized()
    }
    WindowButton {
        icon.name: "window-close"
        text: i18n("Close")
        onClicked: {
            buttons.tasks.requestClose();
            buttons.island.setOpen(false);
        }
    }
}
