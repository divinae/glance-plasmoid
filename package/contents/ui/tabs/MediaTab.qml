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
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.mpris as Mpris

import ".."

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

    implicitHeight: column.implicitHeight + 2 * Kirigami.Units.largeSpacing

    // ---- blurred cover background + theme scrim -----------------------------
    Item {
        id: backdrop
        anchors.fill: parent
        visible: false
        Image {
            id: bgArt
            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
        }
        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
            opacity: 0.55
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: backdrop
        visible: bgArt.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.6
        opacity: 0.6
        maskEnabled: true
        maskSource: mask
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // ---- art + info + controls ------------------------------------------
        RowLayout {
            id: topRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 5
            spacing: Kirigami.Units.largeSpacing

            // Cover: swipe left/right for next/previous, tap to raise the player
            Item {
                id: artBox
                readonly property real side: Math.min(Kirigami.Units.gridUnit * 8, topRow.height)
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

                    RectangularShadow {
                        anchors.fill: parent
                        radius: artMask.radius
                        blur: Kirigami.Units.gridUnit
                        offset.y: Kirigami.Units.smallSpacing
                        color: Qt.rgba(0, 0, 0, 0.35)
                        visible: art.status === Image.Ready
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        source: tab.hasPlayer ? tab.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Kirigami.Units.gridUnit * 8 * Screen.devicePixelRatio
                        sourceSize.height: Kirigami.Units.gridUnit * 8 * Screen.devicePixelRatio
                        visible: false
                    }
                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius * 2
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: art
                        visible: art.status === Image.Ready
                        maskEnabled: true
                        maskSource: artMask
                    }
                    Kirigami.Icon {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        visible: art.status !== Image.Ready
                        source: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "media-default-album"
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
                    enabled: tab.hasPlayer && tab.player.canRaise
                    onTapped: tab.player.Raise()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                PlasmaComponents.ComboBox {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    visible: tab.mpris.count > 1
                    flat: true
                    model: tab.mpris
                    textRole: "identity"
                    currentIndex: tab.mpris.currentIndex
                    onActivated: index => tab.mpris.currentIndex = index
                }

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: tab.hasPlayer ? (tab.player.track || tab.player.identity) : ""
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    textFormat: Text.PlainText
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tab.hasPlayer ? tab.player.artist : ""
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    opacity: 0.85
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tab.hasPlayer ? tab.player.album : ""
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }

                Item {
                    Layout.fillHeight: true
                }

                // transport + compact volume, aligned with the bottom of the cover
                RowLayout {
                    Layout.fillWidth: true
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
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "media-skip-backward"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: tab.hasPlayer && tab.player.canGoPrevious
                        onClicked: tab.player.Previous()
                    }

                    // round accent play/pause
                    Rectangle {
                        id: playButton
                        readonly property bool canToggle: tab.hasPlayer && (tab.isPlaying ? tab.player.canPause : tab.player.canPlay)
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        opacity: canToggle ? 1 : 0.4
                        scale: playTap.pressed ? 0.92 : playHover.hovered ? 1.06 : 1
                        Behavior on scale {
                            NumberAnimation { duration: Kirigami.Units.shortDuration }
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
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: tab.hasPlayer && tab.player.canGoNext
                        onClicked: tab.player.Next()
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
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }

                    Item {
                        Layout.fillWidth: true
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
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
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

        // ---- spectrum: thin bars rising from the seek bar ----------------------
        CavaBars {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 1.5)
            visible: tab.cava.available
            opacity: tab.isPlaying ? 0.8 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }
            cava: tab.cava
            style: tab.island.cfg.cavaPopupStyle
            rounded: tab.island.cfg.cavaRounded
            stretch: true
            spacing: 2
            fadeUp: true
            boost: true
        }

        // ---- seek -------------------------------------------------------------
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

    // Thin progress track; handle only on hover/drag, seeks on release
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
