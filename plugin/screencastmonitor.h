/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <qqmlregistration.h>

struct pw_thread_loop;
struct pw_context;
struct pw_core;
struct pw_registry;

// Screen sharing in progress, from PipeWire: KWin's screencast streams (kwin_wayland,
// Stream/Output/Video) that are running, and the applications taking them in. KDE's
// MediaMonitor misses these: they carry no media.role.
class ScreenCastMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY changed)
    // [{what: "jetbrains-studio" or "", viewers: ["slack"]}]
    Q_PROPERTY(QVariantList casts READ casts NOTIFY changed)
    // The microphone recorded by an application (not audio meters or visualisers)
    Q_PROPERTY(bool micActive READ micActive NOTIFY changed)
    Q_PROPERTY(QStringList micUsers READ micUsers NOTIFY changed)

public:
    explicit ScreenCastMonitor(QObject *parent = nullptr);
    ~ScreenCastMonitor() override;

    bool active() const;
    QVariantList casts() const;
    bool micActive() const;
    QStringList micUsers() const;

    struct Node {
        QString mediaClass;
        QString name;
        QString mediaName;
        QString application;
        QString binary;
        QString category;
        bool captureSink = false;
        quint32 target = 0;
        bool running = false;
    };

    // PipeWire's side (its listeners live in the .cpp)
    struct Private;

    // From PipeWire's thread
    void nodeChanged(quint32 id, const Node &node);
    void nodeRemoved(quint32 id);

Q_SIGNALS:
    void changed();

private:
    void recompute();

    pw_thread_loop *m_loop = nullptr;
    pw_context *m_context = nullptr;
    pw_core *m_core = nullptr;
    pw_registry *m_registry = nullptr;
    Private *d = nullptr;

    QHash<quint32, Node> m_nodes; // on the Qt thread
    QVariantList m_casts;
    QStringList m_micUsers;
};
