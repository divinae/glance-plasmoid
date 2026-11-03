/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "screencastmonitor.h"

#include <pipewire/pipewire.h>
#include <spa/utils/hook.h>

#include <KService>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QTimer>
#include <QPointer>

#include <map>
#include <memory>

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
}

// One bound node, listened to for its state and properties (on PipeWire's thread)
struct BoundNode {
    ScreenCastMonitor *monitor = nullptr;
    quint32 id = 0;
    pw_proxy *proxy = nullptr;
    spa_hook listener{};
    spa_hook proxyListener{};
};

struct ScreenCastMonitor::Private {
    spa_hook registryListener{};
    std::map<quint32, std::unique_ptr<BoundNode>> bound;
};

static void nodeInfo(void *data, const pw_node_info *info)
{
    auto *node = static_cast<BoundNode *>(data);
    ScreenCastMonitor::Node n;
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
    n.running = info->state == PW_NODE_STATE_RUNNING;
    node->monitor->nodeChanged(node->id, n);
}

static const pw_node_events nodeEvents = {
    .version = PW_VERSION_NODE_EVENTS,
    .info = nodeInfo,
    .param = nullptr,
};

static void proxyRemoved(void *data)
{
    auto *node = static_cast<BoundNode *>(data);
    spa_hook_remove(&node->listener);
    spa_hook_remove(&node->proxyListener);
}

static const pw_proxy_events proxyEvents = {
    .version = PW_VERSION_PROXY_EVENTS,
    .destroy = nullptr,
    .bound = nullptr,
    .removed = proxyRemoved,
    .done = nullptr,
    .error = nullptr,
    .bound_props = nullptr,
};

struct RegistryContext {
    ScreenCastMonitor *monitor;
    pw_registry *registry;
    ScreenCastMonitor::Private *d;
};
static RegistryContext *s_ctx = nullptr;

static void registryGlobal(void *data, uint32_t id, uint32_t, const char *type, uint32_t, const spa_dict *props)
{
    auto *ctx = static_cast<RegistryContext *>(data);
    if (qstrcmp(type, PW_TYPE_INTERFACE_Node) != 0 || !isWatched(prop(props, PW_KEY_MEDIA_CLASS))) {
        return;
    }
    auto node = std::make_unique<BoundNode>();
    node->monitor = ctx->monitor;
    node->id = id;
    node->proxy = static_cast<pw_proxy *>(pw_registry_bind(ctx->registry, id, PW_TYPE_INTERFACE_Node, PW_VERSION_NODE, 0));
    if (!node->proxy) {
        return;
    }
    pw_node_add_listener(reinterpret_cast<pw_node *>(node->proxy), &node->listener, &nodeEvents, node.get());
    pw_proxy_add_listener(node->proxy, &node->proxyListener, &proxyEvents, node.get());
    ctx->d->bound[id] = std::move(node);
}

static void registryGlobalRemove(void *data, uint32_t id)
{
    auto *ctx = static_cast<RegistryContext *>(data);
    auto it = ctx->d->bound.find(id);
    if (it != ctx->d->bound.end()) {
        pw_proxy_destroy(it->second->proxy);
        ctx->d->bound.erase(it);
    }
    ctx->monitor->nodeRemoved(id);
}

static const pw_registry_events registryEvents = {
    .version = PW_VERSION_REGISTRY_EVENTS,
    .global = registryGlobal,
    .global_remove = registryGlobalRemove,
};

ScreenCastMonitor::ScreenCastMonitor(QObject *parent)
    : QObject(parent)
    , d(new Private)
{
    pw_init(nullptr, nullptr);
    m_loop = pw_thread_loop_new("glance-screencast", nullptr);
    if (!m_loop) {
        return;
    }
    m_context = pw_context_new(pw_thread_loop_get_loop(m_loop), nullptr, 0);
    if (!m_context) {
        return;
    }
    m_core = pw_context_connect(m_context, nullptr, 0);
    if (!m_core) {
        return;
    }
    m_registry = pw_core_get_registry(m_core, PW_VERSION_REGISTRY, 0);
    s_ctx = new RegistryContext{this, m_registry, d};
    pw_registry_add_listener(m_registry, &d->registryListener, &registryEvents, s_ctx);
    pw_thread_loop_start(m_loop);

    // Cameras opened directly: who has a /dev/video* open, every two seconds
    auto *timer = new QTimer(this);
    timer->setInterval(2000);
    connect(timer, &QTimer::timeout, this, &ScreenCastMonitor::scanCameras);
    timer->start();
    scanCameras();
}

