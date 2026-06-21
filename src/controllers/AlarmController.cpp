#include "AlarmController.h"
#include "models/AlarmListModel.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
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
    m_router = WsMessageRouter::instance();
    if (m_router) {
        QObject::connect(m_router, &WsMessageRouter::alarmReceived,
                         this, &AlarmController::onUnifiedAlarmReceived);
    }
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
            for (const auto& item : arr)
                m_alarms.append(item.toVariant().toMap());
            m_hasUnread = false;
            for (const auto& a : m_alarms) {
                if (a.toMap().value("status").toString() == "unhandled") {
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
    m_api->post(QString("/api/v1/alarms/%1/confirm").arg(alarmId), QJsonObject(),
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::markFalseAlarm(const QString& alarmId) {
    m_api->post(QString("/api/v1/alarms/%1/false").arg(alarmId), QJsonObject(),
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::handleAlarm(const QString& alarmId, const QString& action) {
    QJsonObject body;
    body["action"] = action;
    m_api->post(QString("/api/v1/alarms/%1/handle").arg(alarmId), body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::connectWebSocket() {
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
        m_ws = nullptr;
    }
    QString wsUrl = m_api->property("baseUrl").toString();
    wsUrl.replace("http://", "ws://").replace("https://", "wss://");
    wsUrl += "/api/v1/alarms/stream";
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

    // 同通道同类型去重: 仅保留最新一条
    QString chId = alarm["channel_id_str"].toString();
    if (chId.isEmpty()) chId = alarm["channel_id"].toString();
    QString alarmType = alarm["alarm_type"].toString();

    for (int i = 0; i < m_alarms.size(); ++i) {
        QVariantMap existing = m_alarms[i].toMap();
        QString exCh = existing["channel_id_str"].toString();
        if (exCh.isEmpty()) exCh = existing["channel_id"].toString();
        if (exCh == chId && existing["alarm_type"].toString() == alarmType) {
            m_alarms.removeAt(i);
            break;
        }
    }

    m_hasUnread = true;
    m_alarms.prepend(alarm);

    // 防抖: 500ms 合并窗口，批量刷新 UI
    if (!m_flushTimer) {
        m_flushTimer = new QTimer(this);
        m_flushTimer->setSingleShot(true);
        connect(m_flushTimer, &QTimer::timeout, this, &AlarmController::flushPendingUI);
    }
    m_flushTimer->start(500);

    // 弹窗防抖: 同设备同类型在 N 秒内不重复弹窗 (记录但抑制弹窗)
    qint64 now = QDateTime::currentDateTime().toMSecsSinceEpoch();
    QString popupKey = chId + ":" + alarmType;
    int debounceMs = popupDebounceMs();
    qint64 lastPopup = m_lastPopupMs.value(popupKey, 0);

    if (debounceMs > 0 && (now - lastPopup) < debounceMs) {
        // 被抑制: 记录到列表但不弹窗
        emit suppressedAlarm(alarm);
    } else {
        // 弹窗
        m_lastPopupMs[popupKey] = now;
        emit newAlarm(alarm);
    }
}

void AlarmController::flushPendingUI() {
    emit alarmsUpdated();
    if (m_alarmModel)
        m_alarmModel->setAlarms(m_alarms);
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
