/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2016 Chinmoy Ranjan Pradhan <chinmoyrp65@gmail.com>
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "appmenumodel.h"

#include <QAction>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusServiceWatcher>
#include <QIcon>
#include <QKeyEvent>
#include <QGuiApplication>
#include <QMenu>
#include <QWindow>
#include <QMouseEvent>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>

#include <algorithm>

#include <dbusmenuimporter.h>

namespace
{
// Applications (via plasma-integration and the kded appmenu module) only export their
// menus over DBus while some process owns this name, as the stock appmenu applet does.
const QString s_viewService = QStringLiteral("org.kde.kappmenuview");
int s_viewServiceRefs = 0;

void acquireViewService()
{
    if (++s_viewServiceRefs == 1) {
        QDBusConnection::sessionBus().interface()->registerService(s_viewService,
                                                                   QDBusConnectionInterface::QueueService,
                                                                   QDBusConnectionInterface::DontAllowReplacement);
    }
}

void releaseViewService()
{
    if (--s_viewServiceRefs == 0) {
        QDBusConnection::sessionBus().interface()->unregisterService(s_viewService);
    }
}
}

class KDBusMenuImporter : public DBusMenuImporter
{
public:
    KDBusMenuImporter(const QString &service, const QString &path)
        : DBusMenuImporter(service, path)
    {
    }

protected:
    QIcon iconForName(const QString &name) override
    {
        return QIcon::fromTheme(name);
    }
};

AppMenuModel::AppMenuModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_serviceWatcher(new QDBusServiceWatcher(this))
{
    acquireViewService();
    m_holdsViewService = true;

    connect(this, &AppMenuModel::modelNeedsUpdate, this, [this] {
        if (!m_updatePending) {
            m_updatePending = true;
            QMetaObject::invokeMethod(this, "update", Qt::QueuedConnection);
        }
    });

    m_serviceWatcher->setConnection(QDBusConnection::sessionBus());
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &serviceName) {
        if (serviceName == m_loadedServiceName) {
            setMenuAvailable(false);
            Q_EMIT modelNeedsUpdate();
        }
    });
}

AppMenuModel::~AppMenuModel()
{
    if (m_currentMenu) {
        m_currentMenu->removeEventFilter(this);
        m_currentMenu->hide();
        delete m_currentMenu;
    }
    if (m_holdsViewService) {
        releaseViewService();
    }
}

bool AppMenuModel::enabled() const
{
    return m_enabled;
}

void AppMenuModel::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    if (m_enabled && !m_holdsViewService) {
        acquireViewService();
        m_holdsViewService = true;
    } else if (!m_enabled && m_holdsViewService) {
        releaseViewService();
        m_holdsViewService = false;
    }
    Q_EMIT enabledChanged();
    scheduleApplicationMenuUpdate();
}

QString AppMenuModel::serviceName() const
{
    return m_serviceName;
}

void AppMenuModel::setServiceName(const QString &serviceName)
{
    if (m_serviceName == serviceName) {
        return;
    }
    m_serviceName = serviceName;
    Q_EMIT serviceNameChanged();
    scheduleApplicationMenuUpdate();
}

QString AppMenuModel::objectPath() const
{
    return m_objectPath;
}

void AppMenuModel::setObjectPath(const QString &objectPath)
{
    if (m_objectPath == objectPath) {
        return;
    }
    m_objectPath = objectPath;
    Q_EMIT objectPathChanged();
    scheduleApplicationMenuUpdate();
}

// Both properties usually change together from QML; coalesce into one reload.
void AppMenuModel::scheduleApplicationMenuUpdate()
{
    if (m_appMenuUpdatePending) {
        return;
    }
    m_appMenuUpdatePending = true;
    QTimer::singleShot(0, this, [this] {
        m_appMenuUpdatePending = false;
        updateApplicationMenu();
    });
}

bool AppMenuModel::menuAvailable() const
{
    return m_menuAvailable;
}

void AppMenuModel::setMenuAvailable(bool available)
{
    if (m_menuAvailable != available) {
        m_menuAvailable = available;
        Q_EMIT menuAvailableChanged();
    }
}

int AppMenuModel::currentIndex() const
{
    return m_currentIndex;
}

