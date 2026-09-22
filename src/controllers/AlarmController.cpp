#include "AlarmController.h"
#include "models/AlarmListModel.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
#include "utils/AlarmVerdictConsumer.h"  // [SSOT R10 2026-09-12] 单判定源消费 (弹窗三态)
#include <QJsonDocument>
#include <QStandardPaths>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QDateTime>
#include <QUrl>
#include <QUrlQuery>
#ifdef HAS_QT_WEBSOCKETS
#include <QSystemTrayIcon>
#endif

// ─────────────────────────────────────────────────────────────────────
//  AlarmExportFormat
// ─────────────────────────────────────────────────────────────────────

QString AlarmExportFormat::token(Value v) {
    switch (v) {
        case Csv:  return QStringLiteral("csv");
        case Xlsx: return QStringLiteral("xlsx");
        case Json: return QStringLiteral("json");
        case Pdf:  return QStringLiteral("pdf");
    }
    return QStringLiteral("csv");
}

QString AlarmExportFormat::extension(Value v) {
    switch (v) {
        case Csv:  return QStringLiteral("csv");
        case Xlsx: return QStringLiteral("xlsx");
        case Json: return QStringLiteral("json");
        case Pdf:  return QStringLiteral("pdf");
    }
    return QStringLiteral("bin");
}

QString AlarmExportFormat::mimeType(Value v) {
    switch (v) {
        case Csv:  return QStringLiteral("text/csv");
        case Xlsx: return QStringLiteral(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        case Json: return QStringLiteral("application/json");
        case Pdf:  return QStringLiteral("application/pdf");
    }
    return QStringLiteral("application/octet-stream");
}

int AlarmExportFormat::parseToken(const QString& token) {
    const QString t = token.trimmed().toLower();
    if (t == QLatin1String("csv"))  return int(Csv);
    if (t == QLatin1String("xlsx")) return int(Xlsx);
    if (t == QLatin1String("json")) return int(Json);
    if (t == QLatin1String("pdf"))  return int(Pdf);
    return -1;
}

AlarmController::AlarmController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api), m_settings("SmartGateWay", "AlarmSettings") {
    // 统一 WS 通道: 订阅 WsMessageRouter.alarmReceived 信号
    // [P2-B2 修复 2026-06-28] 双 WS 通道整合。
    //   原设计同时存在 m_router (统一通道) 和 m_ws (独立连接), main.qml:86 会调
    //   alarmController.connectWebSocket() 启动独立连接,导致同一条告警可能走两个 WS 收到两次。
    //   修复: 连接统一通道后,默认不再启动独立 WS (默认 m_useUnifiedWs=true 且 connectWebSocket
    //   被禁用);保留 connectWebSocket() 方法供开发者调试使用 (e.g., 怀疑统一通道问题时回归独立 WS)。
    //   对标海康 iVMS-8700: 单一通道,所有事件统一分发。
    if (m_useUnifiedWs) {
        m_router = WsMessageRouter::instance();
        if (m_router) {
            QObject::connect(m_router, &WsMessageRouter::alarmReceived,
                             this, &AlarmController::onUnifiedAlarmReceived);
            // [P1-5 优化 2026-08-18] 断线重连后 REST 补拉告警列表
            //   (alarm_latency_diagnosis_report.md P1-5): WS 断连窗口内的
            //   alarm.new 推送会丢失, 重连成功后 refreshAlarms 全量拉最新 50 条兑底。
            QObject::connect(m_router, &WsMessageRouter::reconnected, this, [this]() {
                qInfo() << "[AlarmController] [P1-5] WS reconnected — refreshAlarms catch-up";
                refreshAlarms(50);
            });
            qInfo() << "[AlarmController] [P2-B2] Using unified WS channel (recommended), independent connectWebSocket() ignored";
            return;
        }
        qWarning() << "[AlarmController] [P2-B2] WsMessageRouter not available, fallback to independent WS";
    }

#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
        m_ws = nullptr;
    }
    QString wsUrl = m_api->property("baseUrl").toString();
    wsUrl.replace("http://", "ws://").replace("https://", "wss://");
    wsUrl += "/ws";  // [FIX] DrogonWsAdapter route is /ws
    auto* ws = new QWebSocket();
    m_ws = ws;
    connect(ws, &QWebSocket::textMessageReceived,
            this, &AlarmController::onWsTextMessage);
    ws->open(QUrl(wsUrl));
    qInfo() << "[AlarmController] [P2-B2] Independent WS channel started (debug mode)";
