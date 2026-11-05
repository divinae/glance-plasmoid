/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2016 Chinmoy Ranjan Pradhan <chinmoyrp65@gmail.com>
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

    Port of plasma-workspace applets/appmenu (AppMenuModel + AppMenuApplet::trigger).
    The service name and object path come from QML (TasksModel roles
    ApplicationMenuServiceName / ApplicationMenuObjectPath) instead of an
    internal TasksModel.
*/

#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QSet>
#include <QVariantList>
#include <QQuickItem>
#include <QTimer>
#include <qqmlregistration.h>

#include <memory>

class QDBusServiceWatcher;
class QMenu;
class QWindow;
class KDBusMenuImporter;

class AppMenuModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    // While enabled, owns org.kde.kappmenuview so applications export their menus
    // (and hide their in-window menu bars). Disabled: no menu is loaded.
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString serviceName READ serviceName WRITE setServiceName NOTIFY serviceNameChanged)
    Q_PROPERTY(QString objectPath READ objectPath WRITE setObjectPath NOTIFY objectPathChanged)
    Q_PROPERTY(bool menuAvailable READ menuAvailable NOTIFY menuAvailableChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(bool menuOpen READ menuOpen NOTIFY menuOpenChanged)
    // Item whose children carry a "buttonIndex" property; used to switch menus on hover
    Q_PROPERTY(QQuickItem *buttonGrid READ buttonGrid WRITE setButtonGrid NOTIFY buttonGridChanged)

public:
    enum AppMenuRole {
        MenuRole = Qt::UserRole + 1,
        ActionRole,
    };
    Q_ENUM(AppMenuRole)

    explicit AppMenuModel(QObject *parent = nullptr);
    ~AppMenuModel() override;

    QVariant data(const QModelIndex &index, int role) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool enabled() const;
    void setEnabled(bool enabled);

    QString serviceName() const;
    void setServiceName(const QString &serviceName);
    QString objectPath() const;
    void setObjectPath(const QString &objectPath);

    bool menuAvailable() const;
    int currentIndex() const;
    bool menuOpen() const;

    QQuickItem *buttonGrid() const;
    void setButtonGrid(QQuickItem *item);

    Q_INVOKABLE void trigger(QQuickItem *ctx, int idx);
    Q_INVOKABLE void closeMenu();

    // Fetches the whole tree, not only the menus on the bar: many apps fill a submenu only as it
    // opens, so searching needs it asked for first (it arrives over a moment)
    Q_INVOKABLE void prefetchAll();
    // The search closed: no more fetching as submenus arrive
    Q_INVOKABLE void stopPrefetch();
    // The items whose path ("File › Export › PNG…") has every word of `text`, at most `limit`:
    // [{action, text, path, shortcut, enabled, checkable, checked}]. `action` is the QAction:
    // trigger() on it clicks it in the app
    Q_INVOKABLE QVariantList search(const QString &text, int limit = 40) const;
    // About, Settings and Quit as the app's own menus have them (macOS's app menu), in that
    // order, those found: [{kind: "about"|"settings"|"quit", action, text}]
    // `appName`: the app's own ("About Konsole" over "About KDE")
    Q_INVOKABLE QVariantList appActions(const QString &appName = QString()) const;

    bool eventFilter(QObject *watched, QEvent *event) override;

Q_SIGNALS:
    void enabledChanged();
    void serviceNameChanged();
    void objectPathChanged();
    void menuAvailableChanged();
    void currentIndexChanged();
    void menuOpenChanged();
    void buttonGridChanged();
    void requestActivateIndex(int index);
    // More of the tree has arrived (prefetchAll): a search can run again
    void treeChanged();
    // An action was chosen from the menus (the drawer closes, as macOS's menu bar does)
    void actionTriggered();
    void modelNeedsUpdate();

private:
    void update();
    void scheduleApplicationMenuUpdate();
    void updateApplicationMenu();
    void setMenuAvailable(bool available);
    void setCurrentIndex(int index);
    void onMenuAboutToHide();
    void deleteDetachedMenus();
    QMenu *menuForIndex(int idx) const;
    // Stops listening to the shown menu and hides it, silently
    void releaseCurrentMenu();
    static void anchorToItem(QWindow *popup, QQuickItem *item);
    int buttonAt(const QPointF &globalPos) const;

    bool m_enabled = true;
    bool m_holdsViewService = false;
    QString m_serviceName;
    QString m_objectPath;
    QString m_loadedServiceName;
    QString m_loadedObjectPath;
    bool m_menuAvailable = false;
    bool m_updatePending = false;
    bool m_appMenuUpdatePending = false;
    int m_currentIndex = -1;

    QDBusServiceWatcher *m_serviceWatcher;
    std::unique_ptr<KDBusMenuImporter> m_importer;
    QPointer<QMenu> m_menu;

    QPointer<QMenu> m_currentMenu;
    QPointer<QQuickItem> m_buttonGrid;
    // Closing one menu to open another: its aboutToHide isn't the menus closing
    bool m_switching = false;
    // Menus taken from their parent widget to show (see trigger()): deleted with the importer
    QList<QPointer<QMenu>> m_detachedMenus;
    // The submenus asked for by prefetchAll(), and whether new ones are fetched as they come
    QSet<QMenu *> m_prefetched;
    bool m_prefetching = false;
    QMetaObject::Connection m_prefetchConnection;
    // `deep`: into the submenus already fetched as well (a new search, once); not as each arrives
    void prefetchChildren(QMenu *menu, bool deep = false, int depth = 0);
    // An item of the tree, its name and path ("File › Export") as shown and lowercased
    struct Found {
        QPointer<QAction> action;
        QString text;
        QString path;
        QString textLower;
        QString pathLower;
    };
    void collect(QMenu *menu, const QString &path, QList<Found> &out, int depth) const;
    // The tree flattened, kept until the menus change
    const QList<Found> &flat() const;
    mutable QList<Found> m_flat;
    // treeChanged once a burst of submenus has arrived
    QTimer m_treeChangedTimer;
    // Switching menus by pointing waits a moment on the button (eventFilter)
    QTimer m_hoverTimer;
    int m_hoverIndex = -1;
};
