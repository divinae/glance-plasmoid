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

    // The chosen one, lit by one capsule that slides to it, as the drawer's tab indicator
    readonly property Item chosen: {
        for (let i = 0; i < row.children.length; ++i) {
            const c = row.children[i];
            if (c.checked && c.visible) {
                return c;
            }
        }
        return null;
    }
    Rectangle {
        id: lit
        visible: control.chosen !== null
        property real lo: control.chosen ? control.chosen.x : 0
        property real hi: control.chosen ? control.chosen.x + control.chosen.width : 0
        x: row.x + lo
        y: row.y
        width: Math.max(0, hi - lo)
        height: row.height
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
        Behavior on lo {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        Behavior on hi {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2
        // Their own lit background off: the capsule above shows the chosen one
        onChildrenChanged: {
            for (let i = 0; i < children.length; ++i) {
                if (children[i].segmented !== undefined) {
                    children[i].segmented = true;
                }
            }
        }
    }
}
