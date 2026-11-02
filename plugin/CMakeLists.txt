include(ECMQmlModule)
include(ECMQtDeclareLoggingCategory)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED
    Core
    Gui
    Qml
    Quick
    Widgets
    DBus
)

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
    CATEGORY_NAME com.dv.island.dbusmenu
    DEFAULT_SEVERITY Warning
)
set_source_files_properties(dbusmenuqt/com.canonical.dbusmenu.xml PROPERTIES
    NO_NAMESPACE true
    INCLUDE "dbusmenutypes_p.h"
    CLASSNAME DBusMenuInterface
)
qt_add_dbus_interface(dbusmenu_SRCS dbusmenuqt/com.canonical.dbusmenu.xml dbusmenu_interface)

add_library(islanddbusmenuqt STATIC ${dbusmenu_SRCS})
set_target_properties(islanddbusmenuqt PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(islanddbusmenuqt PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/dbusmenuqt
    ${CMAKE_CURRENT_BINARY_DIR}
)
target_link_libraries(islanddbusmenuqt PUBLIC Qt::DBus Qt::Widgets)

ecm_add_qml_module(islandplugin URI com.dv.island.private GENERATE_PLUGIN_SOURCE)
target_sources(islandplugin PRIVATE
    appmenumodel.cpp
    appmenumodel.h
    cavasource.cpp
    cavasource.h
    shelfhelper.cpp
    shelfhelper.h
)

target_link_libraries(islandplugin PRIVATE
    Qt::Core
    Qt::Gui
    Qt::Qml
    Qt::Quick
    Qt::Widgets
    Qt::DBus
    islanddbusmenuqt
)

ecm_finalize_qml_module(islandplugin)
