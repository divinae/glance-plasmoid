/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."

// Now playing, upright (Caelestia's): a round cover (a click opens the Media tab), the track in
// the accent colour, the artist, and the controls; the spectrum faint at the bottom.
Tile {
    id: tile

    required property var island
    required property QtObject cava
    required property Item mediaState

    readonly property var player: island.player
    readonly property bool hasPlayer: island.hasPlayer

    signal openMedia()

    CavaBars {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -tile.padding + 2
        height: parent.height * 0.3
        cava: tile.cava
        visible: tile.hasPlayer && tile.mediaState.playing && tile.cava.available
        stretch: true
        fadeUp: true
        boost: true
        spacing: 2
        style: tile.island.cfg.cavaPopupStyle
        rounded: tile.island.cfg.cavaRounded
        opacity: 0.25
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing / 2
        visible: tile.hasPlayer

        // The cover takes what the text and controls leave
        Item {
            id: coverArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3

            Item {
                id: coverBox
                // Not quite all of it: room around the cover, as around the text
                readonly property real side: Math.min(coverArea.width, coverArea.height) * 0.86
                anchors.centerIn: parent
                width: side
                height: side

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    visible: cover.status !== Image.Ready
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.45
                        height: width
                        source: tile.player && tile.player.iconName ? tile.player.iconName : "media-default-album"
                        opacity: 0.6
                    }
                }
                RoundedImage {
                    id: cover
                    anchors.fill: parent
                    radius: width / 2
                    source: tile.player ? tile.player.artUrl : ""
                    sourceSize: Qt.size(256, 256)
                }
                // Turns slowly while playing, as a record would
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 30000
                    loops: Animation.Infinite
                    running: tile.mediaState.playing && tile.visible
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: tile.openMedia()
                }
            }
        }

        AccentLabel {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            text: tile.player ? (tile.player.track || tile.player.identity || "") : ""
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            text: tile.player ? (tile.player.artist || "") : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            opacity: 0.75
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.ToolButton {
                icon.name: "media-skip-backward"
                enabled: !!(tile.player && tile.player.canGoPrevious)
                onClicked: tile.player.Previous()
            }
            Rectangle {
                id: playButton
                readonly property bool canToggle: !!(tile.player && (tile.mediaState.playing ? tile.player.canPause : tile.player.canPlay))
                implicitWidth: Kirigami.Units.gridUnit * 2
                implicitHeight: implicitWidth
                radius: width / 2
                color: playTap.pressed ? Qt.darker(Kirigami.Theme.highlightColor, 1.15)
                    : playHover.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.1) : Kirigami.Theme.highlightColor
                opacity: canToggle ? 1 : 0.4
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: tile.mediaState.playing ? "media-playback-pause" : "media-playback-start"
                    isMask: true
                    color: Kirigami.Theme.highlightedTextColor
                }
                HoverHandler {
                    id: playHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: playTap
                    enabled: playButton.canToggle
                    onTapped: tile.player.PlayPause()
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
