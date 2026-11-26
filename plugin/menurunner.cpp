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
#include <QKeySequence>
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
    // The name is also CalendarBus's; whichever comes first takes it (asking again is a no-op)
    bus.interface()->registerService(QStringLiteral("com.dv.glance"), QDBusConnectionInterface::DontQueueService);
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
        if (!action || !item.value(QStringLiteral("enabled")).toBool()) {
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
        const QVariant itemId = action->property("_dbusmenu_id");
        if (!itemId.isValid()) {
            continue;
        }
        m_targets.insert(match.id, {model->loadedServiceName(), model->loadedObjectPath(), itemId.toInt(), text});
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
    // the tree and answer once the first of it has arrived (or soon anyway); the next keys see
    // more. The reply waits without blocking: KRunner may ask again meanwhile
    m->prefetchAll();
    m_prefetched = m;
    if (!calledFromDBus()) {
        return matches(m, q);
    }
    setDelayedReply(true);
    const QDBusMessage request = message();
    auto *done = new bool(false);
    auto answer = [this, request, q, done, model = QPointer<AppMenuModel>(m)]() {
        if (*done) {
            return;
        }
        *done = true;
        QDBusConnection::sessionBus().send(request.createReply(QVariant::fromValue(matches(model, q))));
    };
    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(FirstAnswerWaitMs);
    const auto connection = connect(m, &AppMenuModel::treeChanged, timer, [timer]() {
        timer->setInterval(0);
        timer->start();
    });
    connect(timer, &QTimer::timeout, this, [answer, timer, connection, done]() {
        answer();
        disconnect(connection);
        timer->deleteLater();
        delete done;
    });
    timer->start();
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
    m_targets.clear();
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