void AppMenuModel::setCurrentIndex(int index)
{
    if (m_currentIndex != index) {
        const bool wasOpen = menuOpen();
        m_currentIndex = index;
        Q_EMIT currentIndexChanged();
        if (wasOpen != menuOpen()) {
            Q_EMIT menuOpenChanged();
        }
    }
}

bool AppMenuModel::menuOpen() const
{
    return m_currentIndex >= 0;
}

QQuickItem *AppMenuModel::buttonGrid() const
{
    return m_buttonGrid;
}

void AppMenuModel::setButtonGrid(QQuickItem *item)
{
    if (m_buttonGrid != item) {
        m_buttonGrid = item;
        Q_EMIT buttonGridChanged();
    }
}

int AppMenuModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid() || !m_menuAvailable || !m_menu) {
        return 0;
    }
    return m_menu->actions().count();
}

QHash<int, QByteArray> AppMenuModel::roleNames() const
{
    return {
        {MenuRole, QByteArrayLiteral("activeMenu")},
        {ActionRole, QByteArrayLiteral("activeActions")},
    };
}

QVariant AppMenuModel::data(const QModelIndex &index, int role) const
{
    if (!m_menuAvailable || !m_menu || !index.isValid()) {
        return {};
    }

    const auto actions = m_menu->actions();
    const int row = index.row();
    if (row < 0 || row >= actions.count()) {
        return {};
    }

    if (role == MenuRole || role == Qt::DisplayRole) {
        return actions.at(row)->text();
    } else if (role == ActionRole) {
        return QVariant::fromValue(actions.at(row));
    }
    return {};
}

void AppMenuModel::update()
{
    beginResetModel();
    endResetModel();
    m_updatePending = false;
}

void AppMenuModel::updateApplicationMenu()
{
    const QString serviceName = m_enabled ? m_serviceName : QString();
    const QString menuObjectPath = m_enabled ? m_objectPath : QString();

    if (m_loadedServiceName == serviceName && m_loadedObjectPath == menuObjectPath) {
        if (m_importer) {
            QMetaObject::invokeMethod(m_importer.get(), "updateMenu", Qt::QueuedConnection);
        }
        return;
    }

    closeMenu();

    if (serviceName.isEmpty() || menuObjectPath.isEmpty()) {
        setMenuAvailable(false);
        m_loadedServiceName.clear();
        m_loadedObjectPath.clear();
        m_serviceWatcher->setWatchedServices({});
        m_importer.reset();
        m_menu.clear();
        Q_EMIT modelNeedsUpdate();
        return;
    }

    m_loadedServiceName = serviceName;
    m_loadedObjectPath = menuObjectPath;
    m_serviceWatcher->setWatchedServices(QStringList({serviceName}));

    // The shared popup holds the old menu's actions while open: give them back and start afresh
    if (m_currentMenu) {
        m_currentMenu->hide();
        m_currentMenu->deleteLater();
        m_currentMenu.clear();
    }
    m_sourceMenu.clear();
    m_importer = std::make_unique<KDBusMenuImporter>(serviceName, menuObjectPath);
    QMetaObject::invokeMethod(m_importer.get(), "updateMenu", Qt::QueuedConnection);

    connect(m_importer.get(), &DBusMenuImporter::menuUpdated, this, [this](QMenu *menu) {
        m_menu = m_importer->menu();
        if (m_menu.isNull() || menu != m_menu) {
            return;
        }

        if (m_menu->isEmpty()) {
            // apps may pretend to have a menu but then don't give us one
            setMenuAvailable(false);
            Q_EMIT modelNeedsUpdate();
            return;
        }

        // cache first layer of sub menus, which we'll be popping up
        const auto actions = m_menu->actions();
        for (QAction *a : actions) {
            // A lambda can't be a unique connection: drop an earlier one instead
            disconnect(a, &QAction::changed, this, nullptr);
            connect(a, &QAction::changed, this, [this, a] {
                if (m_menuAvailable && m_menu) {
                    const int actionIdx = m_menu->actions().indexOf(a);
                    if (actionIdx > -1) {
                        const QModelIndex modelIdx = index(actionIdx, 0);
                        Q_EMIT dataChanged(modelIdx, modelIdx);
                    }
                }
            });
            connect(a, &QAction::destroyed, this, &AppMenuModel::modelNeedsUpdate, Qt::UniqueConnection);

            if (a->menu()) {
                m_importer->updateMenu(a->menu());
            }
        }

        setMenuAvailable(true);
        Q_EMIT modelNeedsUpdate();
    });

    connect(m_importer.get(), &DBusMenuImporter::actionActivationRequested, this, [this](QAction *action) {
        if (!m_menuAvailable || !m_menu) {
            return;
        }
        const auto actions = m_menu->actions();
        auto it = std::ranges::find(actions, action);
        if (it != actions.end()) {
            Q_EMIT requestActivateIndex(it - actions.begin());
        }
    });

    Q_EMIT modelNeedsUpdate();
}

