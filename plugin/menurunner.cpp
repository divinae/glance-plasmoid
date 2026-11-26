/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "menurunner.h"

#include "appmenumodel.h"

#include <QAction>
#include <QDBusConnection>
#include <QDBusVariant>
#include <QLoggingCategory>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QIcon>
#include <QTimer>

Q_LOGGING_CATEGORY(GLANCE_RUNNER, "com.dv.glance.runner", QtInfoMsg)

namespace
{
// Fewer letters than this match half of every menu: KRunner asks at each key
constexpr int MinQueryLength = 3;
constexpr int MaxMatches = 12;
// The first query of a session starts fetching the submenus; its answer waits this long at most
constexpr int FirstAnswerWaitMs = 400;
// KRunner closes and the app gets its focus back before the item runs (a dialog it opens lands
// on top)
constexpr int RunDelayMs = 150;
// KRunner::QueryMatch::CategoryRelevance::Moderate
constexpr int CategoryModerate = 50;
// The matches remembered for Run: KRunner ends the session (Teardown) before it asks to run one,
// so they outlive it; only the newest this many, as each key asks again
constexpr quint64 KeptTargets = 300;
}

QDBusArgument &operator<<(QDBusArgument &argument, const RunnerMatch &match)
{
    argument.beginStructure();
    argument << match.id << match.text << match.iconName << match.categoryRelevance << match.relevance << match.properties;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, RunnerMatch &match)
{
    argument.beginStructure();
    argument >> match.id >> match.text >> match.iconName >> match.categoryRelevance >> match.relevance >> match.properties;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const RunnerAction &action)
{
    argument.beginStructure();
    argument << action.id << action.text << action.iconName;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, RunnerAction &action)
{
    argument.beginStructure();
    argument >> action.id >> action.text >> action.iconName;
    argument.endStructure();
    return argument;
}

MenuRunner *MenuRunner::instance()
{
    static MenuRunner *runner = new MenuRunner();
    return runner;
}

MenuRunner::MenuRunner(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<RunnerMatch>();
    qDBusRegisterMetaType<RunnerMatches>();
    qDBusRegisterMetaType<RunnerAction>();
    qDBusRegisterMetaType<RunnerActions>();

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.registerObject(QStringLiteral("/Runner"), this, QDBusConnection::ExportAllSlots)) {
        return;
    }
    // The name is also CalendarBus's; whichever comes first takes it (asking again is a no-op).
    // Asked without waiting: plasmashell's GUI thread is loading the widget
    constexpr uint DoNotQueue = 4; // DBUS_NAME_FLAG_DO_NOT_QUEUE
    bus.interface()->asyncCall(QStringLiteral("RequestName"), QStringLiteral("com.dv.glance"), DoNotQueue);
}

void MenuRunner::addModel(AppMenuModel *model)
{
    removeModel(model);
    m_models.append(model);
}

void MenuRunner::removeModel(AppMenuModel *model)
{
    m_models.removeAll(model);
    m_models.removeAll(nullptr);
}

AppMenuModel *MenuRunner::model() const
{
    for (auto it = m_models.crbegin(); it != m_models.crend(); ++it) {
        AppMenuModel *m = it->data();
        if (m && m->enabled() && m->menuAvailable()) {
            return m;
        }
    }
    return nullptr;
}

RunnerActions MenuRunner::Actions()
{
    return {};
}

