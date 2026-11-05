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
#include <QGuiApplication>
#include <QIcon>
#include <QKeyEvent>
#include <QMenu>
#include <QMouseEvent>
#include <QQuickWindow>
#include <QRegularExpression>

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
    m_hoverTimer.setSingleShot(true);
    m_hoverTimer.setInterval(120);
    connect(&m_hoverTimer, &QTimer::timeout, this, [this] {
        if (m_hoverIndex >= 0 && m_hoverIndex != m_currentIndex && m_currentIndex >= 0) {
            Q_EMIT requestActivateIndex(m_hoverIndex);
        }
    });
    acquireViewService();
    m_holdsViewService = true;

    connect(this, &AppMenuModel::modelNeedsUpdate, this, [this] {
        if (!m_updatePending) {
            m_updatePending = true;
            QMetaObject::invokeMethod(this, &AppMenuModel::update, Qt::QueuedConnection);
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
    // Without telling us (aboutToHide, currentIndex) while we go
    releaseCurrentMenu();
    deleteDetachedMenus();
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

    // The shown menu belongs to the old importer, which goes now, with the menus detached from it
    closeMenu();
    releaseCurrentMenu();
    m_importer.reset();
    m_prefetched.clear();
    m_prefetching = false;
    deleteDetachedMenus();

    if (serviceName.isEmpty() || menuObjectPath.isEmpty()) {
        setMenuAvailable(false);
        m_loadedServiceName.clear();
        m_loadedObjectPath.clear();
        m_serviceWatcher->setWatchedServices({});
        m_menu.clear();
        Q_EMIT modelNeedsUpdate();
        return;
    }

    m_loadedServiceName = serviceName;
    m_loadedObjectPath = menuObjectPath;
    m_serviceWatcher->setWatchedServices(QStringList({serviceName}));

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

// ---- the whole tree: prefetching, search, the app's own About/Settings/Quit ----------------

static QString plainText(const QAction *action)
{
    QString text = action->text();
    text.remove(QRegularExpression(QStringLiteral("&(?!&)")));
    return text.replace(QStringLiteral("&&"), QStringLiteral("&")).trimmed();
}

void AppMenuModel::prefetchChildren(QMenu *menu, int depth)
{
    if (!menu || !m_importer || depth > 5 || m_prefetched.size() > 400) {
        return;
    }
    const auto actions = menu->actions();
    for (QAction *a : actions) {
        QMenu *sub = a->menu();
        if (sub && !m_prefetched.contains(sub)) {
            m_prefetched.insert(sub);
            m_importer->updateMenu(sub);
        }
        if (sub) {
            prefetchChildren(sub, depth + 1);
        }
    }
}

void AppMenuModel::prefetchAll()
{
    if (!m_importer || !m_menu || m_prefetching) {
        return;
    }
    m_prefetching = true;
    // Each submenu as it arrives: its own submenus next
    connect(m_importer.get(), &DBusMenuImporter::menuUpdated, this, [this](QMenu *menu) {
        if (m_prefetching && menu != m_menu) {
            prefetchChildren(menu, 1);
        }
    });
    prefetchChildren(m_menu, 0);
}

void AppMenuModel::collect(QMenu *menu, const QString &path, QList<Found> &out, int depth) const
{
    if (!menu || depth > 6) {
        return;
    }
    const auto actions = menu->actions();
    for (QAction *a : actions) {
        if (a->isSeparator() || !a->isVisible()) {
            continue;
        }
        const QString text = plainText(a);
        if (text.isEmpty()) {
            continue;
        }
        const QString here = path.isEmpty() ? text : path + QStringLiteral(" › ") + text;
        if (a->menu()) {
            collect(a->menu(), here, out, depth + 1);
        } else {
            out.append({a, here});
        }
    }
}

QVariantList AppMenuModel::search(const QString &text, int limit) const
{
    QVariantList result;
    const QStringList words = text.simplified().toLower().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (!m_menuAvailable || !m_menu || words.isEmpty()) {
        return result;
    }
    QList<Found> all;
    collect(m_menu, QString(), all, 0);
    // The item's own name matching first, then its path's
    QList<Found> first;
    QList<Found> second;
    for (const Found &f : std::as_const(all)) {
        const QString path = f.path.toLower();
        if (!std::ranges::all_of(words, [&](const QString &w) { return path.contains(w); })) {
            continue;
        }
        const QString name = plainText(f.action).toLower();
        (std::ranges::any_of(words, [&](const QString &w) { return name.contains(w); }) ? first : second).append(f);
    }
    first.append(second);
    for (const Found &f : std::as_const(first)) {
        if (result.size() >= limit) {
            break;
        }
        result.append(QVariantMap{
            {QStringLiteral("action"), QVariant::fromValue(f.action)},
            {QStringLiteral("text"), plainText(f.action)},
            {QStringLiteral("path"), f.path},
            {QStringLiteral("shortcut"), f.action->shortcut().toString(QKeySequence::NativeText)},
            {QStringLiteral("enabled"), f.action->isEnabled()},
            {QStringLiteral("checkable"), f.action->isCheckable()},
            {QStringLiteral("checked"), f.action->isChecked()},
        });
    }
    return result;
}

QVariantList AppMenuModel::appActions(const QString &appName) const
{
    QVariantList result;
    if (!m_menuAvailable || !m_menu) {
        return result;
    }
    QList<Found> all;
    collect(m_menu, QString(), all, 0);
    // Best match per kind: a name that starts with the word beats one that only has it
    struct Kind {
        QString id;
        QStringList words;
    };
    const QList<Kind> kinds = {
        {QStringLiteral("about"), {QStringLiteral("about")}},
        {QStringLiteral("settings"), {QStringLiteral("preferences"), QStringLiteral("settings"), QStringLiteral("configure"), QStringLiteral("options")}},
        // Some apps only close their window ("Close Window" in Konsole)
        {QStringLiteral("quit"), {QStringLiteral("quit"), QStringLiteral("exit"), QStringLiteral("close window")}},
    };
    for (const Kind &kind : kinds) {
        QAction *best = nullptr;
        int bestScore = 0;
        for (const Found &f : std::as_const(all)) {
            if (!f.action->isEnabled()) {
                continue;
            }
            const QString name = plainText(f.action).toLower();
            int score = 0;
            for (int i = 0; i < kind.words.size(); ++i) {
                const QString &w = kind.words.at(i);
                // Earlier words are the likelier ones ("Preferences" over "Options")
                const int weight = kind.words.size() - i;
                if (name.startsWith(w)) {
                    score = std::max(score, 20 + weight);
                } else if (name.contains(w)) {
                    score = std::max(score, 10 + weight);
                }
            }
            // The app's own name in it: its own ("About Konsole", "Configure Konsole…"); the
            // toolkit's About ("About KDE", "About Qt") last. Else the shorter, the likelier
            // ("Configure Keyboard Shortcuts…" isn't the app's settings)
            if (score > 0) {
                const QString app = appName.toLower();
                if (!app.isEmpty() && name.contains(app)) {
                    score += 30;
                } else if (name.contains(QLatin1String("kde")) || name.contains(QLatin1String(" qt"))) {
                    score -= 5;
                }
                score = score * 100 - name.size();
            }
            if (score > bestScore) {
                bestScore = score;
                best = f.action;
            }
        }
        if (best) {
            result.append(QVariantMap{
                {QStringLiteral("kind"), kind.id},
                {QStringLiteral("action"), QVariant::fromValue(best)},
                {QStringLiteral("text"), plainText(best)},
            });
        }
    }
    return result;
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

void AppMenuModel::deleteDetachedMenus()
{
    for (const QPointer<QMenu> &menu : std::as_const(m_detachedMenus)) {
        if (menu) {
            menu->deleteLater();
        }
    }
    m_detachedMenus.clear();
}

void AppMenuModel::onMenuAboutToHide()
{
    // Not while switching to another menu: that one is current already
    if (m_switching || sender() != m_currentMenu) {
        return;
    }
    setCurrentIndex(-1);
}

void AppMenuModel::releaseCurrentMenu()
{
    if (m_currentMenu) {
        m_currentMenu->removeEventFilter(this);
        disconnect(m_currentMenu, nullptr, this, nullptr);
        m_currentMenu->hide();
        m_currentMenu.clear();
    }
}

void AppMenuModel::closeMenu()
{
    if (m_currentMenu && m_currentMenu->isVisible()) {
        m_currentMenu->hide();
    }
}

void AppMenuModel::trigger(QQuickItem *ctx, int idx)
{
    // The same menu already on show: nothing to do
    if (m_currentIndex == idx && m_currentMenu && m_currentMenu->isVisible()) {
        return;
    }
    if (!ctx || !ctx->window()) {
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
        if (ctx->window() && ctx->window()->mouseGrabberItem()) {
            ctx->window()->mouseGrabberItem()->ungrabMouse();
        }
    };

    // The application's own menu is shown, as Plasma's Global Menu does: showing it asks the
    // application for its contents (aboutToShow), which arrive lazily over D-Bus. Moving to
    // another one closes this one and opens that.
    if (m_currentMenu && m_currentMenu != actionMenu && m_currentMenu->isVisible()) {
        m_switching = true;
        m_currentMenu->hide();
        m_switching = false;
    }
    if (m_currentMenu && m_currentMenu != actionMenu) {
        m_currentMenu->removeEventFilter(this);
    }
    // No parent widget while it's ours to show: Qt makes a popup's parent widget's window its
    // parent when it shows, here the application's root menu's, never on screen, overriding the
    // drawer set below, and the compositor then dismisses it. Glance deletes these itself.
    if (actionMenu->parentWidget()) {
        actionMenu->setParent(nullptr, actionMenu->windowFlags());
        m_detachedMenus.append(actionMenu);
    }
    m_currentMenu = actionMenu;
    connect(actionMenu, &QMenu::aboutToHide, this, &AppMenuModel::onMenuAboutToHide, Qt::UniqueConnection);
    // Also fires for actions in its submenus
    connect(actionMenu, &QMenu::triggered, this, &AppMenuModel::actionTriggered, Qt::UniqueConnection);
    actionMenu->removeEventFilter(this);
    actionMenu->installEventFilter(this);

    QTimer::singleShot(0, ctx, ungrabMouseHack);

    actionMenu->winId(); // create window handle
    actionMenu->windowHandle()->setTransientParent(ctx->window());
    anchorToItem(actionMenu->windowHandle(), ctx);
    // Under the button; QMenu keeps it on the screen. On Wayland the anchor above places it.
    actionMenu->popup(ctx->window()->mapToGlobal(ctx->mapToScene(QPointF(0, ctx->height()))).toPoint());

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

// The bar's button under a point of the open menu, or -1: only buttons with a menu, so the
// pointer never sets off a plain action
int AppMenuModel::buttonAt(const QPointF &globalPos) const
{
    if (!m_buttonGrid || !m_buttonGrid->window()) {
        return -1;
    }
    const QPointF windowLocalPos = m_buttonGrid->window()->mapFromGlobal(globalPos);
    const QPointF gridLocalPos = m_buttonGrid->mapFromScene(windowLocalPos);
    QQuickItem *item = m_buttonGrid->childAt(gridLocalPos.x(), gridLocalPos.y());
    if (!item) {
        return -1;
    }
    bool ok = false;
    const int index = item->property("buttonIndex").toInt(&ok);
    return ok && menuForIndex(index) ? index : -1;
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
    } else if (event->type() == QEvent::MouseMove) {
        // While a menu is open it gets all the pointer's events, the bar's buttons none: moving
        // onto another one switches to its menu here
        auto *e = static_cast<QMouseEvent *>(event);
        if (menu->rect().contains(e->position().toPoint())) {
            return false;
        }
        // After a short dwell, so sweeping across the bar doesn't open every menu on the way
        const int index = buttonAt(e->globalPosition());
        if (index >= 0 && index != m_currentIndex) {
            if (index != m_hoverIndex || !m_hoverTimer.isActive()) {
                m_hoverIndex = index;
                m_hoverTimer.start();
            }
        } else {
            m_hoverTimer.stop();
        }
    } else if (event->type() == QEvent::MouseButtonPress) {
        // A click on another button switches at once, instead of only closing this menu (Qt
        // swallows the click that closes a popup)
        auto *e = static_cast<QMouseEvent *>(event);
        if (menu->rect().contains(e->position().toPoint())) {
            return false;
        }
        const int index = buttonAt(e->globalPosition());
        if (index >= 0 && index != m_currentIndex) {
            m_hoverTimer.stop();
            Q_EMIT requestActivateIndex(index);
            return true;
        }
    }
    return false;
}

#include "moc_appmenumodel.cpp"
