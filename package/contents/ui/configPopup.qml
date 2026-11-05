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
    property alias cfg_drawerBlur: drawerBlur.checked
    property alias cfg_openOnHover: openOnHover.checked
    property alias cfg_showWindowButtons: showWindowButtons.checked
    property alias cfg_showAppMenu: showAppMenu.checked
    property alias cfg_showMedia: showMedia.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_calendarEnabled: calendarEnabled.checked
    property alias cfg_showShelf: showShelf.checked
    property alias cfg_showSystem: showSystem.checked
    property alias cfg_showDevices: showDevices.checked

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
        QQC2.CheckBox {
            id: drawerBlur
            Kirigami.FormData.label: i18n("Background:")
            enabled: popupStyle.currentIndex === 0
            text: i18n("Translucent with blur, like the panel")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: openOnHover
            Kirigami.FormData.label: i18n("Open:")
            text: i18n("On hover")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showWindowButtons
            Kirigami.FormData.label: i18n("Show:")
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
            id: showDevices
            text: i18n("Controls tab (Wi-Fi, Do Not Disturb, power profile, brightness, Night Light, sound output, Bluetooth, devices)")
        }
        QQC2.CheckBox {
            id: showSystem
            text: i18n("System monitor (tab, and CPU, memory and disk on the dashboard)")
        }
    }
}
