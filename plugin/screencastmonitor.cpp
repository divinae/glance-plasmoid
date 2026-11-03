/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "screencastmonitor.h"

#include <pipewire/pipewire.h>

#include <KService>

#include <QFile>
#include <QFutureWatcher>
#include <QHash>
#include <QTimer>
#include <QtConcurrentRun>

#include <dirent.h>
#include <unistd.h>

#include <cstring>
#include <map>

namespace
{
QString prop(const spa_dict *props, const char *key)
{
    const char *value = props ? spa_dict_lookup(props, key) : nullptr;
    return value ? QString::fromUtf8(value) : QString();
}

// An application's name for its id ("jetbrains-studio" → "Android Studio"), from its
// .desktop file; the id itself when there's none
QString applicationName(const QString &id)
{
    if (id.isEmpty()) {
        return id;
    }
    KService::Ptr service = KService::serviceByDesktopName(id);
    if (!service) {
        service = KService::serviceByDesktopName(id.toLower());
    }
    if (service && !service->name().isEmpty()) {
        return service->name();
    }
    // No .desktop file: the id, capitalised ("slack" → "Slack")
    return id.left(1).toUpper() + id.mid(1);
}

bool isWatched(const QString &mediaClass)
{
    return mediaClass == QLatin1String("Stream/Output/Video") || mediaClass == QLatin1String("Stream/Input/Video")
        || mediaClass == QLatin1String("Stream/Input/Audio");
}

// The names (comm) of the processes with a /dev/video* open. Off the GUI thread: thousands of
// /proc/*/fd links to read, every two seconds.
QStringList cameraProcesses()
{
    QStringList names;
    DIR *proc = opendir("/proc");
    if (!proc) {
        return names;
    }
    while (const dirent *entry = readdir(proc)) {
        if (entry->d_name[0] < '0' || entry->d_name[0] > '9') {
            continue;
        }
        char path[sizeof("/proc//comm") + sizeof(entry->d_name)];
        snprintf(path, sizeof(path), "/proc/%s/fd", entry->d_name);
        DIR *fds = opendir(path);
        if (!fds) {
            continue; // not ours to look into, or gone
        }
        bool usesCamera = false;
        while (const dirent *fd = readdir(fds)) {
            char target[32];
            const ssize_t length = readlinkat(dirfd(fds), fd->d_name, target, sizeof(target));
            if (length >= 10 && std::memcmp(target, "/dev/video", 10) == 0) {
                usesCamera = true;
                break;
            }
        }
        closedir(fds);
        if (!usesCamera) {
            continue;
        }
        snprintf(path, sizeof(path), "/proc/%s/comm", entry->d_name);
        QFile comm(QString::fromLatin1(path));
        if (comm.open(QIODevice::ReadOnly)) {
            const QString name = QString::fromUtf8(comm.readAll()).trimmed();
            if (!name.isEmpty()) {
                names << name;
            }
        }
    }
    closedir(proc);
    return names;
}
}

struct ScreenCastMonitor::Private {
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

    // One bound node, listened to for its state and properties (on PipeWire's thread)
    struct BoundNode {
        Private *d = nullptr;
        quint32 id = 0;
        // What's known so far: PipeWire sends only what changed after the first info
        Node node;
        pw_proxy *proxy = nullptr;
        spa_hook listener{};
        spa_hook proxyListener{};
    };

    ScreenCastMonitor *q = nullptr;

    pw_thread_loop *loop = nullptr;
    pw_context *context = nullptr;
    pw_core *core = nullptr;
    pw_registry *registry = nullptr;
    spa_hook registryListener{};
    std::map<quint32, std::unique_ptr<BoundNode>> bound; // on PipeWire's thread

    QHash<quint32, Node> nodes; // on the Qt thread
    QFutureWatcher<QStringList> cameraScan;

    void connectPipeWire();
    void disconnectPipeWire();

    // From PipeWire's thread to the Qt thread: q outlives the thread (joined in ~ScreenCastMonitor),
    // and events still queued for it are dropped with it
    void nodeChanged(quint32 id, const Node &node)
    {
        QMetaObject::invokeMethod(q, [q = q, id, node] {
            q->d->nodes.insert(id, node);
            q->recompute();
        }, Qt::QueuedConnection);
    }
    void nodeRemoved(quint32 id)
    {
        QMetaObject::invokeMethod(q, [q = q, id] {
            if (q->d->nodes.remove(id)) {
                q->recompute();
            }
        }, Qt::QueuedConnection);
    }

    static void nodeInfo(void *data, const pw_node_info *info);
    static void proxyRemoved(void *data);
    static void registryGlobal(void *data, uint32_t id, uint32_t permissions, const char *type, uint32_t version, const spa_dict *props);
    static void registryGlobalRemove(void *data, uint32_t id);
};

