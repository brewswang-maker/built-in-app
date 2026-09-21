#include "RecordingController.h"
#include "utils/ApiClient.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>
#include <QDateTime>
#include <QTimer>

RecordingController::RecordingController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void RecordingController::setLoading(bool v) {
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

void RecordingController::query(const QVariantMap& filter) {
    setLoading(true);
    m_api->post("/api/v1/recordings/query",
                QJsonObject::fromVariantMap(filter),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/recordings:[...],total: N}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "recordings" });
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

// [V4-X2 2026-07-08] AI 标签智能检索 — POST /api/v1/recordings/smart-search
//  filter.ai_tag  → 转 target_type (后端从 metadata.class_name 提取)
//  filter.min_confidence / date / channel 透传
void RecordingController::querySmart(const QVariantMap& filter) {
    setLoading(true);
    QJsonObject body = QJsonObject::fromVariantMap(filter);
    // 客户端字段名 ai_tag → 后端字段名 target_type (语义对齐 web-admin)
    if (body.contains("ai_tag") && !body.value("ai_tag").toString().isEmpty()) {
        body["target_type"] = body.value("ai_tag");
    }
    // channel 字段 → channel_id
    if (body.contains("channel") && !body.value("channel").toString().isEmpty()) {
        body["channel_id"] = body.value("channel");
    }
    // date (YYYY-MM-DD) → start_time / end_time (YYYY-MM-DDT00:00:00 / T23:59:59)
    if (body.contains("date") && body.value("date").isString()) {
        QString d = body.value("date").toString();
        if (d.length() == 10 && d[4] == '-' && d[7] == '-') {
            body["start_time"] = d + QStringLiteral("T00:00:00");
            body["end_time"]   = d + QStringLiteral("T23:59:59");
        }
    }
    m_api->post("/api/v1/recordings/smart-search", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("results").toArray();
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

// [V4-X2 2026-07-08] 获取 AI 标签可选值 — GET /api/v1/recordings/smart-search/target-types
//  用于 UI 下拉框初始化
void RecordingController::refreshTargetTypes() {
    m_api->get("/api/v1/recordings/smart-search/target-types",
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("target_types").toArray();
            m_targetTypes.clear();
            for (const auto& v : arr) m_targetTypes.append(v.toString());
            // 即使空也更新, 清空下拉框
            if (m_targetTypes.isEmpty()) m_targetTypes.append(QStringLiteral("person"));
            emit targetTypesUpdated();
        },
        [this](int /*code*/, QString /*msg*/) {
            // 失败时使用默认值, 不阻塞 UI
            if (m_targetTypes.isEmpty()) m_targetTypes.append(QStringLiteral("person"));
            emit targetTypesUpdated();
        });
}

void RecordingController::refreshRecordings(int page, int pageSize) {
    setLoading(true);
    QString path = QString("/api/v1/recordings?page=%1&pageSize=%2").arg(page).arg(pageSize);
    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/recordings:[...],total:N}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "recordings"});
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void RecordingController::refreshStorage() {
    m_api->get("/api/v1/system/info",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{storage:{...}}}
            QJsonObject data = ApiClient::unwrapData(obj);
            m_storageInfo = data.value("storage").toObject().toVariantMap();
            emit storageInfoUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::play(const QString& recordingId, double startTs) {
    QJsonObject body;
    body["recording_id"] = recordingId;
    body["start_time"] = startTs;
    m_api->post(QString("/api/v1/recordings/%1/play").arg(recordingId), body,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{call_id,urls/stream_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString callId = data.value("call_id").toString();
            emit playStarted(callId, data.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::stop(const QString& recordingId) {
    m_api->post(QString("/api/v1/recordings/%1/stop").arg(recordingId),
                QJsonObject(),
        [this, recordingId](QJsonObject) { emit playStopped(recordingId); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::seek(const QString& callId, double timestamp) {
    QJsonObject body; body["timestamp"] = timestamp;
    m_api->post(QString("/api/v1/recordings/%1/seek").arg(callId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::control(const QString& callId, const QString& action) {
    QJsonObject body; body["action"] = action;
    m_api->post(QString("/api/v1/recordings/%1/control").arg(callId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::startRecord(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/start").arg(channelId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::stopRecord(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/stop").arg(channelId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::download(const QString& recordingId) {
    m_api->get(QString("/api/v1/recordings/%1/download").arg(recordingId),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{url/download_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            emit downloadReady(url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::batchDownload(const QVariantList& recordingIds) {
    QJsonObject body;
    QJsonArray arr;
    for (const auto& v : recordingIds) arr.append(v.toString());
    body["recording_ids"] = arr;
    m_api->post("/api/v1/recordings/download", body,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{url/download_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            emit downloadReady(url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::addTag(const QString& recordingId, const QString& tag) {
    // 标签与录像的关联通过 metadata 更新实现
    QJsonObject body;
    QJsonObject meta;
    meta["tag"] = tag;
    body["metadata"] = meta;
    m_api->put(QString("/api/v1/recordings/%1").arg(recordingId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::deleteRecording(const QString& recordingId) {
    m_api->del(QString("/api/v1/recordings/%1").arg(recordingId),
        [this]() { refreshRecordings(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

// [P2-#13 v7.6+] MP4 导出:
//   步骤 1: 获取 download_url
//     - ZLM 切片 id (磁盘绝对路径含 '/') → GET /api/v1/recordings/download-file?path=<urlencoded>
//     - 设备端录像 id (无 '/') → GET /api/v1/recordings/:id/download (兼容入口返回 400 中文引导)
//   步骤 2: 用 ApiClient.downloadToFile 把 url 内容流式落盘到 localPath
//   与 Web 端 ExportClipButton 行为对齐 (下载进度 + 完成提示)
// [P2-1 2026-09-20] 修正第一步路径 (对齐 Web [FIX rec-dl 2026-09-11]): 原实现固定
//   走 /recordings/:id/download, 但 ZLM 切片 id 为磁盘路径 (多级含 '/'),
//   Drogon 路由 :id 单段不匹配 → 恒 404; 改走 query 形态主入口 download-file?path=。
void RecordingController::exportClip(const QString& recordingId, const QString& localPath) {
    // [P2-1] 文件名取 basename: 磁盘路径 id 避免在 ~/Downloads 下复刻深层目录
    QString baseName = recordingId;
    const int slashPos = baseName.lastIndexOf(QLatin1Char('/'));
    if (slashPos >= 0) baseName = baseName.mid(slashPos + 1);
    if (baseName.isEmpty()) baseName = QStringLiteral("clip");

    // 计算默认本地路径
    QString path = localPath;
    if (path.isEmpty()) {
        QString dlDir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        if (dlDir.isEmpty()) dlDir = QDir::homePath() + "/Downloads";
        QDir().mkpath(dlDir);
        path = dlDir + "/" + baseName;
        if (!path.endsWith(QStringLiteral(".mp4"), Qt::CaseInsensitive))
            path += QStringLiteral(".mp4");
    }

    // [P2-1 2026-09-20] 按 id 形态选择入口:
    //   - ZLM 切片 (含 '/') → download-file?path= (主入口, query 形态)
    //   - 设备端 id (无 '/') → /:id/download 兼容入口 (返回 400 中文引导 NVR 下载任务)
    QString endpoint;
    if (recordingId.contains(QLatin1Char('/'))) {
        endpoint = QStringLiteral("/api/v1/recordings/download-file?path=%1")
                       .arg(QString::fromLatin1(QUrl::toPercentEncoding(recordingId)));
    } else {
        endpoint = QStringLiteral("/api/v1/recordings/%1/download").arg(recordingId);
    }

    auto self = this;
    m_api->get(endpoint,
        [self, recordingId, path](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            if (url.isEmpty()) url = data.value("download_url").toString();
            if (url.isEmpty()) {
                emit self->exportClipFailed(recordingId, 404, "后端未返回下载 URL");
                return;
            }
            // 第二步: 流式下载到本地
            self->m_api->downloadToFile(url, path,
                [self, recordingId](qint64 received, qint64 total) {
                    emit self->exportClipProgress(recordingId, received, total);
                },
                [self, recordingId, path](qint64 bytes, const QString& finalPath) {
                    emit self->exportClipFinished(recordingId, finalPath.isEmpty() ? path : finalPath, bytes);
                },
                [self, recordingId](qint64 /*bytes*/, int httpCode, const QString& reason) {
                    emit self->exportClipFailed(recordingId, httpCode, reason);
                });
        },
        [self, recordingId](int code, QString msg) {
            emit self->exportClipFailed(recordingId, code, msg);
        });
}

// [P1-3 2026-09-20] 告警事件 ±90s 点播 (方案 A: export-range-async 复用, 零 ffmpeg 新代码)
//   链路: POST /api/v1/recordings/export-range-async {device_id?, channel_id,
//   start_time, end_time} → task_id → 2.5s 轮询 GET /api/v1/recordings/export-range-status
//   → status=done 后取 download_url (相对 /record/, 拼 baseUrl 绝对化) → alarmClipReady。
//   对齐 Web recording.ts exportRangeRecordingAsync: 轮询间隔 2.5s, 上限 12min;
//   区间 = 告警时刻前后各 90s (Web [FIX clip-90s 2026-09-19] 同语义)。
namespace {
constexpr int kAlarmClipPreSec = 90;                     // 事件前窗口 (s)
constexpr int kAlarmClipPostSec = 90;                    // 事件后窗口 (s)
constexpr int kAlarmClipPollMs = 2500;                   // 轮询间隔 (对齐 Web)
constexpr qint64 kAlarmClipTimeoutMs = 12 * 60 * 1000;  // 轮询上限 (对齐 Web)
}  // namespace

void RecordingController::exportAlarmClip(const QString& deviceId, const QString& channelId,
                                          const QString& alarmTimeIso) {
    if (channelId.isEmpty()) {
        emit alarmClipFailed(QStringLiteral("告警通道为空, 无法定位录像片段"));
        return;
    }
    QDateTime alarmTime = QDateTime::fromString(alarmTimeIso, QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
    if (!alarmTime.isValid())
        alarmTime = QDateTime::fromString(alarmTimeIso, Qt::ISODate);
    if (!alarmTime.isValid()) {
        emit alarmClipFailed(QStringLiteral("告警时间无效: %1").arg(alarmTimeIso));
        return;
    }
    cancelAlarmClip();  // 重复调用/切换告警: 取消在飞旧任务

    QJsonObject body;
    body["channel_id"] = channelId;
    if (!deviceId.isEmpty()) body["device_id"] = deviceId;
    body["start_time"] = alarmTime.addSecs(-kAlarmClipPreSec)
                             .toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
    body["end_time"] = alarmTime.addSecs(kAlarmClipPostSec)
                           .toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss"));

    emit alarmClipStateChanged(QStringLiteral("exporting"));
    m_api->post("/api/v1/recordings/export-range-async", body,
        [this](QJsonObject obj) {
            const QString taskId = ApiClient::unwrapData(obj).value("task_id").toString();
            if (taskId.isEmpty()) {
                emit alarmClipStateChanged(QStringLiteral("failed"));
                emit alarmClipFailed(QStringLiteral("后端未返回导出任务 id"));
                return;
            }
            m_alarmClipTaskId = taskId;
            m_alarmClipDeadlineMs = QDateTime::currentMSecsSinceEpoch() + kAlarmClipTimeoutMs;
            ensureAlarmClipTimer()->start(kAlarmClipPollMs);
        },
        [this](int code, QString msg) {
            emit alarmClipStateChanged(QStringLiteral("failed"));
            emit alarmClipFailed(QStringLiteral("提交导出任务失败 [%1]: %2").arg(code).arg(msg));
        });
}

void RecordingController::cancelAlarmClip() {
    if (m_alarmClipPollTimer) m_alarmClipPollTimer->stop();
    m_alarmClipTaskId.clear();
}

QTimer* RecordingController::ensureAlarmClipTimer() {
    if (m_alarmClipPollTimer) return m_alarmClipPollTimer;
    m_alarmClipPollTimer = new QTimer(this);
    connect(m_alarmClipPollTimer, &QTimer::timeout, this, [this]() {
        if (m_alarmClipTaskId.isEmpty()) { m_alarmClipPollTimer->stop(); return; }
        if (QDateTime::currentMSecsSinceEpoch() > m_alarmClipDeadlineMs) {
            m_alarmClipPollTimer->stop();
            m_alarmClipTaskId.clear();
            emit alarmClipStateChanged(QStringLiteral("failed"));
            emit alarmClipFailed(QStringLiteral("导出超时 (超过 12 分钟), 请稍后重试"));
            return;
        }
        const QString taskId = m_alarmClipTaskId;
        m_api->get(QStringLiteral("/api/v1/recordings/export-range-status?task_id=%1").arg(taskId),
            [this, taskId](QJsonObject obj) {
                if (taskId != m_alarmClipTaskId) return;  // 过期任务响应, 丢弃
                const QJsonObject d = ApiClient::unwrapData(obj);
                const QString st = d.value("status").toString();
                if (st == QStringLiteral("done")) {
                    m_alarmClipPollTimer->stop();
                    m_alarmClipTaskId.clear();
                    QString url = d.value("download_url").toString();
                    if (url.startsWith(QLatin1Char('/'))) url = m_api->baseUrl() + url;
                    emit alarmClipStateChanged(QStringLiteral("done"));
                    emit alarmClipReady(url, d.value("filename").toString(),
                                        static_cast<qint64>(d.value("file_size").toDouble()),
                                        d.value("segments_used").toInt());
                } else if (st == QStringLiteral("failed")) {
                    m_alarmClipPollTimer->stop();
                    m_alarmClipTaskId.clear();
                    emit alarmClipStateChanged(QStringLiteral("failed"));
                    emit alarmClipFailed(d.value("error").toString(QStringLiteral("导出任务失败")));
                }
                // running: 保持轮询
            },
            [](int, QString) {
                // 单次轮询失败不终止 (网络抖动), 由超时兜底
            });
    });
    return m_alarmClipPollTimer;
}