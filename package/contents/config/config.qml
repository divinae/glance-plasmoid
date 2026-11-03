import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Popup")
        icon: "window"
        source: "configPopup.qml"
    }
    ConfigCategory {
        name: i18n("Media & Bars")
        icon: "media-playback-start"
        source: "configMedia.qml"
    }
    ConfigCategory {
        name: i18n("Stand")
        icon: "go-up"
        source: "configStand.qml"
    }
    ConfigCategory {
        name: i18n("Desk")
        icon: "transform-move-vertical"
        source: "configStandDesk.qml"
    }
    ConfigCategory {
        name: i18n("Focus")
        icon: "chronometer"
        source: "configFocusTimer.qml"
    }
    ConfigCategory {
        name: i18n("Focus Sessions")
        icon: "view-calendar-timeline"
        source: "configFocusSessions.qml"
    }
    ConfigCategory {
        name: i18n("Focus Dial")
        icon: "clock"
        source: "configFocusDial.qml"
    }
    ConfigCategory {
        name: i18n("Break Overlay")
        icon: "view-fullscreen"
        source: "configFocusBreak.qml"
    }
    ConfigCategory {
        name: i18n("Focus Sounds")
        icon: "preferences-desktop-notification-bell"
        source: "configFocusNotifications.qml"
    }
    ConfigCategory {
        name: i18n("Focus Scripts")
        icon: "dialog-scripts"
        source: "configFocusScripts.qml"
    }
    ConfigCategory {
        name: i18n("Activities")
        icon: "notifications"
        source: "configActivities.qml"
    }
}
