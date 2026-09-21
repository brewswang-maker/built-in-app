#include "StreamingController.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QDateTime>
#include <QDebug>

// [P2-#14 v7.6+] 降级链顺序: rtsp > ws-flv > flv > hls > webrtc
static const char* const kDegradationChain[] = {"rtsp", "ws-flv", "flv", "hls", "webrtc"};

StreamingController::StreamingController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api),
      m_healthTimer(new QTimer(this)) {
    // [P2-#14 v7.6+] 默认启动健康巡检 (与 Web 端 MediaHealthMonitor 对齐)
    m_healthTimer->setInterval(m_healthCheckIntervalSec * 1000);
    m_healthTimer->setSingleShot(false);
    connect(m_healthTimer, &QTimer::timeout, this, &StreamingController::onHealthTimerTick);
    m_healthTimer->start();
    m_healthMonitoring = true;
    qInfo() << "[StreamingController] 健康巡检已启动, 间隔=" << m_healthCheckIntervalSec << "秒";

    // [FIX v7.6 2026-08-26] 订阅 WS 流事件(后端推流状态变化/转码完成等)
    //   9 类路由补齐: stream_event 之前无消费者,会导致推流完成后 UI 不会自刷新。
    m_wsRouter = WsMessageRouter::instance();
    if (m_wsRouter) {
        QObject::connect(m_wsRouter, &WsMessageRouter::streamEventReceived,
                         this, &StreamingController::onStreamEventReceived);
    }
}

