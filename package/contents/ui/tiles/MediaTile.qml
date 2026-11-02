/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."

// Now playing: the cover, the track, the controls and a little spectrum. A click on the cover or
// the title opens the Media tab.
Tile {
    id: tile

    required property var island
    required property QtObject cava
    required property Item mediaState

    readonly property var player: island.player
    readonly property bool hasPlayer: island.hasPlayer

    signal openMedia()

    // The spectrum, faint, along the bottom of the card
    CavaBars {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.3
        cava: tile.cava
        visible: tile.mediaState.playing && tile.cava.available
        stretch: true
        fadeUp: true
        boost: true
        spacing: 2
        style: tile.island.cfg.cavaPopupStyle
        rounded: tile.island.cfg.cavaRounded
        opacity: 0.35
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        visible: tile.hasPlayer

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: coverFrame
                readonly property real side: Math.min(parent.width, parent.height)
                anchors.centerIn: parent
                width: side
                height: side
                radius: Kirigami.Units.cornerRadius * 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                clip: true

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    visible: cover.status !== Image.Ready
                    source: tile.player && tile.player.iconName ? tile.player.iconName : "media-default-album"
                    opacity: 0.6
                }
                Kirigami.ShadowedTexture {
                    anchors.fill: parent
                    radius: coverFrame.radius
                    visible: cover.status === Image.Ready
                    source: Image {
                        id: cover
                        source: tile.player ? tile.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(coverFrame.width * 2, coverFrame.height * 2)
                    }
                }
                TapHandler {
                    onTapped: tile.openMedia()
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tile.player ? (tile.player.track || tile.player.identity || "") : ""
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: tile.player ? (tile.player.artist || "") : ""
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        // Thin progress line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            radius: 1.5
            visible: tile.mediaState.length > 0
            color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            Rectangle {
                width: parent.width * tile.mediaState.fraction
                height: parent.height
                radius: parent.radius
                color: Kirigami.Theme.highlightColor
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                icon.name: "media-skip-backward"
                enabled: !!(tile.player && tile.player.canGoPrevious)
                onClicked: tile.player.Previous()
            }
            // Play/pause: an accent circle
            PlasmaComponents.ToolButton {
                id: playButton
                icon.name: tile.mediaState.playing ? "media-playback-pause" : "media-playback-start"
                icon.color: Kirigami.Theme.highlightedTextColor
                enabled: !!(tile.player && (tile.mediaState.playing ? tile.player.canPause : tile.player.canPlay))
                onClicked: tile.player.PlayPause()
                background: Rectangle {
                    radius: height / 2
                    color: playButton.down ? Qt.darker(Kirigami.Theme.highlightColor, 1.15)
                        : playButton.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.1) : Kirigami.Theme.highlightColor
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "media-skip-forward"
                enabled: !!(tile.player && tile.player.canGoNext)
                onClicked: tile.player.Next()
            }
        }
    }

    // Nothing playing
    ColumnLayout {
        anchors.centerIn: parent
        visible: !tile.hasPlayer
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: implicitWidth
            source: "media-default-album"
            opacity: 0.4
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Nothing playing")
            opacity: 0.6
        }
    }
}
