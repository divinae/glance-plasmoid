/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The active window's menus searched, as the old HUD: type a few letters of any item, however
// deep ("exp png" finds File › Export › PNG…), Up/Down to pick, Enter to run it in the app.
QQC2.Popup {
    id: search

    required property QtObject appMenu

    // An item was run: the drawer can go
    signal ran()

    property var results: []
    property int current: 0

    function refresh() {
        results = field.text.trim() === "" ? [] : appMenu.search(field.text, 40);
        current = Math.max(0, Math.min(current, results.length - 1));
    }
    function run(i) {
        const r = results[i];
        if (r && r.enabled && r.action) {
            close();
            r.action.trigger();
            ran();
        }
    }

    width: Kirigami.Units.gridUnit * 24
    padding: Kirigami.Units.smallSpacing
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    onOpened: {
        field.text = "";
        refresh();
        // Submenus many apps fill only as they open: asked for now, searched again as they come
        appMenu.prefetchAll();
        field.forceActiveFocus();
    }
    Connections {
        target: search.appMenu
        enabled: search.opened
        function onTreeChanged() { search.refresh(); }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: i18n("Search the menus…")
            onTextChanged: {
                search.current = 0;
                search.refresh();
            }
            Keys.onDownPressed: search.current = Math.max(0, Math.min(search.results.length - 1, search.current + 1))
            Keys.onUpPressed: search.current = Math.max(0, search.current - 1)
            Keys.onReturnPressed: search.run(search.current)
            Keys.onEnterPressed: search.run(search.current)
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: field.text.trim() !== "" && search.results.length === 0
            text: i18n("Nothing in the menus matches.")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
            visible: search.results.length > 0
            clip: true
            model: search.results
            currentIndex: search.current
            boundsBehavior: Flickable.StopAtBounds
            delegate: PlasmaComponents.ItemDelegate {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                highlighted: index === search.current
                enabled: modelData.enabled
                onClicked: search.run(index)
                onHoveredChanged: if (hovered) search.current = index
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: row.modelData.checkable && row.modelData.checked ? "✓ " + row.modelData.text : row.modelData.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: row.modelData.path
                            textFormat: Text.PlainText
                            font: Kirigami.Theme.smallFont
                            opacity: 0.6
                            elide: Text.ElideLeft
                        }
                    }
                    PlasmaComponents.Label {
                        visible: text !== ""
                        text: row.modelData.shortcut
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }
            }
        }
    }
}
