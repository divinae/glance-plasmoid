/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import com.dv.island.private as Island

import ".."

// Who and what (Caelestia's): the user's picture and name, then the system, the desktop, the
// kernel and how long it's been up.
Tile {
    id: tile

    KCoreAddons.KUser {
        id: user
    }

    property int uptime: Island.SystemInfo.uptime()
    Timer {
        interval: 60000
        repeat: true
        running: tile.visible
        onTriggered: tile.uptime = Island.SystemInfo.uptime()
    }
    onVisibleChanged: if (visible) uptime = Island.SystemInfo.uptime()

    function uptimeText(secs: int): string {
        const d = Math.floor(secs / 86400);
        const h = Math.floor(secs % 86400 / 3600);
        const m = Math.floor(secs % 3600 / 60);
        if (d > 0) {
            return i18nc("uptime: days and hours", "up %1 d %2 h", d, h);
        }
        if (h > 0) {
            return i18nc("uptime: hours and minutes", "up %1 h %2 min", h, m);
        }
        return i18nc("uptime: minutes", "up %1 min", m);
    }

    // The picture: the user's own (~/.face.icon), the one from the login screen's accounts, or
    // an icon
    readonly property var faces: [
        String(user.faceIconUrl || ""),
        "file:///var/lib/AccountsService/icons/" + user.loginName,
    ].filter(u => u !== "" && u !== "file:")
    property int faceIndex: 0

    component Line: RowLayout {
        id: line
        property string icon
        property string text
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: line.icon
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: line.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Item {
            readonly property real side: Math.min(parent.height, Kirigami.Units.gridUnit * 4)
            Layout.preferredWidth: side
            Layout.preferredHeight: side
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.2)
                visible: face.status !== Image.Ready
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: width
                    source: "user-identity"
                }
            }
            RoundedImage {
                id: face
                anchors.fill: parent
                radius: width / 2
                source: tile.faceIndex < tile.faces.length ? tile.faces[tile.faceIndex] : ""
                sourceSize: Qt.size(width * 2, height * 2)
                onStatusChanged: {
                    if (status === Image.Error && tile.faceIndex < tile.faces.length) {
                        tile.faceIndex++;
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing / 2

            AccentLabel {
                Layout.fillWidth: true
                text: (user.fullName || user.loginName) + "@" + Island.SystemInfo.hostName
                textFormat: Text.PlainText
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Line {
                icon: KCoreAddons.KOSRelease.logo || "start-here-kde"
                text: KCoreAddons.KOSRelease.prettyName || KCoreAddons.KOSRelease.name
            }
            Line {
                icon: "plasmashell"
                text: i18nc("desktop and its version", "KDE Plasma %1", Island.SystemInfo.plasmaVersion)
            }
            Line {
                icon: "preferences-system-linux"
                text: i18nc("kernel version", "Linux %1", Island.SystemInfo.kernel)
            }
            Line {
                icon: "chronometer"
                text: tile.uptimeText(tile.uptime)
            }
        }
    }
}
