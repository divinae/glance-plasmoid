/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KConfigWatcher>
#include <KSharedConfig>
#include <QObject>
#include <qqmlregistration.h>

// Plasma's automatic light/dark switch (System Settings → Global Theme → "Change automatically"),
// kept in kdeglobals as [KDE] AutomaticLookAndFeel. Plasma's own daemon (kded's
// lookandfeelautoswitcher) does the switching at sunrise and sunset; this only turns it on or off.
// Light and dark themselves go through the brightness plugin's DarkModeControl.
class ThemeMode : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool automatic READ automatic WRITE setAutomatic NOTIFY automaticChanged)
    Q_PROPERTY(bool immutable READ immutable CONSTANT)
    // Plasma's switcher is there and not turned off in Background Services: without it,
    // "automatic" would be saved but nothing would switch
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit ThemeMode(QObject *parent = nullptr);

    bool automatic() const;
    void setAutomatic(bool automatic);
    bool immutable() const;
    bool available() const;

Q_SIGNALS:
    void automaticChanged();

private:
    bool readAutomatic() const;
    void reload();

    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_watcher;
    bool m_automatic = false;
};
