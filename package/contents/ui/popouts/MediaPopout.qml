/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import ".."
import "../common"
import "../common/Utils.js" as Utils

// The music pill's card, laid out as the dashboard's music card: the round cover in the spectrum's
// rays (turning slowly while it plays), the cover blurred under it all, the track, artist and
// player centred, the progress (seek by click, drag or wheel), previous · play · next with play in
// a colour from the cover, and the volume. The Media tab from the corner arrow or the cover.
PopoutCard {
    id: card

    required property var island
    required property Item mediaState
    required property QtObject cava
    readonly property var player: island.player
    readonly property color accent: island.albumAccent
    // The player's own volume, when it lets it be set
    readonly property bool hasVolume: !!player && player.canControl && player.volume >= 0
    property real volumeBeforeMute: 0.5

    cardWidth: Kirigami.Units.gridUnit * 15

    underlay: [
        CoverBackdrop {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            source: cover.ready ? cover.front.source : ""
            strength: 0.35
        },
        // The Media tab, for the rest
        PillButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Kirigami.Units.smallSpacing
            z: 1
            bare: true
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Open the Media tab")
            icon.name: "go-next-symbolic"
            onClicked: card.island.openOn("media", true)
        }
    ]

    // ---- the round cover in its rays ---------------------------------------------------------
    Item {
        id: coverArea
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        RadialCava {
            anchors.centerIn: parent
            width: coverArea.height
            height: width
            cava: card.cava
            visible: card.island.playing && card.cava.available
            innerRadius: coverBox.width / 2 + Kirigami.Units.smallSpacing / 2
            maxLength: width / 2 - innerRadius
            // Thin rays, finer than the dashboard's
            rayWidth: Math.max(1, Math.round(width / 110))
        }
        Item {
            id: coverBox
            // Room around it for the rays
            anchors.centerIn: parent
            width: coverArea.height * 0.68
            height: width
            scale: coverTap.pressed ? 0.96 : 1
            Behavior on scale {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                visible: !cover.ready
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    source: card.player && card.player.iconName ? card.player.iconName : "media-default-album"
                    opacity: 0.6
                }
            }
            CoverArt {
                id: cover
                anchors.fill: parent
                source: card.player ? card.player.artUrl : ""
                sourceSize: Qt.size(256, 256)
            }
            // Turns slowly while playing, as a record would
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 30000
                loops: Animation.Infinite
                running: card.island.playing && card.visible
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: coverTap
                onTapped: card.island.openOn("media", true)
            }
        }
    }

    // ---- the track, centred ---------------------------------------------------------------
    AccentLabel {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        horizontalAlignment: Text.AlignHCenter
        color: Kirigami.ColorUtils.linearInterpolation(card.accent, Kirigami.Theme.textColor, 0.4)
        text: card.player ? (card.player.track || card.player.identity || "") : ""
        textFormat: Text.PlainText
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: card.player ? (card.player.artist || "") : ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        opacity: 0.8
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        visible: text !== "" && !!card.player && !!card.player.track
        text: card.player ? (card.player.identity || "") : ""
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        elide: Text.ElideRight
        opacity: 0.6
    }

    // ---- how far in, when the track has a length (a stream has none) -------------------------
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: card.mediaState.canSeek
        spacing: 2
        // Click or drag to seek, the wheel for 5 s
        ThinSlider {
            Layout.fillWidth: true
            color: card.accent
            from: 0
            to: Math.max(1, card.mediaState.length)
            value: card.mediaState.position
            wheelStep: 5000000
            onMoved: value => card.mediaState.seek(value)
        }
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: Utils.formatTrackTime(card.mediaState.position)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.7
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: Utils.formatTrackTime(card.mediaState.length)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.7
            }
        }
    }

    // ---- previous · play/pause · next, play round in the cover's colour ----------------------
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing
        PillButton {
            bare: true
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Previous")
            icon.name: "media-skip-backward"
            iconSize: Kirigami.Units.iconSizes.smallMedium
            enabled: !!card.player && card.player.canGoPrevious
            onClicked: card.player.Previous()
        }
        Rectangle {
            id: playButton
            readonly property bool canToggle: !!card.player && (card.island.playing ? card.player.canPause : card.player.canPlay)
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: playTap.pressed ? Qt.darker(card.accent, 1.15)
                : playHover.hovered ? Qt.lighter(card.accent, 1.1) : card.accent
            opacity: canToggle ? 1 : 0.4
            scale: playTap.pressed ? 0.92 : 1
            Behavior on scale {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.smallMedium
                height: width
                source: card.island.playing ? "media-playback-pause" : "media-playback-start"
                isMask: true
                color: card.island.onAlbumAccent
            }
            HoverHandler {
                id: playHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: playTap
                enabled: playButton.canToggle
                onTapped: card.player.PlayPause()
            }
            Accessible.role: Accessible.Button
            Accessible.name: card.island.playing ? i18n("Pause") : i18n("Play")
        }
        PillButton {
            bare: true
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Next")
            icon.name: "media-skip-forward"
            iconSize: Kirigami.Units.iconSizes.smallMedium
            enabled: !!card.player && card.player.canGoNext
            onClicked: card.player.Next()
        }
    }

    // ---- the volume: the speaker mutes and unmutes, the slider sets it ------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: card.hasVolume
        spacing: Kirigami.Units.smallSpacing
        PillButton {
            bare: true
            display: PlasmaComponents.AbstractButton.IconOnly
            text: card.hasVolume && card.player.volume <= 0 ? i18n("Unmute") : i18n("Mute")
            icon.name: !card.hasVolume || card.player.volume <= 0 ? "audio-volume-muted"
                : card.player.volume < 0.34 ? "audio-volume-low"
                : card.player.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
            onClicked: {
                if (card.player.volume > 0) {
                    card.volumeBeforeMute = card.player.volume;
                    card.player.volume = 0;
                } else {
                    card.player.volume = card.volumeBeforeMute > 0 ? card.volumeBeforeMute : 0.5;
                }
            }
        }
        ThinSlider {
            Layout.fillWidth: true
            color: card.accent
            value: card.hasVolume ? card.player.volume : 0
            wheelStep: 0.05
            onMoved: value => card.player.volume = value
        }
        PlasmaComponents.Label {
            Layout.minimumWidth: volumeMetrics.advanceWidth
            horizontalAlignment: Text.AlignRight
            text: card.hasVolume ? i18nc("a volume, in percent", "%1%", Math.round(card.player.volume * 100)) : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.features: { "tnum": 1 }
            opacity: 0.7
            TextMetrics {
                id: volumeMetrics
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: "100%"
            }
        }
    }
}
