/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import ".."

// Now playing, after Caelestia's media tab: a round cover inside the spectrum's rays on the left
// (tap: raise the player, swipe: next or previous), and centred on the right the track, album and
// artist, the controls, the seek bar, and a row with the player, shuffle, repeat and volume.
Item {
    id: tab

    required property PlasmoidItem island
    required property QtObject mpris
    required property Item mediaState
    required property QtObject cava

    readonly property var player: island.player
    readonly property bool hasPlayer: island.hasPlayer
    readonly property bool isPlaying: mediaState.playing
    readonly property bool hasVolume: hasPlayer && player.canControl && player.volume >= 0
    property real volumeBeforeMute: 0.5

    implicitHeight: Kirigami.Units.gridUnit * 14

    Rectangle {
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing * 2
        visible: tab.hasPlayer

        // ---- the cover in its rays ---------------------------------------------------
        Item {
            id: artBox
            readonly property real side: Math.min(height, tab.width * 0.45)
            Layout.fillHeight: true
            Layout.preferredWidth: side

            RadialCava {
                anchors.centerIn: parent
                width: artBox.side
                height: width
                cava: tab.cava
                visible: tab.cava.available && tab.isPlaying
                innerRadius: cover.width / 2 + Kirigami.Units.smallSpacing
                maxLength: artBox.side / 2 - innerRadius
                rayWidth: Math.max(2, Math.round(artBox.side / 70))
            }

            Item {
                id: cover
                anchors.centerIn: parent
                width: artBox.side * 0.62
                height: width
                x: dragHandler.active ? dragHandler.translation.x : 0
                scale: artTap.pressed ? 0.97 : 1
                Behavior on scale {
                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
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
                RoundedImage {
                    id: art
                    anchors.fill: parent
                    radius: width / 2
                    source: tab.hasPlayer ? tab.player.artUrl : ""
                    sourceSize.width: cover.width * Screen.devicePixelRatio
                    sourceSize.height: cover.height * Screen.devicePixelRatio
                }
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 30000
                    loops: Animation.Infinite
                    running: tab.isPlaying && tab.visible
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
        }

        // ---- track, controls, seek ---------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillHeight: true
            }
            AccentLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tab.hasPlayer ? (tab.player.track || tab.player.identity || "") : ""
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== "" && text !== (tab.hasPlayer ? tab.player.track : "")
                text: tab.hasPlayer ? (tab.player.album || "") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                opacity: 0.6
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: tab.hasPlayer ? (tab.player.artist || "") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                opacity: 0.85
            }

            // previous · play/pause · next
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing
                PlasmaComponents.ToolButton {
                    icon.name: "media-skip-backward"
                    icon.width: Kirigami.Units.iconSizes.smallMedium
                    icon.height: Kirigami.Units.iconSizes.smallMedium
                    enabled: tab.hasPlayer && tab.player.canGoPrevious
                    onClicked: tab.player.Previous()
                }
                Rectangle {
                    id: playButton
                    readonly property bool canToggle: tab.hasPlayer && (tab.isPlaying ? tab.player.canPause : tab.player.canPlay)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    radius: width / 2
                    color: playTap.pressed ? Qt.darker(Kirigami.Theme.highlightColor, 1.15)
                        : playHover.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.1) : Kirigami.Theme.highlightColor
                    opacity: canToggle ? 1 : 0.4
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
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

            SeekBar {
                id: seek
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
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
                    text: tab.formatTime(tab.mediaState.length)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }

            // shuffle · the player · repeat · volume
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
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
                PlasmaComponents.ToolButton {
                    id: playerChip
                    icon.name: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "multimedia-player"
                    text: tab.hasPlayer ? tab.player.identity : ""
                    display: PlasmaComponents.AbstractButton.TextBesideIcon
                    enabled: tab.mpris.count > 1
                    onClicked: players.popup(playerChip, 0, playerChip.height)
                    background: Rectangle {
                        radius: height / 2
                        color: Qt.alpha(Kirigami.Theme.highlightColor, playerChip.hovered ? 0.3 : 0.18)
                    }
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
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                    from: 0
                    to: 1
                    stepSize: 0.02
                    value: tab.hasPlayer ? tab.player.volume : 0
                    onMoved: tab.player.volume = value
                }
            }
            Item {
                Layout.fillHeight: true
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
