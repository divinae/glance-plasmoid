/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_compactStyle: compactStyle.currentIndex
    property alias cfg_placeholder: placeholder.text
    property alias cfg_maxTitleLength: maxTitleLength.value
    property alias cfg_showCapsule: showCapsule.checked
    property alias cfg_pillCamera: pillCamera.checked
    property alias cfg_pillMicrophone: pillMicrophone.checked
    property alias cfg_pillScreen: pillScreen.checked
    property alias cfg_pillDnd: pillDnd.checked
    property alias cfg_showAppIcon: showAppIcon.checked
    property alias cfg_boldFont: boldFont.checked
    property alias cfg_capitalFont: capitalFont.checked
    property alias cfg_lengthMargin: lengthMargin.value
    property alias cfg_filterByScreen: filterByScreen.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: compactStyle
            Kirigami.FormData.label: i18n("Panel text:")
            model: [i18n("Application name"), i18n("Window title"), i18n("Application — title")]
        }
        QQC2.TextField {
            id: placeholder
            Kirigami.FormData.label: i18n("Text with no window:")
        }
        QQC2.SpinBox {
            id: maxTitleLength
            Kirigami.FormData.label: i18n("Maximum characters:")
            from: 4
            to: 200
        }
        QQC2.SpinBox {
            id: lengthMargin
            Kirigami.FormData.label: i18n("Margins:")
            from: 0
            to: 64
        }
        QQC2.CheckBox {
            id: pillCamera
            Kirigami.FormData.label: i18n("Show in the panel:")
            text: i18n("Camera in use")
        }
        QQC2.CheckBox {
            id: pillMicrophone
            text: i18n("Microphone in use")
        }
        QQC2.CheckBox {
            id: pillScreen
            text: i18n("Screen being shared")
        }
        QQC2.CheckBox {
            id: pillDnd
            text: i18n("Do Not Disturb")
        }
        QQC2.CheckBox {
            id: showCapsule
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Capsule behind the text")
        }
        QQC2.CheckBox {
            id: showAppIcon
            Kirigami.FormData.label: i18n("Icon:")
            text: i18n("Show the application's icon")
        }
        QQC2.CheckBox {
            id: boldFont
            Kirigami.FormData.label: i18n("Font:")
            text: i18n("Bold")
        }
        QQC2.CheckBox {
            id: capitalFont
            text: i18n("Capitalize first letters")
        }
        QQC2.CheckBox {
            id: filterByScreen
            Kirigami.FormData.label: i18n("Windows:")
            text: i18n("Only windows on this screen")
        }
    }
}
