/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_popupStyle: popupStyle.currentIndex
    property alias cfg_drawerEdge: drawerEdge.currentIndex
    property alias cfg_drawerRadius: drawerRadius.value
    property alias cfg_drawerWidth: drawerWidth.value
    property alias cfg_showDashboard: showDashboard.checked
    property alias cfg_drawerBlur: drawerBlur.checked
    property alias cfg_drawerOpacity: drawerOpacity.value
    property alias cfg_openOnHover: openOnHover.checked
    property alias cfg_hoverDelay: hoverDelay.value
    property alias cfg_closeDelay: closeDelay.value
    property alias cfg_popupHeight: popupHeight.value
    property alias cfg_switchTabOnHover: switchTabOnHover.checked
    property alias cfg_showWindowButtons: showWindowButtons.checked
    property alias cfg_showAppMenu: showAppMenu.checked
    property alias cfg_showMedia: showMedia.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_calendarEnabled: calendarEnabled.checked
    property alias cfg_showShelf: showShelf.checked
    property alias cfg_showSystem: showSystem.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: popupStyle
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Drawer from the screen edge"), i18n("Plasma popup")]
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: popupStyle.currentIndex === 0
            text: i18n("The drawer needs layer-shell-qt; without it the Plasma popup is used.")
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }
        QQC2.ComboBox {
            id: drawerEdge
            Kirigami.FormData.label: i18n("Drawer opens:")
            enabled: popupStyle.currentIndex === 0
            model: [i18n("From the panel, beside Glance"), i18n("From the top of the screen")]
        }
        QQC2.SpinBox {
            id: drawerWidth
            Kirigami.FormData.label: i18n("Drawer width (grid units):")
            enabled: popupStyle.currentIndex === 0
            from: 20
            to: 50
        }
        QQC2.CheckBox {
            id: drawerBlur
            Kirigami.FormData.label: i18n("Background:")
            enabled: popupStyle.currentIndex === 0
            text: i18n("Translucent with blur, like the panel")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: popupStyle.currentIndex === 0 && drawerBlur.checked
            QQC2.Slider {
                id: drawerOpacity
                from: 20
                to: 100
                stepSize: 5
            }
            QQC2.Label {
                text: i18nc("percent", "%1%", drawerOpacity.value)
            }
        }
        QQC2.SpinBox {
            id: drawerRadius
            Kirigami.FormData.label: i18n("Corner radius (px):")
            enabled: popupStyle.currentIndex === 0
            from: 0
            to: 48
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: openOnHover
            Kirigami.FormData.label: i18n("Open:")
            text: i18n("On hover")
        }
        QQC2.SpinBox {
            id: hoverDelay
            Kirigami.FormData.label: i18n("Open delay (ms):")
            enabled: openOnHover.checked
            from: 0
            to: 2000
            stepSize: 50
        }
        QQC2.SpinBox {
            id: closeDelay
            Kirigami.FormData.label: i18n("Close delay (ms):")
            from: 0
            to: 2000
            stepSize: 50
        }
        QQC2.SpinBox {
            id: popupHeight
            Kirigami.FormData.label: i18n("Height (grid units):")
            from: 10
            to: 40
        }
        QQC2.CheckBox {
            id: switchTabOnHover
            Kirigami.FormData.label: i18n("Tabs:")
            text: i18n("Switch on hover")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showDashboard
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("Dashboard tab")
        }
        QQC2.CheckBox {
            id: showWindowButtons
            text: i18n("Window buttons")
        }
        QQC2.CheckBox {
            id: showAppMenu
            text: i18n("Application menu")
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Apps that support a global menu hide their own menu bar while this is on.")
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }
        QQC2.CheckBox {
            id: showMedia
            text: i18n("Media tab")
        }
        QQC2.CheckBox {
            id: showNotifications
            text: i18n("Notifications tab")
        }
        QQC2.CheckBox {
            id: calendarEnabled
            text: i18n("Today's events (from Event Calendar)")
        }
        QQC2.CheckBox {
            id: showShelf
            text: i18n("Shelf tab")
        }
        QQC2.CheckBox {
            id: showSystem
            text: i18n("System monitor (tab, and CPU, memory and disk on the dashboard)")
        }
    }
}
