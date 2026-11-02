/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

import com.dv.island.private as Island

// Files dropped here stay until removed; drag them out again anywhere.
Item {
    id: tab

    required property PlasmoidItem island

    readonly property var items: island.cfg.shelfItems || []

    implicitHeight: column.implicitHeight

    function add(urls) {
        const list = items.slice();
        for (const u of urls) {
            const s = String(u);
            if (s && list.indexOf(s) === -1) {
                list.push(s);
            }
        }
        Plasmoid.configuration.shelfItems = list;
    }
    function remove(url) {
        Plasmoid.configuration.shelfItems = items.filter(u => u !== url);
    }

    Component.onCompleted: {
        // drop entries whose files were deleted meanwhile
        const alive = items.filter(u => Island.ShelfHelper.exists(u));
        if (alive.length !== items.length) {
            Plasmoid.configuration.shelfItems = alive;
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drag => {
            if (drag.hasUrls) {
                tab.add(drag.urls);
                drag.acceptProposedAction();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2
        color: "transparent"
        border.width: drop.containsDrag ? 2 : 1
        border.color: drop.containsDrag ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: tab.items.length === 0
            text: i18n("Drop files here to keep them at hand.\nDrag them out again into any app.")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            opacity: 0.6
        }

        Flow {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: tab.items.length > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: tab.items

                PlasmaComponents.ToolButton {
                    id: tile
                    required property string modelData

                    width: Kirigami.Units.gridUnit * 5
                    height: Kirigami.Units.gridUnit * 5
                    display: PlasmaComponents.AbstractButton.TextUnderIcon
                    icon.name: Island.ShelfHelper.iconName(modelData)
                    icon.width: Kirigami.Units.iconSizes.large
                    icon.height: Kirigami.Units.iconSizes.large
                    text: Island.ShelfHelper.fileName(modelData)
                    onClicked: Qt.openUrlExternally(modelData)

                    PlasmaComponents.ToolTip.text: Island.ShelfHelper.fileName(modelData)
                        + (Island.ShelfHelper.sizeText(modelData) ? "\n" + Island.ShelfHelper.sizeText(modelData) : "")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

                    // drag out into other apps
                    Drag.active: dragHandler.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
                    Drag.mimeData: ({"text/uri-list": modelData})
                    DragHandler {
                        id: dragHandler
                        target: null
                    }
                    onHoveredChanged: {
                        if (hovered && !Drag.imageSource.toString()) {
                            grabToImage(r => tile.Drag.imageSource = r.url);
                        }
                    }

                    PlasmaComponents.ToolButton {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        visible: tile.hovered
                        icon.name: "edit-delete-remove"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                        height: width
                        onClicked: tab.remove(tile.modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: tab.items.length > 0
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                text: i18n("Clear Shelf")
                icon.name: "edit-clear-all"
                onClicked: Plasmoid.configuration.shelfItems = []
            }
        }
    }
}
