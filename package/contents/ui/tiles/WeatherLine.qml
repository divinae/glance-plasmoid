/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The weather now, from Event Calendar, kept small: its icon and the temperature, in a row. What it's
// like, today's high / low and the place are in the tooltip; a click opens Event Calendar (its
// Weather panel is there).
RowLayout {
    id: line

    required property var weather

    signal clicked()

    spacing: Kirigami.Units.smallSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Layout.preferredWidth
        source: line.weather.iconName ? line.weather.iconName + "-symbolic" : "weather-none-available-symbolic"
        fallback: line.weather.iconName || "weather-none-available"
        isMask: true
        color: Kirigami.Theme.textColor
        opacity: 0.8
    }
    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignVCenter
        visible: line.weather.temp !== null && line.weather.temp !== undefined
        text: line.weather.temp + "°"
        font.weight: Font.DemiBold
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: line.clicked()
    }
    QQC2.ToolTip.text: [line.weather.text,
        line.weather.high !== null && line.weather.high !== undefined && line.weather.low !== null
            ? i18nc("high / low temperature", "%1° / %2°", line.weather.high, line.weather.low) : "",
        line.weather.place || ""].filter(t => !!t).join("\n")
    QQC2.ToolTip.visible: hover.hovered && QQC2.ToolTip.text !== ""
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
