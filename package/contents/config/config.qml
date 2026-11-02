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
        name: i18n("Activities")
        icon: "notifications"
        source: "configActivities.qml"
    }
}