void ScreenCastMonitor::Private::nodeInfo(void *data, const pw_node_info *info)
{
    auto *bound = static_cast<BoundNode *>(data);
    Node &n = bound->node;
    if (info->change_mask & PW_NODE_CHANGE_MASK_STATE) {
        n.running = info->state == PW_NODE_STATE_RUNNING;
    }
    if ((info->change_mask & PW_NODE_CHANGE_MASK_PROPS) && info->props) {
        n.mediaClass = prop(info->props, PW_KEY_MEDIA_CLASS);
        n.name = prop(info->props, PW_KEY_NODE_NAME);
        n.mediaName = prop(info->props, PW_KEY_MEDIA_NAME);
        n.application = prop(info->props, PW_KEY_APP_NAME);
        n.binary = prop(info->props, PW_KEY_APP_PROCESS_BINARY);
        n.category = prop(info->props, PW_KEY_MEDIA_CATEGORY);
        n.captureSink = prop(info->props, PW_KEY_STREAM_CAPTURE_SINK) == QLatin1String("true");
        bool ok = false;
        n.target = prop(info->props, PW_KEY_TARGET_OBJECT).toUInt(&ok);
        if (!ok) {
            n.target = prop(info->props, "node.target").toUInt(&ok);
        }
        if (!ok) {
            n.target = prop(info->props, "node.driver-id").toUInt();
        }
    }
    bound->d->nodeChanged(bound->id, n);
}

void ScreenCastMonitor::Private::proxyRemoved(void *data)
{
    // The node is gone on the server: no more events for it (its proxy goes with global_remove)
    auto *bound = static_cast<BoundNode *>(data);
    spa_hook_remove(&bound->listener);
    spa_hook_remove(&bound->proxyListener);
}

void ScreenCastMonitor::Private::registryGlobal(void *data, uint32_t id, uint32_t, const char *type, uint32_t, const spa_dict *props)
{
    static const pw_node_events nodeEvents = {
        .version = PW_VERSION_NODE_EVENTS,
        .info = nodeInfo,
        .param = nullptr,
    };
    static const pw_proxy_events proxyEvents = {
        .version = PW_VERSION_PROXY_EVENTS,
        .destroy = nullptr,
        .bound = nullptr,
        .removed = proxyRemoved,
        .done = nullptr,
        .error = nullptr,
        .bound_props = nullptr,
    };

    auto *d = static_cast<Private *>(data);
    if (qstrcmp(type, PW_TYPE_INTERFACE_Node) != 0 || !isWatched(prop(props, PW_KEY_MEDIA_CLASS))) {
        return;
    }
    auto bound = std::make_unique<BoundNode>();
    bound->d = d;
    bound->id = id;
    bound->proxy = static_cast<pw_proxy *>(pw_registry_bind(d->registry, id, PW_TYPE_INTERFACE_Node, PW_VERSION_NODE, 0));
    if (!bound->proxy) {
        return;
    }
    pw_node_add_listener(reinterpret_cast<pw_node *>(bound->proxy), &bound->listener, &nodeEvents, bound.get());
    pw_proxy_add_listener(bound->proxy, &bound->proxyListener, &proxyEvents, bound.get());
    d->bound[id] = std::move(bound);
}

void ScreenCastMonitor::Private::registryGlobalRemove(void *data, uint32_t id)
{
    auto *d = static_cast<Private *>(data);
    auto it = d->bound.find(id);
    if (it != d->bound.end()) {
        pw_proxy_destroy(it->second->proxy);
        d->bound.erase(it);
        d->nodeRemoved(id);
    }
}

void ScreenCastMonitor::Private::connectPipeWire()
{
    static const pw_registry_events registryEvents = {
        .version = PW_VERSION_REGISTRY_EVENTS,
        .global = registryGlobal,
        .global_remove = registryGlobalRemove,
    };

    pw_init(nullptr, nullptr);
    loop = pw_thread_loop_new("glance-screencast", nullptr);
    if (!loop) {
        return;
    }
    context = pw_context_new(pw_thread_loop_get_loop(loop), nullptr, 0);
    if (!context) {
        return;
    }
    core = pw_context_connect(context, nullptr, 0);
    if (!core) {
        return;
    }
    registry = pw_core_get_registry(core, PW_VERSION_REGISTRY, 0);
    if (!registry) {
        return;
    }
    // The loop isn't running yet: no locking needed before it starts
    pw_registry_add_listener(registry, &registryListener, &registryEvents, this);
    pw_thread_loop_start(loop);
}