void StreamingController::setLoading(bool v) {
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

void StreamingController::refreshStreams() {
    setLoading(true);
    m_api->get("/api/v1/streams",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/streams:[...]/data:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "streams", "data"});
            m_streams.clear();
            for (const auto& v : arr) m_streams.append(v.toVariant().toMap());
            emit streamsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void StreamingController::refreshZlmStatus() {
    m_api->get("/api/v1/zlm/status",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{...zlm 状态字段...}}
            m_zlmStatus = ApiClient::unwrapData(obj).toVariantMap();
            emit zlmStatusUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::refreshStreamHealth() {
    m_api->get("/api/v1/media/health",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{...health 字段...}}
            m_streamHealth = ApiClient::unwrapData(obj).toVariantMap();
            emit streamHealthUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::refreshAll() {
    refreshStreams();
    refreshZlmStatus();
    refreshStreamHealth();
}

// [P2-#14 v7.6+] 健康巡检控制
void StreamingController::startHealthMonitoring() {
    if (m_healthMonitoring) return;
    m_healthTimer->start();
    m_healthMonitoring = true;
    qInfo() << "[StreamingController] 健康巡检启动, 间隔=" << m_healthTimer->interval() / 1000 << "秒";
    emit healthMonitoringChanged();
}

void StreamingController::stopHealthMonitoring() {
    if (!m_healthMonitoring) return;
    m_healthTimer->stop();
    m_healthMonitoring = false;
    qInfo() << "[StreamingController] 健康巡检已停止";
    emit healthMonitoringChanged();
}

void StreamingController::setHealthCheckIntervalSec(int s) {
    if (s < 5) s = 5;       // 下限 5s
    if (s > 600) s = 600;    // 上限 10min
    if (m_healthCheckIntervalSec != s) {
        m_healthCheckIntervalSec = s;
        m_healthTimer->setInterval(s * 1000);
        emit healthCheckIntervalChanged();
        qInfo() << "[StreamingController] 健康巡检间隔已调整为" << s << "秒";
    }
}

void StreamingController::onHealthTimerTick() {
    // 定时刷新健康状态 + 检测阈值后自动切换协议
    // [FIX v7.6 2026-08-26] 向后兼容: 旧版后端 /api/v1/media/health 仅返回
    //   {zlm_status, timestamp}, 走 graceful degradation: zlm_status != "healthy"
    //   时直接触发降级链.
    // [P0-C 2026-09-21] 后端已扩展 streams[]({channelId,streamId,active,lossRate,
    //   failCount,rttMs}, MediaRouter::getHealthJson), 细粒度路径真实生效。
    m_api->get("/api/v1/media/health",
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            m_streamHealth = data.toVariantMap();
            emit streamHealthUpdated();

            // 1) 后端细粒度字段就绪路径: 逐流按阈值判断
            QJsonArray streams = data.value("streams").toArray();
            bool fineGrained = !streams.isEmpty();
            for (const auto& v : streams) {
                QJsonObject so = v.toObject();
                QString sid = so.value("streamId").toString(so.value("id").toString());
                QString protocol = so.value("protocol").toString("rtsp");
                double lossRate = so.value("lossRate").toDouble(0.0);
                int failCount = so.value("failCount").toInt(0);
                int rttMs = so.value("rttMs").toInt(-1);

                // 阈值: lossRate > 0.3 或 failCount >= 3 或 rttMs > 3000
                bool degraded = (lossRate > 0.3) || (failCount >= 3) || (rttMs > 3000);
                if (!degraded || sid.isEmpty()) continue;

                QString fallback = pickFallbackProtocol(protocol, sid);
                if (fallback.isEmpty() || fallback == protocol) continue;

                QString reason = QString("lossRate=%1, failCount=%2, rttMs=%3")
                    .arg(lossRate, 0, 'f', 2).arg(failCount).arg(rttMs);
                qWarning() << "[StreamingController] 健康度异常 stream=" << sid
                           << " reason=" << reason
                           << " 降级到" << fallback;

                emit healthDegraded(sid, reason, fallback);

                // 自动切换: 避免连环切换, 只在 currentProtocol 不是 fallback 时调用
                switchStream(sid, fallback);
            }

            // 2) 粗粒度降级: 后端未提供 streams[] 或 zlm_status != healthy
            //   按 ZLM 整体健康度做一次整体降级 (any-stream fallback)
            if (!fineGrained) {
                QString zlm = data.value("zlm_status").toString();
                if (zlm.isEmpty()) zlm = "unknown";
                if (zlm == "down" || zlm == "unknown") {
                    // 任意活跃流: 取 m_streams 第一条, 强制降一级 (作为系统级触发)
                    if (!m_streams.isEmpty()) {
                        QVariantMap first = m_streams.first().toMap();
                        QString sid = first.value("streamId").toString();
                        if (sid.isEmpty()) sid = first.value("stream_id").toString();
                        QString protocol = first.value("schema").toString();
                        if (protocol.isEmpty()) protocol = "rtsp";
                        QString fallback = pickFallbackProtocol(protocol, sid);
                        if (!fallback.isEmpty() && fallback != protocol) {
                            QString reason = QString("zlm_status=%1 (no streams[] yet, fallback to first stream)").arg(zlm);
                            qWarning() << "[StreamingController] 健康度异常 zlm=" << zlm
                                       << " stream=" << sid
                                       << " 降级到" << fallback;
                            emit healthDegraded(sid, reason, fallback);
                            switchStream(sid, fallback);
                        }
                    }
                }
            }
        },
        [this](int code, QString msg) {
            qWarning() << "[StreamingController] 健康巡检失败:" << code << msg;
        });
}

QString StreamingController::pickFallbackProtocol(const QString& currentProtocol, const QString& streamId) const {
    Q_UNUSED(streamId);
    // 降级链: rtsp > ws-flv > flv > hls > webrtc
    // 例如当前是 rtsp, 返回 ws-flv (下一步)
    int idx = -1;
    int n = sizeof(kDegradationChain) / sizeof(kDegradationChain[0]);
    for (int i = 0; i < n; i++) {
        if (QString::fromLatin1(kDegradationChain[i]) == currentProtocol) { idx = i; break; }
    }
    if (idx < 0 || idx >= n - 1) return QString();  // 已在最末位 (webrtc) 或未知
    return QString::fromLatin1(kDegradationChain[idx + 1]);
}

void StreamingController::startStream(const QString& streamId) {
    m_api->post(QString("/api/v1/streams/%1/start").arg(streamId),
                QJsonObject(),
        [this, streamId](QJsonObject) {
            emit streamStarted(streamId);
            refreshStreams();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::stopStream(const QString& streamId) {
    m_api->post(QString("/api/v1/streams/%1/stop").arg(streamId),
                QJsonObject(),
        [this, streamId](QJsonObject) {
            emit streamStopped(streamId);
            refreshStreams();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::switchStream(const QString& streamId, const QString& protocol) {
    QJsonObject body; body["protocol"] = protocol;
    m_api->post(QString("/api/v1/streams/%1/switch").arg(streamId), body,
        [this](QJsonObject) { refreshStreams(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::setStreamQuality(const QString& streamId, const QString& quality) {
    QJsonObject body; body["quality"] = quality;
    m_api->post(QString("/api/v1/streams/%1/quality").arg(streamId), body,
        [this](QJsonObject) { refreshStreams(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::takeSnapshot(const QString& channelId) {
    m_api->post(QString("/api/v1/channels/%1/snapshot").arg(channelId),
                QJsonObject(),
        [this, channelId](QJsonObject obj) {
            // 后端响应: {code,message,data:{url/snapshot_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            if (url.isEmpty()) url = data.value("snapshot_url").toString();
            emit snapshotTaken(channelId, url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

// [FIX 2026-09-21 P0-A] 原 QString("...").arg(streamId) 中 URL 无 %1 占位符,
//   .arg() 为无效调用(静默返回原串)。后端 POST /api/v1/zlm/webrtc/play 为
//   占位 SDP stub(RestApiHandlers.cpp:28074, 勿作为 WebRTC 播放依据);
//   真实 WebRTC 播放链路 = WebRtcClient 直连 ZLM WHEP
//   (WebRtcClient.h:9, POST /index/api/webrtc?app=<app>&stream=<id>&type=play)。
//   本方法保留 REST 触发语义, streamId 改经 body 传递。
void StreamingController::startWebRtcPlay(const QString& streamId) {
    m_api->post("/api/v1/zlm/webrtc/play",
                QJsonObject{{"stream_id", streamId}},
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::stopZlmStream(const QString& streamId) {
    QJsonObject body; body["stream_id"] = streamId;
    m_api->post("/api/v1/zlm/stream/stop", body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::addProxy(const QString& srcUrl, const QString& dstKey) {
    QJsonObject body; body["src_url"] = srcUrl; body["dst_key"] = dstKey;
    m_api->post("/api/v1/zlm/proxy/add", body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::getStreamUrls(const QString& streamId) {
    m_api->get(QString("/api/v1/streams/%1/multi-urls").arg(streamId),
        [this, streamId](QJsonObject obj) {
            // 后端响应: {code,message,data:{rtsp,hls,webrtc,flv,...}}
            QJsonObject data = ApiClient::unwrapData(obj);
            emit urlsReceived(streamId, data.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

// [FIX v7.6 2026-08-26] WS stream_event 订阅 — 推流状态变化主动通知
// payload 形态: {event: "started"|"stopped"|"fault"|"transcoded"|"no_reader",
//                  stream_id, channel_id, app, stream, schema, code, msg}
// 参考 后端 wsAdapter.pushStreamEvent (StreamingService/BootServerKeepService)
void StreamingController::onStreamEventReceived(const QJsonObject& payload) {
    QString event    = payload.value("event").toString();
    QString streamId = payload.value("stream_id").toString();
    if (streamId.isEmpty()) streamId = payload.value("streamId").toString();
    QString chId     = payload.value("channel_id").toString();
    if (chId.isEmpty()) chId = payload.value("channelId").toString();
    qInfo() << "[StreamingController] stream_event event=" << event
            << "streamId=" << streamId << "channelId=" << chId;

    if (event == "started") {
        emit streamStarted(streamId);
        // 推流完成 → 全量刷新确保 UI 拿到最新 URL
        refreshStreams();
    } else if (event == "stopped") {
        emit streamStopped(streamId);
    } else if (event == "fault" || event == "transcoded" || event == "no_reader") {
        // 故障/转码完成/无人拉流 → 刷新状态 + 重新查询健康度
        refreshStreamHealth();
        if (event == "fault") {
            int code = payload.value("code").toInt(500);
            QString msg = payload.value("msg").toString("stream fault");
            qWarning() << "[StreamingController] stream fault:" << msg;
            emit errorOccurred(code, msg);
        }
    } else {
        // 未知事件类型 — 刷新走兜底
        refreshStreams();
    }
}