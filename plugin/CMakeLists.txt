include(ECMQmlModule)
include(ECMQtDeclareLoggingCategory)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED
    Core
    Gui
    Qml
    Quick
    Widgets
    DBus
    Concurrent
)
find_package(KF6WindowSystem ${KF6_MIN_VERSION} REQUIRED)
find_package(KF6Service ${KF6_MIN_VERSION} REQUIRED)
find_package(KF6Config ${KF6_MIN_VERSION} REQUIRED)
find_package(KF6CoreAddons ${KF6_MIN_VERSION} REQUIRED)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PipeWire REQUIRED IMPORTED_TARGET libpipewire-0.3)

# Vendored libdbusmenuqt (static inside plasma-workspace, not installed)
set(dbusmenu_SRCS
    dbusmenuqt/dbusmenuimporter.cpp
    dbusmenuqt/dbusmenushortcut_p.cpp
    dbusmenuqt/dbusmenutypes_p.cpp
    dbusmenuqt/utils.cpp
)
ecm_qt_declare_logging_category(dbusmenu_SRCS
    HEADER debug.h
    IDENTIFIER DBUSMENUQT
    CATEGORY_NAME com.dv.glance.dbusmenu
    DEFAULT_SEVERITY Warning
)
set_source_files_properties(dbusmenuqt/com.canonical.dbusmenu.xml PROPERTIES
    NO_NAMESPACE true
    INCLUDE "dbusmenutypes_p.h"
    CLASSNAME DBusMenuInterface
)
qt_add_dbus_interface(dbusmenu_SRCS dbusmenuqt/com.canonical.dbusmenu.xml dbusmenu_interface)

add_library(glancedbusmenuqt STATIC ${dbusmenu_SRCS})
set_target_properties(glancedbusmenuqt PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(glancedbusmenuqt PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/dbusmenuqt
    ${CMAKE_CURRENT_BINARY_DIR}
)
target_link_libraries(glancedbusmenuqt PUBLIC Qt::DBus Qt::Widgets)

ecm_add_qml_module(glanceplugin URI com.dv.glance.private GENERATE_PLUGIN_SOURCE)
target_sources(glanceplugin PRIVATE
    appmenumodel.cpp
    appmenumodel.h
    calendarbus.cpp
    calendarbus.h
    cavasource.cpp
    cavasource.h
    drawereffects.cpp
    drawereffects.h
    systeminfo.cpp
    systeminfo.h
    screencastmonitor.cpp
    screencastmonitor.h
    trayactions.cpp
    trayactions.h
    shelfhelper.cpp
    shelfhelper.h
    thememode.cpp
    thememode.h
)

target_link_libraries(glanceplugin PRIVATE
    Qt::Core
    Qt::Gui
    Qt::Qml
    Qt::Quick
    Qt::Widgets
    Qt::DBus
    Qt::Concurrent
    KF6::WindowSystem
    KF6::Service
    KF6::ConfigCore
    KF6::CoreAddons
    Plasma::Plasma
    Plasma::PlasmaQuick
    PkgConfig::PipeWire
    glancedbusmenuqt
)

ecm_finalize_qml_module(glanceplugin)
