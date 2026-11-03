/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// What's using the camera or sharing the screen, along the top of the drawer as at the top of
// macOS's Control Center: a coloured dot, what it is, and its name.
Rectangle {
    id: bar

    required property Item privacy

    visible: privacy.anyActive
    implicitHeight: column.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: height / 2 > Kirigami.Units.gridUnit ? Kirigami.Units.cornerRadius * 2 : height / 2
    color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: 0

        component Line: RowLayout {
            id: line
            property color dot
            property string icon
            // Symbolic icons take the dot's colour; others show as they are
            property bool mask: true
            property string what
            property var names: []
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: line.dot
            }
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: line.icon
                color: line.mask ? line.dot : "transparent"
                isMask: line.mask
            }
            PlasmaComponents.Label {
                text: line.what
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: line.names.join(", ")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                opacity: 0.7
            }
        }

        Line {
            visible: bar.privacy.cameraActive
            dot: bar.privacy.cameraColor
            icon: "camera-on-symbolic"
            what: i18n("Camera in use")
            names: bar.privacy.cameraNames
        }
        Line {
            visible: bar.privacy.screenActive
            dot: bar.privacy.screenColor
            icon: "video-display"
            mask: false
            what: i18n("Screen is being shared")
            names: bar.privacy.screenNames
        }
    }
}