#endif
}

void AlarmController::setUseUnifiedWs(bool v) {
    if (m_useUnifiedWs != v) {
        m_useUnifiedWs = v;
        emit useUnifiedWsChanged();
    }
}

int AlarmController::popupDebounceMs() const {
    return m_settings.value("popupDebounceMs", 30000).toInt();
}

void AlarmController::setPopupDebounceMs(int ms) {
    if (ms < 0) ms = 0;
    if (ms != popupDebounceMs()) {
        m_settings.setValue("popupDebounceMs", ms);
        emit popupDebounceChanged();
    }
}

AlarmController::~AlarmController() {
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
    }
#endif
}

void AlarmController::setAlarmModel(AlarmListModel* model) {
    m_alarmModel = model;
}

void AlarmController::refreshAlarms(int limit) {
    m_api->getList(QString("/api/v1/alarms?limit=%1").arg(limit),
        [this](QJsonArray arr) {
            m_alarms.clear();
            for (const auto& item : arr) {
                QVariantMap m = item.toVariant().toMap();
                // [FIX v7.4] snake_case → camelCase 兼容 (对齐 Web SituationAlarmStream)
                //   后端 /api/v1/alarms 返回字段是 snapshot_url/stream_url/channel_id/device_name
                //   不转换会导致 DashboardView.qml _snapshot 读不到缩略图, 拼接 'continuous://' 等
                if (m.contains("snapshot_url") && !m.contains("snapshotUrl"))
                    m["snapshotUrl"] = m["snapshot_url"];
                if (m.contains("channel_id") && !m.contains("channelId"))
                    m["channelId"] = m["channel_id"];
                if (m.contains("device_name") && !m.contains("deviceName"))
                    m["deviceName"] = m["device_name"];
                if (m.contains("alarm_type") && !m.contains("type"))
                    m["type"] = m["alarm_type"];
                m_alarms.append(m);
            }
            m_hasUnread = false;
            for (const auto& a : m_alarms) {
                QString st = a.toMap().value("status").toString();
                if (st == "unhandled" || st == "pending") {
                    m_hasUnread = true;
                    break;
                }
            }
            emit alarmsUpdated();
            if (m_alarmModel)
                m_alarmModel->setAlarms(m_alarms);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::confirmAlarm(const QString& alarmId) {
    // [FIX api-contract 2026-09-22] 契约纠正: 后端无 /alarms/:id/confirm 路由,
    // canonical = POST /api/v1/alarms/confirm {alarm_id,handler}(含反馈入库)。
    QJsonObject body;
    body["alarm_id"] = alarmId;
    body["handler"] = "gui";
    m_api->post("/api/v1/alarms/confirm", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::markFalseAlarm(const QString& alarmId) {
    // [FIX api-contract 2026-09-22] 同理: POST /api/v1/alarms/false {alarm_id,handler,note}
    // (含误报热点记录 recordMisreportHotspot)。
    QJsonObject body;
    body["alarm_id"] = alarmId;
    body["handler"] = "gui";
    m_api->post("/api/v1/alarms/false", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::handleAlarm(const QString& alarmId, const QString& action) {
    // [FIX api-contract 2026-09-22] 后端 handle 路由为 PUT(非 POST),
    // body action/status 双兼容。
    QJsonObject body;
    body["action"] = action;
    m_api->put(QString("/api/v1/alarms/%1/handle").arg(alarmId), body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::connectWebSocket() {
    // [FIX 2026-06-28] 统一WS通道启用时跳过独立连接, 避免双通道重复收告警
    if (m_useUnifiedWs && m_router) {
        qInfo() << "[AlarmController] unified WS active, connectWebSocket() skipped";
        return;
    }
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
        m_ws = nullptr;
    }
    QString wsUrl = m_api->property("baseUrl").toString();
    wsUrl.replace("http://", "ws://").replace("https://", "wss://");
    wsUrl += "/ws";  // [FIX] DrogonWsAdapter route is /ws
    auto* ws = new QWebSocket();
    m_ws = ws;
    connect(ws, &QWebSocket::textMessageReceived,
            this, &AlarmController::onWsTextMessage);
    ws->open(QUrl(wsUrl));
#endif
}

void AlarmController::onWsTextMessage(const QString& message) {
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QVariantMap alarm = doc.object().toVariantMap();

    // 提取通道标识用于防抖
    QString chId = alarm["channel_id_str"].toString();
    if (chId.isEmpty()) chId = alarm["channel_id"].toString();
    QString alarmType = alarm["alarm_type"].toString();

    // [FIX 2026-07-09] 收到消息入 pending 队列，500ms 后批量合并，避免每次都触发 alarmsUpdated
    m_pendingAlarms.append(alarm);
    m_hasPendingAlarms = true;

    // 防抖: 500ms 合并窗口，批量刷新 UI
    if (!m_flushTimer) {
        m_flushTimer = new QTimer(this);
        m_flushTimer->setSingleShot(true);
        connect(m_flushTimer, &QTimer::timeout, this, &AlarmController::flushPendingUI);
    }
    m_flushTimer->start(500);

    // 弹窗防抖: 同设备同类型在 N 秒内不重复弹窗
    qint64 now = QDateTime::currentDateTime().toMSecsSinceEpoch();
    QString popupKey = chId + ":" + alarmType;
    const int debounceMs = popupDebounceMs();
    // [SSOT R11 2026-09-12] 双帧去重图惰性清理 (窗口 = 防抖参数)
    AlarmVerdictConsumer::prunePopped(m_recentPopupAlarms, now, debounceMs);

    // [SSOT R10 2026-09-12] 单判定源消费 (§5.1 + §8.1 操作门第 2 点内置端对等):
    //   与 web 端 useGlobalAlarm 三态降级链同语义 — verdict 存在时以后端
    //   matchAndVerdict 为准 (matched=弹窗总闸 / debounced=后端防抖窗口);
    //   缺失 (旧后端 / verdict_push_enabled=false 回退态) 回落现状本地防抖链,
    //   零回归。红线不变: 告警已全部进列表 (上方 pending 队列), 判定只影响弹窗。
    const AlarmVerdictConsumer::Decision decision = AlarmVerdictConsumer::decide(alarm);
    if (decision == AlarmVerdictConsumer::Decision::Suppress) {
        qInfo() << "[AlarmController] [SSOT R10] popup suppressed by backend verdict"
                << "(unmatched) type:" << alarmType << "ch:" << chId;
        emit suppressedAlarm(alarm);
        return;
    }
    if (decision == AlarmVerdictConsumer::Decision::SuppressDebounced) {
        // matched 两态都更新本地防抖图 (与后端防抖图共识: 回退时兜底链窗口对齐)
        m_lastPopupMs[popupKey] = now;
        qInfo() << "[AlarmController] [SSOT R10] popup debounced by backend verdict"
                << "key:" << popupKey;
        emit suppressedAlarm(alarm);
        return;
    }
    if (decision == AlarmVerdictConsumer::Decision::Show) {
        // [SSOT R11] 双帧去重: linkage_alarm (dispatch 顺序在先, 走兜底链) 已弹同
        //   alarm_id 时, Show 不再看本地防抖 → 无此闸会同告警双弹 (列表已刷新,
        //   仅弹窗去重)。
        const QString frameAlarmId = alarm.value(QStringLiteral("alarm_id")).toString();
        if (AlarmVerdictConsumer::isRecentlyPopped(m_recentPopupAlarms, frameAlarmId,
                                                   now, debounceMs)) {
            qInfo() << "[AlarmController] [SSOT R11] popup deduped (same alarm_id already"
                    << "popped) alarm_id:" << frameAlarmId;
            emit suppressedAlarm(alarm);
            return;
        }
        m_lastPopupMs[popupKey] = now;
        // 帧富化: has_linkage / linkage_actions / auto_close_s — 单权威切换
        //   (R9) 后 WEB_POPUP 降档, 联动形态信息改从 verdict 注入, main.qml
        //   分流 (severity>=3 || has_linkage) 与 LinkageAlarmPopup 保持现状体验。
        AlarmVerdictConsumer::enrichFromVerdict(alarm);
        AlarmVerdictConsumer::recordPopped(m_recentPopupAlarms, frameAlarmId, now);
        emit newAlarm(alarm);
        return;
    }

    // Fallback: 无 verdict (旧后端 / 回退态) — 现状链逐字保留
    qint64 lastPopup = m_lastPopupMs.value(popupKey, 0);

    if (debounceMs > 0 && (now - lastPopup) < debounceMs) {
        emit suppressedAlarm(alarm);
    } else {
        // [SSOT R11] 双帧去重 (反向顺序补位: alarm.new Show 先弹 → linkage_alarm
        //   后到; 防抖图未拦住时此闸兜底)
        const QString frameAlarmId = alarm.value(QStringLiteral("alarm_id")).toString();
        if (AlarmVerdictConsumer::isRecentlyPopped(m_recentPopupAlarms, frameAlarmId,
                                                   now, debounceMs)) {
            qInfo() << "[AlarmController] [SSOT R11] popup deduped (same alarm_id already"
                    << "popped) alarm_id:" << frameAlarmId;
            emit suppressedAlarm(alarm);
            return;
        }
        m_lastPopupMs[popupKey] = now;
        AlarmVerdictConsumer::recordPopped(m_recentPopupAlarms, frameAlarmId, now);
        emit newAlarm(alarm);
    }
}

void AlarmController::flushPendingUI() {
    // [FIX 2026-07-09] 只在有新消息时触发 alarmsUpdated
    if (!m_hasPendingAlarms) return;
    m_hasPendingAlarms = false;

    // 合并 pending 队列到 m_alarms，同通道同类型去重只保留最新
    for (const QVariant& item : std::as_const(m_pendingAlarms)) {
        QVariantMap a = item.toMap();
        QString aChId = a["channel_id_str"].toString();
        if (aChId.isEmpty()) aChId = a["channel_id"].toString();
        QString aType = a["alarm_type"].toString();

        // 从 m_alarms 移除同通道同类型的旧条目
        for (int i = 0; i < m_alarms.size(); ++i) {
            QVariantMap ex = m_alarms[i].toMap();
            QString exChId = ex["channel_id_str"].toString();
            if (exChId.isEmpty()) exChId = ex["channel_id"].toString();
            if (exChId == aChId && ex["alarm_type"].toString() == aType) {
                m_alarms.removeAt(i);
                break;
            }
        }
        m_alarms.prepend(a);
    }
    m_pendingAlarms.clear();

    emit alarmsUpdated();
    if (m_alarmModel)
        m_alarmModel->setAlarms(m_alarms);
}

void AlarmController::onUnifiedAlarmReceived(const QJsonObject& payload) {
    // 统一 WS 通道入口(规范 b4ced019): 接收 WsMessageRouter::alarmReceived
    // 复用 onWsTextMessage 的去重/防抖/弹窗逻辑
    QJsonDocument doc(payload);
    onWsTextMessage(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

// ─────────────────────────────────────────────────────────────────────
//  导出 (规范 P1 #11)
// ─────────────────────────────────────────────────────────────────────

QString AlarmController::defaultExportDir() const {
    QString base = QStandardPaths::writableLocation(
        QStandardPaths::DocumentsLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/Documents");
    const QString dir = base + QStringLiteral("/ShieldBox");
    QDir().mkpath(dir);
    return dir;
}

QStringList AlarmController::supportedExportFormats() const {
    return {QStringLiteral("csv"), QStringLiteral("xlsx"),
            QStringLiteral("json"), QStringLiteral("pdf")};
}

void AlarmController::resetExportState() {
    m_exporting = false;
    m_exportProgress = 0.0;
    m_exportFilePath.clear();
    m_exportFormat.clear();
    m_exportToken = 0;
    emit exportProgressChanged();
}

void AlarmController::cancelExport() {
    if (!m_exporting) return;
    if (m_exportToken != 0 && m_api)
        m_api->cancelDownload(m_exportToken);
    m_exportToken = 0;
    emit exportCancelled();
    resetExportState();
}

void AlarmController::exportAlarms(const QString& format,
                                   const QVariantMap& filter,
                                   const QString& destDir) {
    // 1) 验证 format 枚举 (规范 6bdcc86c 严格 4 种格式)
    const int fmtIdx = AlarmExportFormat::parseToken(format);
    if (fmtIdx < 0) {
        emit exportFailed(format, -1,
            QStringLiteral("unsupported export format: %1 (must be csv/xlsx/json/pdf)")
                .arg(format));
        emit errorOccurred(-1, "unsupported export format");
        return;
    }
    const AlarmExportFormat::Value fmtValue =
        static_cast<AlarmExportFormat::Value>(fmtIdx);

    // 2) 准备目标路径
    const QString targetDir = destDir.isEmpty() ? defaultExportDir() : destDir;
    QDir().mkpath(targetDir);
    const QString ts = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    const QString fileName = QStringLiteral("alarms_%1.%2")
                                 .arg(ts)
                                 .arg(AlarmExportFormat::extension(fmtValue));
    const QString fullPath = targetDir + QLatin1Char('/') + fileName;

    // 3) 拼接查询串
    QUrl url(QStringLiteral("/api/v1/alarms/export"));
    QUrlQuery q;
    q.addQueryItem("format", AlarmExportFormat::token(fmtValue));
    for (auto it = filter.constBegin(); it != filter.constEnd(); ++it) {
        q.addQueryItem(it.key(), it.value().toString());
    }
    url.setQuery(q);

    // 4) 初始化进度状态
    m_exporting = true;
    m_exportProgress = 0.0;
    m_exportFilePath = fullPath;
    m_exportFormat = AlarmExportFormat::token(fmtValue);
    emit exportStarted(m_exportFormat, m_exportFilePath);
    emit exportProgressChanged();

    // 5) 首选服务端流式导出 (规范 6bdcc86c: 大数据量严禁客户端生成)
    m_exportToken = m_api->downloadToFile(
        url.toString(),
        fullPath,
        [this](qint64 rec, qint64 tot) {
            if (!m_exporting) return;
            m_exportProgress =
                (tot > 0) ? (double(rec) / double(tot)) : 0.5;
            // chunked 时 tot = -1,进度条转圈圈;出现任何字节都重置到 0.5
            emit exportProgressChanged();
        },
        [this](qint64 token, const QString& filePath) {
            Q_UNUSED(token);
            m_exportToken = 0;
            m_exporting = false;
            m_exportProgress = 1.0;
            QFileInfo fi(filePath);
            const qint64 sz = fi.size();
            emit exportProgressChanged();
            emit exportSucceeded(m_exportFormat, filePath, sz);
            emit alarmsUpdated();   // no-op,但让绑定重连
        },
        [this, fmtValue, fullPath](qint64 token, int code, const QString& message) {
            Q_UNUSED(token);
            m_exportToken = 0;
            // 6) 降级: 仅当本地缓存 ≤ 5000 且格式 = csv 时本地生成
            const bool canFallback =
                (fmtValue == AlarmExportFormat::Csv) &&
                (m_alarms.size() <= 5000);
            if (canFallback) {
                emit errorOccurred(0,
                    QStringLiteral("server export unavailable (%1); "
                                   "falling back to local CSV").arg(message));
                exportLocalCsv(fullPath);
                return;
            }
            m_exporting = false;
            m_exportProgress = 0.0;
            emit exportProgressChanged();
            emit exportFailed(m_exportFormat, code, message);
            emit errorOccurred(code, message);
        });
}

void AlarmController::exportLocalCsv(const QString& filePath) {
    // 本地生成仅作为离线降级路径 (规范 P1 #11)
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        m_exporting = false;
        emit exportProgressChanged();
        emit exportFailed(QStringLiteral("csv"), -1,
                          QStringLiteral("open failed: %1").arg(filePath));
        return;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "ID,Type,Level,Description,Status,Timestamp,Channel,Confidence\n";
    int total = m_alarms.size();
    int done = 0;
    for (const auto& a : m_alarms) {
        QVariantMap m = a.toMap();
        out << m["alarm_id"].toString() << ","
            << m["alarm_type"].toString() << ","
            << m["level"].toString() << ","
            << "\"" << m["description"].toString().replace("\"", "\"\"") << "\"" << ","
            << m["status"].toString() << ","
            << m["timestamp"].toString() << ","
            << m["channel_id"].toString() << ","
            << m["confidence"].toString() << "\n";
        ++done;
        if (total > 0) {
            m_exportProgress = double(done) / double(total);
            emit exportProgressChanged();
        }
    }
    file.close();
    m_exporting = false;
    m_exportProgress = 1.0;
    emit exportProgressChanged();
    emit exportSucceeded(QStringLiteral("csv"), filePath, QFileInfo(file).size());
}

void AlarmController::batchConfirm(const QVariantList& alarmIds) {
    QJsonArray ids;
    for (const auto& id : alarmIds)
        ids.append(id.toString());
    QJsonObject body;
    body["alarm_ids"] = ids;
    m_api->post("/api/v1/alarms/batch-confirm", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::batchFalseAlarm(const QVariantList& alarmIds) {
    QJsonArray ids;
    for (const auto& id : alarmIds)
        ids.append(id.toString());
    QJsonObject body;
    body["alarm_ids"] = ids;
    m_api->post("/api/v1/alarms/batch-false", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
