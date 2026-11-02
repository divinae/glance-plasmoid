/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The shelf at a glance: how many files it holds, and a place to drop more. A click opens it.
Tile {
    id: tile

    required property var island
    readonly property var items: island.cfg.shelfItems || []

    clickable: true
    border.width: drop.containsDrag ? 2 : 0
    border.color: Kirigami.Theme.highlightColor

    DragDrop.DropArea {
        id: drop
        anchors.fill: parent
        onDragEnter: event => {
            if (tile.island.dropHasFiles(event)) {
                event.accept(Qt.CopyAction);
            }
        }
        onDrop: event => tile.island.acceptFiles(event)
    }

    // Side by side when there's room, the icon over the text when narrow
    GridLayout {
        anchors.fill: parent
        columns: tile.width > Kirigami.Units.gridUnit * 9 ? 2 : 1
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Layout.alignment: Qt.AlignCenter
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: implicitWidth
            source: "folder-download"
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: parent.parent.columns === 1 ? Text.AlignHCenter : Text.AlignLeft
                text: i18n("Shelf")
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: parent.parent.columns === 1 ? Text.AlignHCenter : Text.AlignLeft
                text: tile.items.length > 0
                    ? i18np("%1 file", "%1 files", tile.items.length)
                    : i18n("Drop files here")
                opacity: 0.7
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
            }
        }
    }
}