void ScreenCastMonitor::scanCameras()
{
    // PipeWire and its session manager keep the devices open for everyone: not "in use"
    static const QStringList services = {QStringLiteral("pipewire"), QStringLiteral("wireplumber"), QStringLiteral("pipewire-media-session")};
    QStringList users;
    const QStringList pids = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &pid : pids) {
        bool numeric = false;
        pid.toInt(&numeric);
        if (!numeric) {
            continue;
        }
        const QString fdDir = QStringLiteral("/proc/") + pid + QStringLiteral("/fd");
        const QStringList fds = QDir(fdDir).entryList(QDir::Files | QDir::System | QDir::NoDotAndDotDot);
        bool usesCamera = false;
        for (const QString &fd : fds) {
            if (QFileInfo(fdDir + QLatin1Char('/') + fd).symLinkTarget().startsWith(QLatin1String("/dev/video"))) {
                usesCamera = true;
                break;
            }
        }
        if (!usesCamera) {
            continue;
        }
        QFile comm(QStringLiteral("/proc/") + pid + QStringLiteral("/comm"));
        if (!comm.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QString name = QString::fromUtf8(comm.readAll()).trimmed();
        if (name.isEmpty() || services.contains(name)) {
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

ScreenCastMonitor::~ScreenCastMonitor()
{
    if (m_loop) {
        pw_thread_loop_stop(m_loop);
    }
    for (auto &[id, node] : d->bound) {
        if (node->proxy) {
            pw_proxy_destroy(node->proxy);
        }
    }
    d->bound.clear();
    if (m_registry) {
        spa_hook_remove(&d->registryListener);
        pw_proxy_destroy(reinterpret_cast<pw_proxy *>(m_registry));
    }
    if (m_core) {
        pw_core_disconnect(m_core);
    }
    if (m_context) {
        pw_context_destroy(m_context);
    }
    if (m_loop) {
        pw_thread_loop_destroy(m_loop);
    }
    delete s_ctx;
    s_ctx = nullptr;
    delete d;
}

void ScreenCastMonitor::nodeChanged(quint32 id, const Node &node)
{
    QPointer<ScreenCastMonitor> self(this);
    QMetaObject::invokeMethod(this, [self, id, node] {
        if (self) {
            self->m_nodes.insert(id, node);
            self->recompute();
        }
    }, Qt::QueuedConnection);
}

void ScreenCastMonitor::nodeRemoved(quint32 id)
{
    QPointer<ScreenCastMonitor> self(this);
    QMetaObject::invokeMethod(this, [self, id] {
        if (self && self->m_nodes.remove(id)) {
            self->recompute();
        }
    }, Qt::QueuedConnection);
}

void ScreenCastMonitor::recompute()
{
    QVariantList casts;
    for (auto it = m_nodes.cbegin(); it != m_nodes.cend(); ++it) {
        const Node &cast = it.value();
        if (!cast.running || cast.mediaClass != QLatin1String("Stream/Output/Video") || cast.name != QLatin1String("kwin_wayland")) {
            continue;
        }
        // "kwin-screencast-<window's app id>", or the screen's name
        QString what = cast.mediaName;
        what.remove(QLatin1String("kwin-screencast-"));
        what = applicationName(what);
        QStringList viewers;
        for (auto v = m_nodes.cbegin(); v != m_nodes.cend(); ++v) {
            const Node &viewer = v.value();
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
    for (const Node &n : std::as_const(m_nodes)) {
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
