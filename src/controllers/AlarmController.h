#pragma once
#include <QObject>
#include <QVariantList>
#include <QTimer>
#include <QSettings>
#include <QDateTime>
#include <QHash>
#ifdef HAS_QT_WEBSOCKETS
#include <QWebSocket>
#endif

class ApiClient;
class AlarmListModel;
class WsMessageRouter;

/**
 * @brief AlarmExportFormat
 *
 * Strict enumeration of the four export formats required by the
 * data-export specification. Keep in sync with the server
 * `/api/v1/alarms/export?format=` handler. Any unknown value is
 * rejected by AlarmController::exportAlarms().
 */
class AlarmExportFormat {
    Q_GADGET
public:
    enum Value {
        Csv  = 0,
        Xlsx = 1,
        Json = 2,
        Pdf  = 3
    };
    Q_ENUM(Value)

    /// Returns the lower-case token used by the server URL.
    static QString token(Value v);
    /// Returns the canonical file extension (without the dot).
    static QString extension(Value v);
    /// Returns the MIME type for Content-Type / FileDialog filters.
    static QString mimeType(Value v);
    /// Parses a token (case insensitive) or returns -1 when unknown.
    static int parseToken(const QString& token);
};

class AlarmController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList alarms READ alarms NOTIFY alarmsUpdated)
    Q_PROPERTY(int alarmCount READ alarmCount NOTIFY alarmsUpdated)
    Q_PROPERTY(bool hasUnread READ hasUnread NOTIFY alarmsUpdated)
    Q_PROPERTY(int popupDebounceMs READ popupDebounceMs WRITE setPopupDebounceMs NOTIFY popupDebounceChanged)
    Q_PROPERTY(bool useUnifiedWs READ useUnifiedWs WRITE setUseUnifiedWs NOTIFY useUnifiedWsChanged)
    // 导出状态 (规范 P1 #11):用于 QML 进度条 / 取消按钮 / 完成后“打开文件”提示
    Q_PROPERTY(bool exporting READ exporting NOTIFY exportProgressChanged)
    Q_PROPERTY(double exportProgress READ exportProgress NOTIFY exportProgressChanged)
    Q_PROPERTY(QString exportFilePath READ exportFilePath NOTIFY exportProgressChanged)
    Q_PROPERTY(QString exportFormat READ exportFormatString NOTIFY exportProgressChanged)

public:
    explicit AlarmController(ApiClient* api, QObject* parent = nullptr);
    ~AlarmController();

    QVariantList alarms() const { return m_alarms; }
    int alarmCount() const { return m_alarms.size(); }
    bool hasUnread() const { return m_hasUnread; }

    // 弹窗防抖配置 (默认 30000ms = 30s, 参考海康威视)
    int popupDebounceMs() const;
    void setPopupDebounceMs(int ms);

    // 是否使用 WsMessageRouter 统一通道(默认 true, 推荐)
    bool useUnifiedWs() const { return m_useUnifiedWs; }
    void setUseUnifiedWs(bool v);

    void setAlarmModel(AlarmListModel* model);

    Q_INVOKABLE void refreshAlarms(int limit = 50);
    Q_INVOKABLE void confirmAlarm(const QString& alarmId);
    Q_INVOKABLE void markFalseAlarm(const QString& alarmId);
    Q_INVOKABLE void handleAlarm(const QString& alarmId, const QString& action);
    Q_INVOKABLE void connectWebSocket();
    Q_INVOKABLE void batchConfirm(const QVariantList& alarmIds);
    Q_INVOKABLE void batchFalseAlarm(const QVariantList& alarmIds);

    // 导出状态查询
    bool exporting() const { return m_exporting; }
    double exportProgress() const { return m_exportProgress; }
    QString exportFilePath() const { return m_exportFilePath; }
    QString exportFormatString() const { return m_exportFormat; }

    /// Triggers an export. The implementation calls the server's
    /// streaming endpoint `/api/v1/alarms/export?format=...` first
    /// (server stream is the canonical path per spec). If the server
    /// is unreachable AND the in-memory cache holds <= 5000 entries,
    /// falls back to the local CSV generator. Otherwise surfaces the
    /// error through exportFailed().
    ///
    /// @p format    One of "csv" / "xlsx" / "json" / "pdf"
    ///              (case-insensitive, validated).
    /// @p filter    Optional QVariantMap of query params (level,
    ///              type, status, start, end, channel, etc.).
    /// @p destDir   Override destination directory. Defaults to
    ///              QStandardPaths::DocumentsLocation / "ShieldBox".
    Q_INVOKABLE void exportAlarms(const QString& format,
                                  const QVariantMap& filter = {},
                                  const QString& destDir = QString());

    /// Cancels an in-flight export started by exportAlarms().
    Q_INVOKABLE void cancelExport();

    /// Returns the four supported export tokens. Used by QML to build
    /// the format picker ComboBox.
    Q_INVOKABLE QStringList supportedExportFormats() const;

    /// Returns "DocumentsLocation/ShieldBox" by default. Public so
    /// QML can pre-fill the "open folder" toast after success.
    Q_INVOKABLE QString defaultExportDir() const;

signals:
    void alarmsUpdated();
    void newAlarm(const QVariantMap& alarm);
    void suppressedAlarm(const QVariantMap& alarm);
    void errorOccurred(int code, const QString& message);
    void popupDebounceChanged();
    void useUnifiedWsChanged();

    // 导出进度 / 完成 / 失败 / 取消 (规范 P1 #11)
    void exportProgressChanged();
    void exportStarted(const QString& format, const QString& filePath);
    void exportSucceeded(const QString& format, const QString& filePath,
                         qint64 bytes);
    void exportFailed(const QString& format, int code, const QString& message);
    void exportCancelled();

private slots:
    // 旧路径: 直接 WS 消息处理 (向后兼容)
    void onWsTextMessage(const QString& message);
    // 新路径: 通过 WsMessageRouter 接收的 alarm 消息
    void onUnifiedAlarmReceived(const QJsonObject& payload);
    void flushPendingUI();

private:
    ApiClient* m_api;
    AlarmListModel* m_alarmModel = nullptr;
    QVariantList m_alarms;
    bool m_hasUnread = false;
    bool m_useUnifiedWs = true;
    void* m_ws = nullptr;  // QWebSocket* when HAS_QT_WEBSOCKETS (旧路径)
    WsMessageRouter* m_router = nullptr;  // 新路径
    QTimer* m_flushTimer = nullptr;
    bool m_hasPendingAlarms = false;  // [FIX 2026-07-09] flushPendingUI 只在新消息到达时才触发
    QVariantList m_pendingAlarms;     // [FIX 2026-07-09] 500ms 批量合并的 pending 队列
    QSettings m_settings;

    // 弹窗防抖: key = "channelId:alarmType" → last popup timestamp
    QMap<QString, qint64> m_lastPopupMs;
    // [SSOT R11 2026-09-12] 双帧去重: alarm_id → last popup timestamp
    //  (linkage_alarm 与 alarm.new 同告警双帧防双弹; 空 id 不参与)
    QHash<QString, qint64> m_recentPopupAlarms;

    // 内部处理告警(两个路径共用)
    void ingestAlarm(const QJsonObject& alarmJson);

    // 导出内部状态
    void exportLocalCsv(const QString& filePath);
    void resetExportState();
    qint64 m_exportToken = 0;
    bool m_exporting = false;
    double m_exportProgress = 0.0;
    QString m_exportFilePath;
    QString m_exportFormat;
};
