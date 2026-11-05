/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// A pill's hover card (shown in its tooltip's window): a column with room around it. The cards
// (focus/FocusPopout.qml, popouts/) put their rows in it.
Item {
    id: card

    property real cardWidth: Kirigami.Units.gridUnit * 15
    default property alias content: layout.data
    // What goes behind it all, filling the card (the music card's blurred cover)
    property alias underlay: underlay.data

    implicitWidth: cardWidth
    implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2

    Item {
        id: underlay
        anchors.fill: parent
    }
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
    }
}
