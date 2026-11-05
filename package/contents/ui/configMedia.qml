/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import com.dv.glance.private as Island

KCM.SimpleKCM {
    property alias cfg_mediaInPanel: mediaInPanel.checked
    property alias cfg_mediaAsPill: mediaAsPill.checked
    property alias cfg_showProgressInPanel: showProgressInPanel.checked
    property alias cfg_cavaInPanel: cavaInPanel.checked
    property alias cfg_cavaStyle: cavaStyle.currentIndex
    property alias cfg_cavaPanelStyle: cavaPanelStyle.currentIndex
    property alias cfg_cavaEdge: cavaEdge.currentIndex

    Island.CavaSource {
        id: cavaProbe
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: mediaInPanel
            Kirigami.FormData.label: i18n("While playing:")
            text: i18n("Show track in panel")
        }
        QQC2.CheckBox {
            id: mediaAsPill
            enabled: mediaInPanel.checked
            text: i18n("As a pill, keeping the window's name")
        }
        QQC2.CheckBox {
            id: showProgressInPanel
            text: i18n("Show progress line along the panel edge")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Audio bars (cava)")
        }

        QQC2.Label {
            visible: !cavaProbe.available
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Install cava to see audio bars.")
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: cavaInPanel
            Kirigami.FormData.label: i18n("Panel:")
            enabled: mediaInPanel.checked && cavaProbe.available
            text: i18n("Show bars in panel")
        }
        QQC2.ComboBox {
            id: cavaStyle
            Kirigami.FormData.label: i18n("Placement:")
            enabled: cavaInPanel.enabled && cavaInPanel.checked
            model: [i18n("Behind the text"), i18n("Beside the text"), i18n("Small equalizer instead of the icon"), i18n("Along the panel's edge")]
        }
        QQC2.ComboBox {
            id: cavaPanelStyle
            Kirigami.FormData.label: i18n("Panel style:")
            enabled: cavaInPanel.enabled && cavaInPanel.checked
            model: [i18n("Bars"), i18n("Wave")]
        }
        QQC2.ComboBox {
            id: cavaEdge
            Kirigami.FormData.label: i18n("Edge:")
            enabled: cavaStyle.enabled && cavaStyle.currentIndex === 3
            model: [i18n("Outer (the screen's side)"), i18n("Inner (the windows' side)")]
        }
    }
}
