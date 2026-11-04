/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// A row of bare PillButtons in one capsule, the chosen one lit (`checked`): Sit | Stand,
// Focus | Posture
Rectangle {
    id: control

    property color textColor: Kirigami.Theme.textColor
    default property alias buttons: row.data

    implicitWidth: row.implicitWidth + 4
    implicitHeight: row.implicitHeight + 4
    radius: height / 2
    color: Qt.alpha(textColor, 0.07)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2
    }
}
