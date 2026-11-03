/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// A tool button showing only its icon, its text as the tooltip.
PlasmaComponents.ToolButton {
    display: PlasmaComponents.AbstractButton.IconOnly
    PlasmaComponents.ToolTip.text: text
    PlasmaComponents.ToolTip.visible: hovered
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
}
