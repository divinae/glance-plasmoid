/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "thememode.h"

#include <KConfigGroup>
#include <KPluginMetaData>

namespace
{
const char *const s_group = "KDE";
const char *const s_key = "AutomaticLookAndFeel";
const char *const s_switcher = "lookandfeelautoswitcher";
}

ThemeMode::ThemeMode(QObject *parent)
    : QObject(parent)
    // CascadeConfig, not the default FullConfig: an instance of our own rather than the one
    // the whole shell shares, so reparsing or syncing it touches nobody else's state
    , m_config(KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::CascadeConfig))
    , m_watcher(KConfigWatcher::create(m_config))
{
    // System Settings, or the daemon, changing it: KConfig::Notify writes reach us here, the
    // watcher having reparsed the file already
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group, const QByteArrayList &names) {
        if (group.name() == QLatin1String(s_group) && names.contains(s_key)) {
            reload();
        }
    });
    m_automatic = readAutomatic();
}

bool ThemeMode::automatic() const
{
    return m_automatic;
}

bool ThemeMode::immutable() const
{
    return m_config->group(QString::fromLatin1(s_group)).isEntryImmutable(s_key);
}

bool ThemeMode::available() const
{
    if (!KPluginMetaData::findPluginById(QStringLiteral("kf6/kded"), QString::fromLatin1(s_switcher)).isValid()) {
        return false;
    }
    // Turned off under System Settings → Background Services
    const KConfig kded(QStringLiteral("kded6rc"), KConfig::NoGlobals);
    return kded.group(QStringLiteral("Module-") + QString::fromLatin1(s_switcher)).readEntry("autoload", true);
}

bool ThemeMode::readAutomatic() const
{
    return m_config->group(QString::fromLatin1(s_group)).readEntry(s_key, false);
}

void ThemeMode::setAutomatic(bool automatic)
{
    if (immutable()) {
        return;
    }
    // What the file says now, not what we last heard: a change made without Notify (by hand,
    // or kwriteconfig6 without --notify) never reached the watcher
    m_config->reparseConfiguration();
    if (readAutomatic() != automatic) {
        KConfigGroup group = m_config->group(QString::fromLatin1(s_group));
        // Notify: the switcher daemon and System Settings pick it up at once
        group.writeEntry(s_key, automatic, KConfig::Notify | KConfig::Persistent);
        m_config->sync();
    }
    if (automatic != m_automatic) {
        m_automatic = automatic;
        Q_EMIT automaticChanged();
    }
}

void ThemeMode::reload()
{
    const bool automatic = readAutomatic();
    if (automatic != m_automatic) {
        m_automatic = automatic;
        Q_EMIT automaticChanged();
    }
}
