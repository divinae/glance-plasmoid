/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The active window's menus searched, as the old HUD, in the menu bar itself: a rounded field
// across it (in place of the menus) and the results in a card under it. A few letters of any
// item however deep ("exp png" finds File › Export › PNG…), Up/Down to pick, Enter to run it,
// Esc to leave.
Rectangle {
    id: search

    required property QtObject appMenu
    // Up (Glance's drawer held while it is)
    property bool active: false
    // Left: Esc, the ✕, focus elsewhere, or an item run (`ran` too)
    signal finished()
    signal ran()

    // What's typed
    property alias query: field.text
    property var results: []
    property int current: 0

    function refresh() {
        results = field.text.trim() === "" ? [] : appMenu.search(field.text, 40);
        current = Math.max(0, Math.min(current, results.length - 1));
    }
    function run(i) {
        const r = results[i];
        if (r && r.enabled && r.action) {
            finish();
            r.action.trigger();
            ran();
        }
    }
    function finish() {
        if (active) {
            active = false;
            appMenu.stopPrefetch();
            finished();
        }
    }

    onActiveChanged: {
        if (active) {
            field.text = "";
            refresh();
            // Submenus many apps fill only as they open: asked for now, searched again as they come
            appMenu.prefetchAll();
            field.forceActiveFocus();
        }
    }
    Connections {
        target: search.appMenu
        enabled: search.active
        function onTreeChanged() { search.refresh(); }
    }

    // The field: a capsule as Glance's buttons are, its tint deeper and an accent edge while typing
    implicitHeight: Math.max(field.implicitHeight, Kirigami.Units.iconSizes.small) + Kirigami.Units.smallSpacing * 2
    radius: height / 2
    color: Qt.alpha(Kirigami.Theme.textColor, field.activeFocus ? 0.1 : 0.07)
    border.width: 1
    border.color: field.activeFocus ? Qt.alpha(Kirigami.Theme.highlightColor, 0.6) : "transparent"
    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.shortDuration }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "search"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.7
        }
        TextInput {
            id: field
            Layout.fillWidth: true
            color: Kirigami.Theme.textColor
            selectionColor: Kirigami.Theme.highlightColor
            selectedTextColor: Kirigami.Theme.highlightedTextColor
            font: Kirigami.Theme.defaultFont
            clip: true
            onTextChanged: {
                search.current = 0;
                search.refresh();
            }
            Keys.onDownPressed: search.current = Math.max(0, Math.min(search.results.length - 1, search.current + 1))
            Keys.onUpPressed: search.current = Math.max(0, search.current - 1)
            Keys.onReturnPressed: search.run(search.current)
            Keys.onEnterPressed: search.run(search.current)
            Keys.onEscapePressed: search.finish()

            PlasmaComponents.Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: i18n("Search the menus…")
                opacity: 0.5
            }
        }
        // Clear what's typed (back to the menus: the arrow before the field, or Esc)
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            visible: field.text !== ""
            source: "edit-clear-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: clearHover.hovered ? 1 : 0.6
            HoverHandler {
                id: clearHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: {
                    field.text = "";
                    field.forceActiveFocus();
                }
            }
        }
    }

    // ---- the results: a card under the field, as wide -------------------------------------
    QQC2.Popup {
        id: resultsCard
        y: search.height + Kirigami.Units.smallSpacing
        width: search.width
        padding: Kirigami.Units.smallSpacing
        visible: search.active && field.text.trim() !== ""
        // Typing stays in the field: the card never takes the focus
        focus: false
        closePolicy: QQC2.Popup.NoAutoClose

        background: Rectangle {
            radius: Kirigami.Units.cornerRadius * 2.5
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
        }

        contentItem: ColumnLayout {
            spacing: 0
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: search.results.length === 0
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
                spacing: 2
                model: search.results
                currentIndex: search.current
                boundsBehavior: Flickable.StopAtBounds
                // A row: its name and where it lives, its shortcut as a key cap at the end; the
                // chosen one lit in a rounded band, as the agenda's rows
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === search.current
                    width: ListView.view.width
                    implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                    opacity: modelData.enabled ? 1 : 0.5

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius * 1.5
                        color: row.chosen ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }
                    RowLayout {
                        id: rowLayout
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: row.modelData.checkable && row.modelData.checked ? "✓ " + row.modelData.text : row.modelData.text
                                textFormat: Text.PlainText
                                font.weight: row.chosen ? Font.DemiBold : Font.Normal
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
                        Rectangle {
                            visible: row.modelData.shortcut !== ""
                            implicitWidth: keyLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                            implicitHeight: keyLabel.implicitHeight + 2
                            radius: Kirigami.Units.cornerRadius
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                            PlasmaComponents.Label {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: row.modelData.shortcut
                                textFormat: Text.PlainText
                                font: Kirigami.Theme.smallFont
                                opacity: 0.8
                            }
                        }
                    }
                    HoverHandler {
                        onHoveredChanged: if (hovered) search.current = row.index
                        cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        onTapped: search.run(row.index)
                    }
                }
            }
        }
    }
}
