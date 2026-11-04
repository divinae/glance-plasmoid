/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Glance's one button look, for the cards: a rounded capsule in a light tint of the text, deeper
// under the pointer, in the accent's tint when checked or `highlighted` (the main action).
// `bare` leaves it bare until hovered: icon-only buttons, and the halves of a segmented control
// (SegmentedControl), where only the chosen one is lit. An icon-only one shows its text as a
// tooltip.
PlasmaComponents.ToolButton {
    id: button

    property bool bare: false
    // The text colour the card uses (Focus and Shift follow their own theme)
    property color textColor: Kirigami.Theme.textColor
    property int iconSize: Kirigami.Units.iconSizes.small

    readonly property bool lit: checked || highlighted
    // In a SegmentedControl: its sliding highlight shows the chosen one, not this background
    property bool segmented: false

    readonly property bool iconOnly: display === PlasmaComponents.AbstractButton.IconOnly || text === ""
    readonly property bool hasIcon: icon.name !== "" || icon.source.toString() !== ""

    icon.color: textColor
    font.weight: lit ? Font.DemiBold : Font.Normal
    // Even all round: a circle with only an icon, a capsule with room at its rounded ends
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    leftPadding: iconOnly ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
    rightPadding: leftPadding

    // Icon and text together in the middle (Plasma's stretches the text, which left it beside
    // the icon at the start of a wide button)
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: Math.max(content.implicitHeight, button.iconSize)
        Row {
            id: content
            anchors.centerIn: parent
            spacing: button.spacing
            opacity: button.enabled ? 1 : 0.4
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.hasIcon
                width: button.iconSize
                height: width
                source: button.icon.name !== "" ? button.icon.name : button.icon.source
                color: button.icon.color
                isMask: button.icon.source.toString() !== ""
            }
            PlasmaComponents.Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !button.iconOnly
                text: button.Kirigami.MnemonicData.richTextLabel
                textFormat: Text.StyledText
                font: button.font
                color: button.textColor
            }
        }
    }

    background: Rectangle {
        radius: height / 2
        color: button.lit && !button.segmented ? Qt.alpha(Kirigami.Theme.highlightColor, button.hovered ? 0.4 : 0.3)
            : button.lit ? "transparent"
            : button.hovered || button.visualFocus ? Qt.alpha(button.textColor, 0.12)
            : button.bare ? "transparent" : Qt.alpha(button.textColor, 0.07)
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    PlasmaComponents.ToolTip.text: text
    PlasmaComponents.ToolTip.visible: hovered && display === PlasmaComponents.AbstractButton.IconOnly
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
}
