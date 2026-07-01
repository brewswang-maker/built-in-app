#include "WebRTCStreamProvider.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QDebug>

namespace {
// 探测结果缓存时长 — 60s 避免 64 路并发重复探测
constexpr int kCacheTtlSeconds = 60;
}  // namespace

WebRTCStreamProvider::WebRTCStreamProvider(QObject* parent)
    : QObject(parent) {}

QString WebRTCStreamProvider::buildWebRtcUrl(const QString& host, int port,
                                             const QString& streamId) {
    return QStringLiteral("webrtc://%1:%2/index/api/webrtc?app=live&stream=%3")
        .arg(host)
        .arg(port)
        .arg(streamId);
}

bool WebRTCStreamProvider::probeSync(const QString& host, int port,
                                     int timeoutMs) {
    QNetworkAccessManager nam;
    QNetworkRequest req(QUrl(QStringLiteral("http://%1:%2/index/api/getServerInfo")
                                 .arg(host).arg(port)));
    req.setRawHeader("User-Agent", "ShieldBox-WebRTC-Probe/1.0");

    QEventLoop loop;
    QNetworkReply* reply = nam.head(req);
    bool available = false;

    QTimer::singleShot(timeoutMs, reply, [reply]() {
        if (reply->isRunning()) reply->abort();
    });

    QObject::connect(reply, &QNetworkReply::finished, [&]() {
        const int httpStatus = reply->attribute(
            QNetworkRequest::HttpStatusCodeAttribute).toInt();
        available = (reply->error() == QNetworkReply::NoError) || (httpStatus > 0);
        loop.quit();
    });

    loop.exec();
    reply->deleteLater();
    return available;
}

void WebRTCStreamProvider::requestWebRtcUrl(const QString& host, int port,
                                            const QString& streamId) {
    m_stats.total_probes++;
    m_stats.last_probe_at = QDateTime::currentDateTime();

    const QString cacheKey = QStringLiteral("%1:%2").arg(host).arg(port);

    if (!m_enabled) {
        m_stats.fallback_count++;
        emit webRtcFallback(host, port, streamId,
                            QStringLiteral("WebRTCStreamProvider disabled"));
        return;
    }

    auto it = m_cache.find(cacheKey);
    if (it != m_cache.end() && it->expiresAt > QDateTime::currentDateTime()) {
        if (it->available) {
            m_stats.successful_probes++;
            emit webRtcResolved(host, port, streamId,
                                buildWebRtcUrl(host, port, streamId));
        } else {
            m_stats.fallback_count++;
            emit webRtcFallback(host, port, streamId,
                                QStringLiteral("cached unavailable"));
        }
        return;
    }

    QNetworkAccessManager* nam = new QNetworkAccessManager(this);
    QNetworkRequest req(QUrl(QStringLiteral("http://%1:%2/index/api/getServerInfo")
                                 .arg(host).arg(port)));
    req.setRawHeader("User-Agent", "ShieldBox-WebRTC-Probe/1.0");

    QNetworkReply* reply = nam->head(req);
    QTimer::singleShot(1500, reply, [reply]() {
        if (reply->isRunning()) reply->abort();
    });

    QObject::connect(reply, &QNetworkReply::finished, this,
        [this, reply, nam, cacheKey, host, port, streamId]() {
            const int httpStatus = reply->attribute(
                QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const bool available =
                (reply->error() == QNetworkReply::NoError) || (httpStatus > 0);

            CacheEntry entry;
            entry.available = available;
            entry.expiresAt = QDateTime::currentDateTime().addSecs(kCacheTtlSeconds);
            m_cache.insert(cacheKey, entry);

            if (available) {
                m_stats.successful_probes++;
                emit webRtcResolved(host, port, streamId,
                                    buildWebRtcUrl(host, port, streamId));
            } else {
                m_stats.fallback_count++;
                emit webRtcFallback(host, port, streamId,
                                    QStringLiteral("probe failed: %1")
                                        .arg(reply->errorString()));
            }

            reply->deleteLater();
            nam->deleteLater();
        });
}