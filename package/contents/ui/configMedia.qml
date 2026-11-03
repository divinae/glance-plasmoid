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
    property alias cfg_showProgressInPanel: showProgressInPanel.checked
    property alias cfg_cavaInPanel: cavaInPanel.checked
    property alias cfg_cavaStyle: cavaStyle.currentIndex
    property alias cfg_cavaPanelStyle: cavaPanelStyle.currentIndex
    property alias cfg_cavaPopupStyle: cavaPopupStyle.currentIndex
    property alias cfg_cavaRounded: cavaRounded.checked
    property alias cfg_cavaBackgroundOpacity: cavaBackgroundOpacity.value
    property alias cfg_cavaEdge: cavaEdge.currentIndex
    property alias cfg_cavaPanelOpacity: cavaPanelOpacity.value
    property alias cfg_cavaBars: cavaBars.value
    property alias cfg_cavaFramerate: cavaFramerate.value
    property alias cfg_cavaMonstercat: cavaMonstercat.checked
    property alias cfg_cavaNoiseReduction: cavaNoiseReduction.value
    property alias cfg_pauseOnFullscreen: pauseOnFullscreen.checked

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
        RowLayout {
            Kirigami.FormData.label: i18n("Bars opacity:")
            enabled: cavaStyle.enabled && cavaStyle.currentIndex !== 0
            QQC2.Slider {
                id: cavaPanelOpacity
                from: 10
                to: 100
                stepSize: 5
            }
            QQC2.Label {
                text: i18nc("percent", "%1%", cavaPanelOpacity.value)
            }
        }
        QQC2.SpinBox {
            id: cavaBackgroundOpacity
            Kirigami.FormData.label: i18n("Opacity behind text (%):")
            enabled: cavaStyle.enabled && cavaStyle.currentIndex === 0
            from: 5
            to: 100
            stepSize: 5
        }
        QQC2.ComboBox {
            id: cavaPopupStyle
            Kirigami.FormData.label: i18n("Popup style:")
            enabled: cavaProbe.available
            model: [i18n("Bars"), i18n("Wave")]
        }
        QQC2.CheckBox {
            id: cavaRounded
            enabled: cavaProbe.available
            text: i18n("Rounded bars")
        }
        QQC2.SpinBox {
            id: cavaBars
            Kirigami.FormData.label: i18n("Number of bars:")
            enabled: cavaProbe.available
            from: 2
            to: 64
        }
        QQC2.SpinBox {
            id: cavaFramerate
            Kirigami.FormData.label: i18n("Framerate:")
            enabled: cavaProbe.available
            from: 5
            to: 144
        }
        QQC2.CheckBox {
            id: cavaMonstercat
            Kirigami.FormData.label: i18n("Smoothing:")
            enabled: cavaProbe.available
            text: i18n("Monstercat (softer, connected peaks)")
        }
        QQC2.SpinBox {
            id: cavaNoiseReduction
            Kirigami.FormData.label: i18n("Noise reduction:")
            enabled: cavaProbe.available
            from: 0
            to: 100
        }
        QQC2.CheckBox {
            id: pauseOnFullscreen
            Kirigami.FormData.label: i18n("Performance:")
            enabled: cavaProbe.available
            text: i18n("Stop bars while a fullscreen window is active")
        }
    }
}
