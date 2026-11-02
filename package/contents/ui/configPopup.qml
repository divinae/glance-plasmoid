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

    Kirigami.FormLayout {
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
            to: 3000
            stepSize: 50
        }
        QQC2.SpinBox {
            id: closeDelay
            Kirigami.FormData.label: i18n("Close delay (ms):")
            from: 0
            to: 3000
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
            text: i18n("Agenda tab (from Event Calendar)")
        }
        QQC2.CheckBox {
            id: showShelf
            text: i18n("Shelf tab")
        }
    }
}
