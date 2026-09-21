#pragma once
/**
 * @file RecordingController.h
 * @brief 录像管理 Controller（查询/回放/下载/标签）
 *
 * 对齐后端端点：
 *   - GET    /api/v1/recordings
 *   - POST   /api/v1/recordings/query
 *   - POST   /api/v1/recordings/:id/play
 *   - POST   /api/v1/recordings/:id/stop
 *   - POST   /api/v1/recordings/:id/control
 *   - GET    /api/v1/recordings/:id/download
 *   - GET    /api/v1/recordings/download-file    (主入口, ZLM 磁盘路径 id)
 *   - POST   /api/v1/recordings/export-range-async   ([P1-3] 告警 ±90s 点播)
 *   - GET    /api/v1/recordings/export-range-status  ([P1-3] 导出任务轮询)
 *   - DELETE /api/v1/recordings/:id
 *   - POST   /api/v1/recordings/download
 *   - POST   /api/v1/recordings/download/:callId/stop
 *   - POST   /api/v1/recordings/:callId/seek
 *   - POST   /api/v1/recording/:id/start
 *   - POST   /api/v1/recording/:id/stop
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;
class QTimer;

class RecordingController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList recordings READ recordings NOTIFY recordingsUpdated)
    Q_PROPERTY(QVariantMap storageInfo READ storageInfo NOTIFY storageInfoUpdated)
    Q_PROPERTY(int total READ total NOTIFY recordingsUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit RecordingController(ApiClient* api, QObject* parent = nullptr);

    QVariantList recordings() const { return m_recordings; }
    QVariantMap storageInfo() const { return m_storageInfo; }
    int total() const { return m_total; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void query(const QVariantMap& filter);
    /// [V4-X2 2026-07-08] AI 标签智能检索 (透传到后端 smart-search 端点)
    ///  filter.ai_tag  → 转为 target_type (class_name 匹配)
    ///  filter.min_confidence → 透传
    ///  filter.date/start_time/end_time → 透传
    Q_INVOKABLE void querySmart(const QVariantMap& filter);
    /// [V4-X2 2026-07-08] 获取 AI 标签可选值 (人/车/狗/...) 供 UI 下拉
    Q_INVOKABLE void refreshTargetTypes();
    Q_PROPERTY(QVariantList targetTypes READ targetTypes NOTIFY targetTypesUpdated)
    QVariantList targetTypes() const { return m_targetTypes; }
    Q_INVOKABLE void refreshRecordings(int page = 1, int pageSize = 50);
    Q_INVOKABLE void refreshStorage();
    Q_INVOKABLE void play(const QString& recordingId, double startTs);
    Q_INVOKABLE void stop(const QString& recordingId);
    Q_INVOKABLE void seek(const QString& callId, double timestamp);
    Q_INVOKABLE void control(const QString& callId, const QString& action);
    Q_INVOKABLE void startRecord(const QString& channelId);
    Q_INVOKABLE void stopRecord(const QString& channelId);
    Q_INVOKABLE void download(const QString& recordingId);
    Q_INVOKABLE void batchDownload(const QVariantList& recordingIds);
    // [P2-#13 v7.6+] MP4 下载: 通过 GET /api/v1/recordings/:id/download 拿 url, 再用 ApiClient.downloadToFile 落盘
    //  localPath 为本地绝对路径, 空则使用 QStandardPaths::DownloadLocation/<recordingId>.mp4
    Q_INVOKABLE void exportClip(const QString& recordingId, const QString& localPath = QString());
    // [P1-3 2026-09-20] 告警事件 ±90s 点播 (方案 A: export-range-async 复用, 零 ffmpeg 新代码):
    //   alarmTimeIso "yyyy-MM-ddTHH:mm:ss" (本地时区, QML 侧构造) → 提交异步导出任务
    //   → 2.5s 轮询 /export-range-status → alarmClipReady(url 已绝对化, 可直接播放)。
    //   对齐 Web RecordingView.vue exportAndDownloadRange + [FIX clip-90s 2026-09-19]
    //   事件前后各 90s 语义; 重复调用自动取消旧任务。
    Q_INVOKABLE void exportAlarmClip(const QString& deviceId, const QString& channelId,
                                     const QString& alarmTimeIso);
    /// [P1-3] 取消在飞事件回放导出任务 (弹窗关闭 / 切换告警时调用)
    Q_INVOKABLE void cancelAlarmClip();
    Q_INVOKABLE void addTag(const QString& recordingId, const QString& tag);
    Q_INVOKABLE void deleteRecording(const QString& recordingId);

signals:
    void recordingsUpdated();
    void storageInfoUpdated();
    void loadingChanged();
    void playStarted(const QString& callId, const QVariantMap& urls);
    void playStopped(const QString& recordingId);
    void downloadReady(const QString& url);
    void targetTypesUpdated();
    void errorOccurred(int code, const QString& message);
    // [P2-#13 v7.6+] MP4 导出进度 / 完成 / 失败
    void exportClipProgress(const QString& recordingId, qint64 received, qint64 total);
    void exportClipFinished(const QString& recordingId, const QString& localPath, qint64 bytes);
    void exportClipFailed(const QString& recordingId, int code, const QString& reason);
    // [P1-3 2026-09-20] 事件回放 (±90s) 状态: exporting | done | failed | idle
    void alarmClipStateChanged(const QString& state);
    void alarmClipReady(const QString& url, const QString& filename, qint64 fileSize, int segments);
    void alarmClipFailed(const QString& reason);

private:
    void setLoading(bool v);
    /// [P1-3] 懒创建导出状态轮询定时器 (2.5s, 上限 12min — 对齐 Web recording.ts)
    QTimer* ensureAlarmClipTimer();

    ApiClient* m_api;
    QVariantList m_recordings;
    QVariantMap m_storageInfo;
    QVariantList m_targetTypes;  ///< [V4-X2 2026-07-08] AI 标签可选值
    int m_total = 0;
    bool m_loading = false;
    // [P1-3 2026-09-20] 事件回放导出任务轮询态
    QTimer* m_alarmClipPollTimer = nullptr;
    QString m_alarmClipTaskId;
    qint64 m_alarmClipDeadlineMs = 0;
};