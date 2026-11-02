/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import ".."

// Now playing, on a card like the dashboard's: the cover large on the left (tap: raise the
// player, swipe: next or previous), the player, track, artist, album, a spectrum and the seek bar
// beside it, and the controls across the bottom with the volume.
Item {
    id: tab

    required property PlasmoidItem island
    required property QtObject mpris
    required property Item mediaState
    required property QtObject cava

    readonly property var player: island.player
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: mediaState.playing
    readonly property bool hasVolume: hasPlayer && player.canControl && player.volume >= 0
    property real volumeBeforeMute: 0.5

    implicitHeight: Kirigami.Units.gridUnit * 14

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2.5
        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
    }

    // Nothing playing
    ColumnLayout {
        anchors.centerIn: parent
        visible: !tab.hasPlayer
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 1.5
        spacing: Kirigami.Units.largeSpacing
        visible: tab.hasPlayer

        RowLayout {
            id: topRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing * 1.5

            // ---- cover ----------------------------------------------------------
            Item {
                id: artBox
                readonly property real side: Math.min(Kirigami.Units.gridUnit * 10, topRow.height)
                Layout.preferredWidth: side
                Layout.preferredHeight: side
                Layout.alignment: Qt.AlignVCenter

                Item {
                    id: artSlide
                    width: parent.width
                    height: parent.height
                    x: dragHandler.active ? dragHandler.translation.x : 0
                    Behavior on x {
                        enabled: !dragHandler.active
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                    opacity: 1 - Math.min(0.6, Math.abs(x) / width)
                    scale: artTap.pressed ? 0.97 : 1
                    Behavior on scale {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius * 2
                        blur: Kirigami.Units.gridUnit
                        offset.y: Kirigami.Units.smallSpacing
                        color: Qt.rgba(0, 0, 0, 0.3)
                        visible: art.status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius * 2
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                        visible: art.status !== Image.Ready
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: parent.width * 0.45
                            height: width
                            source: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "media-default-album"
                            opacity: 0.6
                        }
                    }
                    Kirigami.ShadowedTexture {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius * 2
                        visible: art.status === Image.Ready
                        source: Image {
                            id: art
                            source: tab.hasPlayer ? tab.player.artUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: artBox.side * Screen.devicePixelRatio
                            sourceSize.height: artBox.side * Screen.devicePixelRatio
                        }
                    }
                }
                DragHandler {
                    id: dragHandler
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (active || !tab.hasPlayer) {
                            return;
                        }
                        const dx = translation.x;
                        if (dx < -Kirigami.Units.gridUnit * 2 && tab.player.canGoNext) {
                            tab.player.Next();
                        } else if (dx > Kirigami.Units.gridUnit * 2 && tab.player.canGoPrevious) {
                            tab.player.Previous();
                        }
                    }
                }
                TapHandler {
                    id: artTap
                    enabled: tab.hasPlayer && tab.player.canRaise
                    onTapped: tab.player.Raise()
                }
                HoverHandler {
                    cursorShape: tab.hasPlayer && tab.player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            // ---- player, track, spectrum, seek ----------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing / 2

                // The player: a chip, a menu of the others when there are several
                PlasmaComponents.ToolButton {
                    id: playerChip
                    Layout.maximumWidth: parent.width
                    icon.name: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "multimedia-player"
                    text: tab.hasPlayer ? tab.player.identity : ""
                    font: Kirigami.Theme.smallFont
                    display: PlasmaComponents.AbstractButton.TextBesideIcon
                    enabled: tab.mpris.count > 1
                    opacity: 0.8
                    onClicked: players.popup(playerChip, 0, playerChip.height)
                    PlasmaComponents.Menu {
                        id: players
                        Repeater {
                            model: tab.mpris
                            delegate: PlasmaComponents.MenuItem {
                                required property int index
                                required property var model
                                text: model.identity || ""
                                icon.name: model.iconName || "multimedia-player"
                                checkable: true
                                checked: index === tab.mpris.currentIndex
                                onTriggered: tab.mpris.currentIndex = index
                            }
                        }
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: tab.hasPlayer ? (tab.player.track || tab.player.identity || "") : ""
                    textFormat: Text.PlainText
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tab.hasPlayer ? (tab.player.artist || "") : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Kirigami.Theme.highlightColor
                    font.weight: Font.DemiBold
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== "" && text !== (tab.hasPlayer ? tab.player.track : "")
                    text: tab.hasPlayer ? (tab.player.album || "") : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }

                // The spectrum fills what's left above the seek bar
                CavaBars {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit
                    cava: tab.cava
                    visible: tab.cava.available
                    opacity: tab.isPlaying ? 0.7 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.longDuration }
                    }
                    style: tab.island.cfg.cavaPopupStyle
                    rounded: tab.island.cfg.cavaRounded
                    stretch: true
                    spacing: 2
                    fadeUp: true
                    boost: true
                }
                Item {
                    Layout.fillHeight: true
                    visible: !tab.cava.available
                }

                SeekBar {
                    id: seek
                    Layout.fillWidth: true
                    visible: tab.mediaState.canSeek
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: tab.mediaState.canSeek
                    PlasmaComponents.Label {
                        text: tab.formatTime(seek.dragging ? seek.previewValue : tab.mediaState.position)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        text: "-" + tab.formatTime(tab.mediaState.length - (seek.dragging ? seek.previewValue : tab.mediaState.position))
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
        }

        // ---- controls across the bottom: shuffle | previous, play, next | repeat, volume.
        // The two sides share the rest equally, so the middle stays in the middle.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignLeft
                    PlasmaComponents.ToolButton {
                        icon.name: "media-playlist-shuffle"
                        checkable: true
                        visible: tab.hasPlayer && tab.player.shuffle !== undefined && tab.player.canControl
                        checked: tab.hasPlayer && tab.player.shuffle === true
                        opacity: checked ? 1 : 0.6
                        onClicked: tab.player.shuffle = !tab.player.shuffle
                        PlasmaComponents.ToolTip.text: i18n("Shuffle")
                        PlasmaComponents.ToolTip.visible: hovered
                    }
                Item {
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.ToolButton {
                        icon.name: "media-skip-backward"
                        icon.width: Kirigami.Units.iconSizes.smallMedium
                        icon.height: Kirigami.Units.iconSizes.smallMedium
                        enabled: tab.hasPlayer && tab.player.canGoPrevious
                        onClicked: tab.player.Previous()
                    }
                    // Play/pause: an accent pill
                    Rectangle {
                        id: playButton
                        readonly property bool canToggle: tab.hasPlayer && (tab.isPlaying ? tab.player.canPause : tab.player.canPlay)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                        radius: height / 2
                        color: playTap.pressed ? Qt.darker(Kirigami.Theme.highlightColor, 1.15)
                            : playHover.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.1) : Kirigami.Theme.highlightColor
                        opacity: canToggle ? 1 : 0.4
                        Behavior on color {
                            ColorAnimation { duration: Kirigami.Units.shortDuration }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: tab.isPlaying ? "media-playback-pause" : "media-playback-start"
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
                            onTapped: tab.player.PlayPause()
                        }
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "media-skip-forward"
                        icon.width: Kirigami.Units.iconSizes.smallMedium
                        icon.height: Kirigami.Units.iconSizes.smallMedium
                        enabled: tab.hasPlayer && tab.player.canGoNext
                        onClicked: tab.player.Next()
                    }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Item {
                    Layout.fillWidth: true
                }
                    PlasmaComponents.ToolButton {
                        readonly property int loop: tab.hasPlayer ? tab.player.loopStatus : Mpris.LoopStatus.Unknown
                        icon.name: loop === Mpris.LoopStatus.Track ? "media-repeat-single" : "media-repeat-all"
                        checkable: true
                        visible: tab.hasPlayer && loop !== Mpris.LoopStatus.Unknown && tab.player.canControl
                        checked: loop === Mpris.LoopStatus.Playlist || loop === Mpris.LoopStatus.Track
                        opacity: checked ? 1 : 0.6
                        onClicked: {
                            // None -> Playlist -> Track -> None
                            if (loop === Mpris.LoopStatus.None) {
                                tab.player.loopStatus = Mpris.LoopStatus.Playlist;
                            } else if (loop === Mpris.LoopStatus.Playlist) {
                                tab.player.loopStatus = Mpris.LoopStatus.Track;
                            } else {
                                tab.player.loopStatus = Mpris.LoopStatus.None;
                            }
                        }
                        PlasmaComponents.ToolTip.text: i18n("Repeat")
                        PlasmaComponents.ToolTip.visible: hovered
                    }
                    PlasmaComponents.ToolButton {
                        visible: tab.hasVolume
                        icon.name: !tab.hasPlayer || tab.player.volume <= 0 ? "audio-volume-muted"
                            : tab.player.volume < 0.34 ? "audio-volume-low"
                            : tab.player.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                        onClicked: {
                            if (tab.player.volume > 0) {
                                tab.volumeBeforeMute = tab.player.volume;
                                tab.player.volume = 0;
                            } else {
                                tab.player.volume = tab.volumeBeforeMute > 0 ? tab.volumeBeforeMute : 0.5;
                            }
                        }
                        PlasmaComponents.ToolTip.text: tab.hasPlayer && tab.player.volume <= 0 ? i18n("Unmute") : i18n("Mute")
                        PlasmaComponents.ToolTip.visible: hovered
                    }
                    PlasmaComponents.Slider {
                        visible: tab.hasVolume
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        from: 0
                        to: 1
                        stepSize: 0.02
                        value: tab.hasPlayer ? tab.player.volume : 0
                        onMoved: tab.player.volume = value
                    }
            }
        }
    }

    component SeekBar: Item {
        id: bar
        property bool dragging: seekArea.pressed
        property real previewValue: 0
        readonly property real length: tab.mediaState.length
        readonly property real fraction: length > 0
            ? Math.max(0, Math.min(1, (dragging ? previewValue : tab.mediaState.position) / length)) : 0
        readonly property bool active: seekArea.containsMouse || dragging

        implicitHeight: Kirigami.Units.gridUnit * 0.75

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: bar.active ? 6 : 4
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
            Behavior on height {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            Rectangle {
                width: bar.fraction * parent.width
                height: parent.height
                radius: parent.radius
                color: Kirigami.Theme.highlightColor
            }
        }
        Rectangle {
            width: Math.round(Kirigami.Units.gridUnit * 0.7)
            height: width
            radius: width / 2
            x: bar.fraction * bar.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Kirigami.Theme.highlightColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1
            opacity: bar.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
        MouseArea {
            id: seekArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function valueAt(x: real): real {
                return Math.max(0, Math.min(1, x / width)) * bar.length;
            }
            onPressed: mouse => bar.previewValue = valueAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) {
                    bar.previewValue = valueAt(mouse.x);
                }
            }
            onReleased: tab.mediaState.seek(bar.previewValue)
        }
    }


    function formatTime(us: real): string {
        const total = Math.max(0, Math.floor(us / 1000000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const ss = s < 10 ? "0" + s : "" + s;
        return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss;
    }
}
