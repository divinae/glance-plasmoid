/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "cavasource.h"

#include <QProcess>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTextStream>
#include <QTimer>

#include <algorithm>

namespace
{
constexpr int MaxRange = 100;
}

CavaSource::CavaSource(QObject *parent)
    : QObject(parent)
    , m_silenceTimer(new QTimer(this))
    , m_executable(QStandardPaths::findExecutable(QStringLiteral("cava")))
{
    m_silenceTimer->setSingleShot(true);
    m_silenceTimer->setInterval(2000);
    connect(m_silenceTimer, &QTimer::timeout, this, [this] {
        setSilent(true);
    });
    resetValues();
}

bool CavaSource::monstercat() const
{
    return m_monstercat;
}

void CavaSource::setMonstercat(bool monstercat)
{
    if (m_monstercat == monstercat) {
        return;
    }
    m_monstercat = monstercat;
    Q_EMIT monstercatChanged();
    restartIfRunning();
}

int CavaSource::noiseReduction() const
{
    return m_noiseReduction;
}

void CavaSource::setNoiseReduction(int noiseReduction)
{
    noiseReduction = qBound(0, noiseReduction, 100);
    if (m_noiseReduction == noiseReduction) {
        return;
    }
    m_noiseReduction = noiseReduction;
    Q_EMIT noiseReductionChanged();
    restartIfRunning();
}

bool CavaSource::silent() const
{
    return m_silent;
}

void CavaSource::setSilent(bool silent)
{
    if (m_silent != silent) {
        m_silent = silent;
        Q_EMIT silentChanged();
    }
}

CavaSource::~CavaSource()
{
    // Going (the applet removed, the shell quitting): cava goes now, not later
    if (m_process) {
        m_process->disconnect(this);
        m_process->terminate();
        if (!m_process->waitForFinished(500)) {
            m_process->kill();
            m_process->waitForFinished(200);
        }
    }
}

int CavaSource::bars() const
{
    return m_bars;
}

void CavaSource::setBars(int bars)
{
    bars = qBound(2, bars, 64);
    if (m_bars == bars) {
        return;
    }
    m_bars = bars;
    Q_EMIT barsChanged();
    resetValues();
    restartIfRunning();
}

int CavaSource::framerate() const
{
    return m_framerate;
}

void CavaSource::setFramerate(int framerate)
{
    framerate = qBound(5, framerate, 144);
    if (m_framerate == framerate) {
        return;
    }
    m_framerate = framerate;
    Q_EMIT framerateChanged();
    restartIfRunning();
}

bool CavaSource::running() const
{
    return m_running;
}

void CavaSource::setRunning(bool running)
{
    if (m_running == running) {
        return;
    }
    m_running = running;
    Q_EMIT runningChanged();
    if (m_running) {
        start();
    } else {
        stop();
        resetValues();
    }
}

bool CavaSource::available() const
{
    return !m_executable.isEmpty();
}

QVariantList CavaSource::values() const
{
    return m_values;
}

void CavaSource::resetValues()
{
    QVariantList zeros;
    zeros.reserve(m_bars);
    for (int i = 0; i < m_bars; ++i) {
        zeros << 0;
    }
    m_values = zeros;
    Q_EMIT valuesChanged();
    m_silenceTimer->stop();
    setSilent(false);
}

void CavaSource::restartIfRunning()
{
    if (m_running) {
        stop();
        start();
    }
}

void CavaSource::start()
{
    if (!available() || m_process) {
        return;
    }

    m_config = std::make_unique<QTemporaryFile>();
    if (!m_config->open()) {
        m_config.reset();
        return;
    }
    {
        QTextStream out(m_config.get());
        out << "[general]\n"
            << "bars = " << m_bars << "\n"
            << "framerate = " << m_framerate << "\n"
            << "autosens = 1\n"
            << "[output]\n"
            << "method = raw\n"
            << "raw_target = /dev/stdout\n"
            << "data_format = ascii\n"
            << "ascii_max_range = " << MaxRange << "\n"
            << "bar_delimiter = 59\n"
            << "frame_delimiter = 10\n"
            << "[smoothing]\n"
            << "monstercat = " << (m_monstercat ? 1 : 0) << "\n"
            << "noise_reduction = " << m_noiseReduction << "\n";
    }
    m_config->flush();

    m_buffer.clear();
    m_process = std::make_unique<QProcess>();
    m_process->setProcessChannelMode(QProcess::SeparateChannels);
    m_process->setStandardErrorFile(QProcess::nullDevice());
    connect(m_process.get(), &QProcess::readyReadStandardOutput, this, &CavaSource::readOutput);
    connect(m_process.get(), &QProcess::finished, this, [this] {
        // cava exited on its own (no audio backend, bad config...): don't respawn in a loop
        if (m_process) {
            m_process.release()->deleteLater();
        }
        m_config.reset();
        resetValues();
    });
    m_process->start(m_executable, {QStringLiteral("-p"), m_config->fileName()});
}

void CavaSource::stop()
{
    if (!m_process) {
        return;
    }
    // Without waiting for it on the GUI thread (the whole shell would wait): it goes in the
    // background, killed if it ignores SIGTERM
    QProcess *process = m_process.release();
    process->disconnect(this);
    if (process->state() == QProcess::NotRunning) {
        process->deleteLater();
    } else {
        connect(process, &QProcess::finished, process, &QObject::deleteLater);
        process->terminate();
        QTimer::singleShot(500, process, &QProcess::kill);
    }
    m_config.reset();
    m_buffer.clear();
}

void CavaSource::readOutput()
{
    if (!m_process) {
        return;
    }
    m_buffer += m_process->readAllStandardOutput();

    const int lastNewline = m_buffer.lastIndexOf('\n');
    if (lastNewline < 0) {
        return;
    }
    // Only the newest complete frame matters
    const int prevNewline = m_buffer.lastIndexOf('\n', lastNewline - 1);
    const QByteArray frame = m_buffer.mid(prevNewline + 1, lastNewline - prevNewline - 1);
    m_buffer.remove(0, lastNewline + 1);

    const QList<QByteArray> parts = frame.split(';');
    QVariantList values;
    values.reserve(m_bars);
    for (const QByteArray &part : parts) {
        if (part.isEmpty()) {
            continue;
        }
        bool ok = false;
        const int v = part.toInt(&ok);
        values << (ok ? qBound(0, v, MaxRange) : 0);
    }
    if (values.isEmpty()) {
        return;
    }
    if (std::ranges::any_of(values, [](const QVariant &v) { return v.toInt() > 0; })) {
        m_silenceTimer->stop();
        setSilent(false);
    } else if (!m_silent && !m_silenceTimer->isActive()) {
        m_silenceTimer->start();
    }
    m_values = values;
    Q_EMIT valuesChanged();
}
