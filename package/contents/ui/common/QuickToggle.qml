/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// A quick-settings toggle: an icon in a rounded tile, filled with the accent when on (or with
// the negative colour, for `alert`: the microphone muted). With a `label`, the name under the
// icon's side (the Controls tab); without, the name as a tooltip (the dashboard's narrow card).
// One icon whatever the state, the fill tells it: themes draw their "off" icons faint or smaller.
Rectangle {
    id: toggle

    property string iconName
    // For a theme without iconName (GNOME's names, full-size in most themes, Breeze's as fallback)
    property string fallbackIcon
    property string label
    property string tip: label
    property bool on: false
    property bool alert: false
    signal toggled()

    readonly property color fill: alert ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.7
    radius: Kirigami.Units.cornerRadius * 2
    color: on ? Qt.alpha(fill, toggleHover.hovered ? 0.85 : 0.7)
        : Qt.alpha(Kirigami.Theme.textColor, toggleHover.hovered ? 0.12 : 0.07)
    opacity: enabled ? 1 : 0.5
    scale: toggleTap.pressed ? 0.94 : 1
    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.shortDuration }
    }
    Behavior on scale {
        NumberAnimation { duration: Kirigami.Units.shortDuration }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - Kirigami.Units.largeSpacing * 2)
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: toggle.iconName
            fallback: toggle.fallbackIcon
            isMask: true
            color: toggle.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: toggle.label !== ""
            text: toggle.label
            color: toggle.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            elide: Text.ElideRight
        }
    }
    HoverHandler {
        id: toggleHover
        cursorShape: toggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        id: toggleTap
        enabled: toggle.enabled
        onTapped: toggle.toggled()
    }
    PlasmaComponents.ToolTip.text: tip
    PlasmaComponents.ToolTip.visible: toggleHover.hovered && tip !== "" && tip !== label
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
    Accessible.role: Accessible.CheckBox
    Accessible.checked: on
    Accessible.name: tip
}