QMenu *AppMenuModel::menuForIndex(int idx) const
{
    if (!m_menuAvailable || !m_menu) {
        return nullptr;
    }
    const auto actions = m_menu->actions();
    if (idx < 0 || idx >= actions.count()) {
        return nullptr;
    }
    return actions.at(idx)->menu();
}

void AppMenuModel::onMenuAboutToHide()
{
    setCurrentIndex(-1);
    // Give the actions back to the importer's menu once the triggered action (if any)
    // has been activated; QMenu hides before it activates the chosen action.
    QTimer::singleShot(0, this, [this] {
        if (!m_currentMenu || !m_sourceMenu || m_currentMenu->isVisible()) {
            return;
        }
        const auto actions = m_currentMenu->actions();
        for (QAction *action : actions) {
            m_currentMenu->removeAction(action);
            m_sourceMenu->addAction(action);
        }
        m_sourceMenu->menuAction()->setMenu(m_sourceMenu);
        m_sourceMenu.clear();
    });
}

void AppMenuModel::closeMenu()
{
    if (m_currentMenu && m_currentMenu->isVisible()) {
        m_currentMenu->hide();
    }
}

void AppMenuModel::trigger(QQuickItem *ctx, int idx)
{
    if (m_currentIndex == idx) {
        return;
    }
    if (!ctx || !ctx->window() || !ctx->window()->screen()) {
        return;
    }

    QMenu *actionMenu = menuForIndex(idx);
    if (!actionMenu) {
        // plain action without a submenu
        if (m_menu && idx >= 0 && idx < m_menu->actions().count()) {
            closeMenu();
            m_menu->actions().at(idx)->trigger();
            Q_EMIT actionTriggered();
        }
        return;
    }

    // QTBUG-59044: Qt may miss the mouse release when a non-focus window spawns a grabbing popup
    auto ungrabMouseHack = [ctx]() {
        if (ctx && ctx->window() && ctx->window()->mouseGrabberItem()) {
            ctx->window()->mouseGrabberItem()->ungrabMouse();
        }
    };

    // One persistent QMenu that adopts the actions of whichever top-level menu is shown,
    // so switching menus while open only moves it instead of re-opening.
    if (!m_currentMenu) {
        // No parent widget: Qt would then make that widget's (hidden) window the popup's parent
        // when it shows, overriding the transient parent set below, and on Wayland the compositor
        // dismisses a popup whose parent isn't on screen
        m_currentMenu = new QMenu();
        connect(m_currentMenu, &QMenu::aboutToHide, this, &AppMenuModel::onMenuAboutToHide, Qt::UniqueConnection);
        // Also fires for actions in its submenus
        connect(m_currentMenu, &QMenu::triggered, this, &AppMenuModel::actionTriggered);
    } else if (m_sourceMenu && m_sourceMenu != actionMenu) {
        const auto actions = m_currentMenu->actions();
        for (QAction *action : actions) {
            m_currentMenu->removeAction(action);
            m_sourceMenu->addAction(action);
        }
        m_sourceMenu->menuAction()->setMenu(m_sourceMenu);
    }
    m_sourceMenu = actionMenu;
    const auto sourceActions = m_sourceMenu->actions();
    for (QAction *action : sourceActions) {
        m_sourceMenu->removeAction(action);
        m_currentMenu->addAction(action);
    }
    m_sourceMenu->menuAction()->setMenu(m_currentMenu);

    QTimer::singleShot(0, ctx, ungrabMouseHack);

    const QRect geo = ctx->window()->screen()->availableVirtualGeometry();
    QPoint pos = ctx->window()->mapToGlobal(ctx->mapToScene(QPointF(0, ctx->height())).toPoint());

    m_currentMenu->adjustSize();
    pos = QPoint(qBound(geo.x(), pos.x(), geo.x() + geo.width() - m_currentMenu->width()),
                 qBound(geo.y(), pos.y(), geo.y() + geo.height() - m_currentMenu->height()));

    // Switching to another menu while one is open (hovering along the bar) moves the open one:
    // QtWayland repositions the popup (xdg_popup.reposition) from the new anchor. Closing it and
    // opening another instead needs a new grab, which the compositor refuses without a fresh
    // click: the menu then vanished when moving along the bar quickly.
    const bool sameParent = m_currentMenu->isVisible() && m_currentMenu->windowHandle()
        && m_currentMenu->windowHandle()->transientParent() == ctx->window();
    if (m_currentMenu->isVisible() && !sameParent) {
        m_currentMenu->hide();
    }
    if (!m_currentMenu->isVisible()) {
        m_currentMenu->installEventFilter(this);
        m_currentMenu->winId(); // create window handle
        m_currentMenu->windowHandle()->setTransientParent(ctx->window());
    }
    anchorToItem(m_currentMenu->windowHandle(), ctx);
    if (m_currentMenu->isVisible()) {
        m_currentMenu->move(pos);
    } else {
        m_currentMenu->popup(pos);
    }

    setCurrentIndex(idx);
}