RunnerMatches MenuRunner::matches(AppMenuModel *model, const QString &query)
{
    RunnerMatches out;
    if (!model) {
        return out;
    }
    const QVariantList found = model->search(query, MaxMatches * 2);
    for (const QVariant &v : found) {
        const QVariantMap item = v.toMap();
        auto *action = item.value(QStringLiteral("action")).value<QAction *>();
        // Its id in the app's exported menu: what Run clicks
        const QVariant itemId = action ? action->property("_dbusmenu_id") : QVariant();
        if (!itemId.isValid() || !item.value(QStringLiteral("enabled")).toBool()) {
            continue;
        }
        const QString text = item.value(QStringLiteral("text")).toString();
        // Where it is, without its own name: "File › Export", and its shortcut
        QString where = item.value(QStringLiteral("path")).toString();
        const QString tail = QStringLiteral(" › ") + text;
        if (where.endsWith(tail)) {
            where.chop(tail.size());
        } else if (where == text) {
            where.clear();
        }
        const QString shortcut = item.value(QStringLiteral("shortcut")).toString();
        if (!shortcut.isEmpty()) {
            where = where.isEmpty() ? shortcut : where + QStringLiteral("  ·  ") + shortcut;
        }

        RunnerMatch match;
        match.id = QString::number(++m_nextId);
        match.text = text;
        match.iconName = action->icon().name().isEmpty() ? QStringLiteral("application-menu") : action->icon().name();
        match.categoryRelevance = CategoryModerate;
        // In the menus' order of fit (the item's own name first), a step apart
        match.relevance = qMax(0.1, 0.8 - out.size() * 0.02);
        match.properties = {
            {QStringLiteral("subtext"), where},
            {QStringLiteral("category"), QStringLiteral("Application Menu")},
            {QStringLiteral("actions"), QStringList()},
        };
        m_targets.insert(match.id, {model->loadedServiceName(), model->loadedObjectPath(), itemId.toInt(), text});
        if (m_nextId > KeptTargets) {
            m_targets.remove(QString::number(m_nextId - KeptTargets));
        }
        out.append(match);
        if (out.size() >= MaxMatches) {
            break;
        }
    }
    return out;
}

RunnerMatches MenuRunner::Match(const QString &query)
{
    const QString q = query.simplified();
    AppMenuModel *m = model();
    if (!m || q.size() < MinQueryLength) {
        return {};
    }
    if (m->prefetching()) {
        return matches(m, q);
    }
    // First query of the session: many apps fill a submenu only as it's asked for, so fetch
    // the tree, and when some of it had to be asked for, answer once the first of it has arrived
    // (or soon anyway); the next keys see more. The reply waits without blocking: KRunner may ask
    // again meanwhile
    m_prefetched = m;
    if (!m->prefetchAll() || !calledFromDBus()) {
        return matches(m, q);
    }
    setDelayedReply(true);
    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    // The timer is the connection's context: deleting it ends the wait for treeChanged too
    connect(m, &AppMenuModel::treeChanged, timer, [timer]() {
        timer->start(0);
    });
    connect(timer, &QTimer::timeout, this, [this, timer, request = message(), q, model = QPointer<AppMenuModel>(m)]() {
        QDBusConnection::sessionBus().send(request.createReply(QVariant::fromValue(matches(model, q))));
        timer->deleteLater();
    });
    timer->start(FirstAnswerWaitMs);
    return {};
}

void MenuRunner::Run(const QString &matchId, const QString &actionId)
{
    Q_UNUSED(actionId)
    if (!m_targets.contains(matchId)) {
        qCWarning(GLANCE_RUNNER) << "Run: no item for match" << matchId;
        return;
    }
    const Target target = m_targets.value(matchId);
    qCInfo(GLANCE_RUNNER) << "Run:" << target.text << "→" << target.service << target.path << "item" << target.itemId;
    // As the menu bar does when it's clicked (DBusMenuImporter::sendClickedEvent), straight to the
    // app: a moment later, once KRunner has closed and the app has its focus back
    QTimer::singleShot(RunDelayMs, this, [target]() {
        QDBusMessage event = QDBusMessage::createMethodCall(target.service, target.path, QStringLiteral("com.canonical.dbusmenu"),
                                                            QStringLiteral("Event"));
        event.setArguments({target.itemId, QStringLiteral("clicked"), QVariant::fromValue(QDBusVariant(QString())), 0u});
        QDBusConnection::sessionBus().asyncCall(event);
    });
}

void MenuRunner::Teardown()
{
    // Not the matches: Run comes after this
    if (m_prefetched) {
        m_prefetched->stopPrefetch();
        m_prefetched = nullptr;
    }
}

void MenuRunner::SetActivationToken(const QString &token)
{
    // The item runs in an app that already has a window: nothing to hand focus to
    Q_UNUSED(token)
}
