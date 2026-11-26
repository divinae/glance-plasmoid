/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QDBusArgument>
#include <QDBusContext>
#include <QHash>
#include <QList>
#include <QMetaType>
#include <QObject>
#include <QPointer>
#include <QVariantMap>

class AppMenuModel;
class QAction;

// org.kde.krunner1's types, as KRunner's D-Bus runners send them
struct RunnerMatch {
    QString id;
    QString text;
    QString iconName;
    int categoryRelevance = 0;
    double relevance = 0;
    QVariantMap properties;
};
struct RunnerAction {
    QString id;
    QString text;
    QString iconName;
};
using RunnerMatches = QList<RunnerMatch>;
using RunnerActions = QList<RunnerAction>;
Q_DECLARE_METATYPE(RunnerMatch)
Q_DECLARE_METATYPE(RunnerAction)

QDBusArgument &operator<<(QDBusArgument &argument, const RunnerMatch &match);
const QDBusArgument &operator>>(const QDBusArgument &argument, RunnerMatch &match);
QDBusArgument &operator<<(QDBusArgument &argument, const RunnerAction &action);
const QDBusArgument &operator>>(const QDBusArgument &argument, RunnerAction &action);

// The active app's menus in KRunner (as the old HUD): "exp png" finds File › Export › PNG…, Enter
// runs it. A D-Bus runner at com.dv.glance /Runner (glance-appmenu-runner.desktop tells
// KRunner), searching the menus Glance already holds for its menu bar (AppMenuModel). KRunner's
// own window isn't in the task list, so that is still the app you were in when it opened. Only
// while the application menu is on: apps export their menus then.
class MenuRunner : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.krunner1")

public:
    static MenuRunner *instance();

    // Each AppMenuModel announces itself; the last one with a menu is searched
    void addModel(AppMenuModel *model);
    void removeModel(AppMenuModel *model);

public Q_SLOTS:
    RunnerActions Actions();
    RunnerMatches Match(const QString &query);
    void Run(const QString &matchId, const QString &actionId);
    void Teardown();
    void SetActivationToken(const QString &token);

private:
    explicit MenuRunner(QObject *parent = nullptr);
    AppMenuModel *model() const;
    RunnerMatches matches(AppMenuModel *model, const QString &query);

    QList<QPointer<AppMenuModel>> m_models;
    // What a match's id runs: the item's id in the app's
    // exported menu and where that menu is. Not the QAction: an app may export its menus anew as
    // it gets the focus back from KRunner, and the action is gone by then
    struct Target {
        QString service;
        QString path;
        int itemId = 0;
        QString text;
    };
    // Kept past Teardown, which KRunner sends before Run: only the latest KeptTargets
    QHash<QString, Target> m_targets;
    quint64 m_nextId = 0;
    // The model this session started fetching the whole tree of, to stop it at the end
    QPointer<AppMenuModel> m_prefetched;
};