// On Wayland a popup is placed relative to its parent surface, from global coordinates Qt
// only knows for windows the shell told it about: not for a layer-shell surface such as the
// drawer, whose menus then landed anywhere. QtWayland takes the placement from these window
// properties instead: under the button, growing down and right, flipped up or slid along when
// it doesn't fit.
void AppMenuModel::anchorToItem(QWindow *popup, QQuickItem *item)
{
    if (!popup || !item || !QGuiApplication::platformName().startsWith(QLatin1String("wayland"))) {
        return;
    }
    const QRect anchor = item->mapRectToScene(QRectF(0, 0, item->width(), item->height())).toAlignedRect();
    popup->setProperty("_q_waylandPopupAnchorRect", anchor);
    popup->setProperty("_q_waylandPopupAnchor", QVariant::fromValue(Qt::Edges(Qt::BottomEdge | Qt::LeftEdge)));
    popup->setProperty("_q_waylandPopupGravity", QVariant::fromValue(Qt::Edges(Qt::BottomEdge | Qt::RightEdge)));
    // xdg_positioner: slide_x 1, slide_y 2, flip_x 4, flip_y 8
    popup->setProperty("_q_waylandPopupConstraintAdjustment", 1 | 2 | 8);
}

bool AppMenuModel::eventFilter(QObject *watched, QEvent *event)
{
    auto *menu = qobject_cast<QMenu *>(watched);
    if (!menu) {
        return false;
    }

    if (event->type() == QEvent::KeyPress) {
        auto *e = static_cast<QKeyEvent *>(event);
        if (e->key() == Qt::Key_Left) {
            Q_EMIT requestActivateIndex(m_currentIndex - 1);
            return true;
        } else if (e->key() == Qt::Key_Right) {
            if (menu->activeAction() && menu->activeAction()->menu()) {
                return false;
            }
            Q_EMIT requestActivateIndex(m_currentIndex + 1);
            return true;
        }
    } else if (event->type() == QEvent::MouseMove && !QGuiApplication::platformName().startsWith(QLatin1String("wayland"))) {
        // X11 only: there the open menu grabs the pointer, so hovering along the bar arrives here.
        // On Wayland the bar's buttons get the hover themselves, and global coordinates don't
        // match between the popup and a layer-shell window: the button found here was a wrong
        // one, and a plain action under it closed the menu.
        auto *e = static_cast<QMouseEvent *>(event);
        if (!m_buttonGrid || !m_buttonGrid->window()) {
            return false;
        }
        const QPointF windowLocalPos = m_buttonGrid->window()->mapFromGlobal(e->globalPosition());
        const QPointF gridLocalPos = m_buttonGrid->mapFromScene(windowLocalPos);
        auto *item = m_buttonGrid->childAt(gridLocalPos.x(), gridLocalPos.y());
        if (!item) {
            return false;
        }
        bool ok = false;
        const int buttonIndex = item->property("buttonIndex").toInt(&ok);
        if (ok) {
            Q_EMIT requestActivateIndex(buttonIndex);
        }
    }
    return false;
}

#include "moc_appmenumodel.cpp"
