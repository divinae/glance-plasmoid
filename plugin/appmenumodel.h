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
#include <QQuickItem>
#include <qqmlregistration.h>

#include <memory>

class QAction;
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

    bool eventFilter(QObject *watched, QEvent *event) override;
    static void anchorToItem(QWindow *popup, QQuickItem *item);

Q_SIGNALS:
    void enabledChanged();
    void serviceNameChanged();
    void objectPathChanged();
    void menuAvailableChanged();
    void currentIndexChanged();
    void menuOpenChanged();
    void buttonGridChanged();
    void requestActivateIndex(int index);
    // An action was chosen from the menus (the drawer closes, as macOS's menu bar does)
    void actionTriggered();
    void modelNeedsUpdate();

private Q_SLOTS:
    void update();

private:
    void scheduleApplicationMenuUpdate();
    void updateApplicationMenu();
    void setMenuAvailable(bool available);
    void setCurrentIndex(int index);
    void onMenuAboutToHide();
    QMenu *menuForIndex(int idx) const;

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
    QPointer<QMenu> m_sourceMenu;
    QPointer<QQuickItem> m_buttonGrid;
    // The button the shown menu belongs to, and where it opened: to open or resize it once the
    // application sends its contents
    QPointer<QQuickItem> m_menuCtx;
    QPoint m_menuPos;
};