void ScreenCastMonitor::Private::disconnectPipeWire()
{
    // Joins PipeWire's thread: no callbacks from here on, and its objects are ours to destroy
    if (loop) {
        pw_thread_loop_stop(loop);
    }
    for (auto &[id, node] : bound) {
        pw_proxy_destroy(node->proxy);
    }
    bound.clear();
    if (registry) {
        spa_hook_remove(&registryListener);
        pw_proxy_destroy(reinterpret_cast<pw_proxy *>(registry));
    }
    if (core) {
        pw_core_disconnect(core);
    }
    if (context) {
        pw_context_destroy(context);
    }
    if (loop) {
        pw_thread_loop_destroy(loop);
    }
}

ScreenCastMonitor::ScreenCastMonitor(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>())
{
    d->q = this;
    d->connectPipeWire();

    // Cameras opened directly: who has a /dev/video* open, every two seconds
    connect(&d->cameraScan, &QFutureWatcher<QStringList>::finished, this, [this] {
        camerasScanned(d->cameraScan.result());
    });
    auto *timer = new QTimer(this);
    timer->setInterval(2000);
    connect(timer, &QTimer::timeout, this, &ScreenCastMonitor::scanCameras);
    timer->start();
    scanCameras();
}

ScreenCastMonitor::~ScreenCastMonitor()
{
    d->disconnectPipeWire();
}

void ScreenCastMonitor::scanCameras()
{
    if (!d->cameraScan.isRunning()) {
        d->cameraScan.setFuture(QtConcurrent::run(cameraProcesses));
    }
}

void ScreenCastMonitor::camerasScanned(const QStringList &processes)
{
    // PipeWire and its session manager keep the devices open for everyone: not "in use"
    static const QStringList services = {QStringLiteral("pipewire"), QStringLiteral("wireplumber"), QStringLiteral("pipewire-media-session")};
    QStringList users;
    for (const QString &name : processes) {
        if (services.contains(name)) {
            continue;
        }
        const QString who = applicationName(name);
        if (!users.contains(who)) {
            users << who;
        }
    }
    if (users != m_cameraUsers) {
        m_cameraUsers = users;
        Q_EMIT changed();
    }
}

void ScreenCastMonitor::recompute()
{
    const auto &nodes = d->nodes;
    QVariantList casts;
    for (auto it = nodes.cbegin(); it != nodes.cend(); ++it) {
        const Private::Node &cast = it.value();
        if (!cast.running || cast.mediaClass != QLatin1String("Stream/Output/Video") || cast.name != QLatin1String("kwin_wayland")) {
            continue;
        }
        // "kwin-screencast-<window's app id>", or the screen's name
        QString what = cast.mediaName;
        what.remove(QLatin1String("kwin-screencast-"));
        what = applicationName(what);
        QStringList viewers;
        for (auto v = nodes.cbegin(); v != nodes.cend(); ++v) {
            const Private::Node &viewer = v.value();
            if (viewer.mediaClass == QLatin1String("Stream/Input/Video") && viewer.target == it.key()) {
                const QString who = applicationName(!viewer.application.isEmpty() ? viewer.application : viewer.name);
                if (!who.isEmpty() && !viewers.contains(who)) {
                    viewers << who;
                }
            }
        }
        casts << QVariantMap{{QStringLiteral("what"), what}, {QStringLiteral("viewers"), viewers}};
    }
    // Recording the microphone: running audio captures, but not of what's playing (cava and
    // other visualisers, a sink's monitor) nor level meters (the volume applet, pavucontrol)
    static const QStringList meters = {QStringLiteral("cava"), QStringLiteral("plasmashell"), QStringLiteral("pavucontrol"),
                                       QStringLiteral("pavucontrol-qt"), QStringLiteral("easyeffects"), QStringLiteral("pwvucontrol")};
    QStringList mic;
    for (const Private::Node &n : nodes) {
        if (!n.running || n.mediaClass != QLatin1String("Stream/Input/Audio") || n.captureSink
            || n.category == QLatin1String("Monitor") || meters.contains(n.binary)
            || n.mediaName.contains(QLatin1String("Peak detect"), Qt::CaseInsensitive)) {
            continue;
        }
        const QString who = applicationName(!n.application.isEmpty() ? n.application : n.name);
        if (!who.isEmpty() && !mic.contains(who)) {
            mic << who;
        }
    }
    if (casts != m_casts || mic != m_micUsers) {
        m_casts = casts;
        m_micUsers = mic;
        Q_EMIT changed();
    }
}

bool ScreenCastMonitor::active() const
{
    return !m_casts.isEmpty();
}

QVariantList ScreenCastMonitor::casts() const
{
    return m_casts;
}

bool ScreenCastMonitor::micActive() const
{
    return !m_micUsers.isEmpty();
}

QStringList ScreenCastMonitor::micUsers() const
{
    return m_micUsers;
}

QStringList ScreenCastMonitor::cameraUsers() const
{
    return m_cameraUsers;
}
