/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

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

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drag => {
            if (!drag.hasUrls) {
                return;
            }
            const list = tile.items.slice();
            for (const u of drag.urls) {
                const s = String(u);
                if (s && list.indexOf(s) === -1) {
                    list.push(s);
                }
            }
            tile.island.cfg.shelfItems = list;
            drag.acceptProposedAction();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: implicitWidth
            source: "folder-download"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Shelf")
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: tile.items.length > 0
                    ? i18np("%1 file", "%1 files", tile.items.length)
                    : i18n("Drop files here")
                opacity: 0.7
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
            }
        }
    }
}
