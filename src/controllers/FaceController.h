#pragma once

/**
 * @file FaceController.h
 * @brief 人脸库管理 Controller（统计/记录CRUD/批量/导入导出/告警/通行）
 *
 * 对齐后端端点（与 web-admin/src/api/face.ts 完全一致）：
 *   GET    /face/database/stats
 *   GET    /face/database/records?group_type=&search=&page=&page_size=
 *   GET    /face/database/records/:personId
 *   POST   /face/database/records
 *   PUT    /face/database/records/:personId
 *   DELETE /face/database/records/:personId
 *   POST   /face/database/records/batch
 *   DELETE /face/database/groups/:groupType
 *   POST   /face/database/upload          (multipart, 暂走 JSON)
 *   POST   /face/database/match
 *   GET    /face/database/alarms
 *   GET    /face/database/pass-records
 *   GET    /face/database/export
 *   POST   /face/database/import
 *   POST   /face/database/cleanup
 *
 * 对标: 海康 iVMS-8700 人脸库管理 / 大华 DSS 智能分析 / web-admin FaceDatabaseView.vue
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class FaceController : public QObject {
    Q_OBJECT

    // ── 统计数据 ──
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY statsUpdated)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY statsUpdated)
    Q_PROPERTY(int blacklistCount READ blacklistCount NOTIFY statsUpdated)
    Q_PROPERTY(int whitelistCount READ whitelistCount NOTIFY statsUpdated)
    Q_PROPERTY(int visitorCount READ visitorCount NOTIFY statsUpdated)

    // ── 记录列表 ──
    Q_PROPERTY(QVariantList records READ records NOTIFY recordsUpdated)
    Q_PROPERTY(int total READ total NOTIFY recordsUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

    // ── 告警 / 通行 ──
    Q_PROPERTY(QVariantList faceAlarms READ faceAlarms NOTIFY alarmsUpdated)
    Q_PROPERTY(QVariantList passRecords READ passRecords NOTIFY passRecordsUpdated)

public:
    explicit FaceController(ApiClient* api, QObject* parent = nullptr);

    // ── Getters ──
    QVariantMap stats() const { return m_stats; }
    int totalCount() const { return m_stats.value("total", 0).toInt(); }
    int blacklistCount() const { return m_stats.value("blacklist", 0).toInt(); }
    int whitelistCount() const { return m_stats.value("whitelist", 0).toInt(); }
    int visitorCount() const { return m_stats.value("visitor", 0).toInt(); }

    QVariantList records() const { return m_records; }
    int total() const { return m_total; }
    bool loading() const { return m_loading; }

    QVariantList faceAlarms() const { return m_alarms; }
    QVariantList passRecords() const { return m_passRecords; }

    // ── Q_INVOKABLE API (对标 face.ts) ──

    /** 刷新统计数据 */
    Q_INVOKABLE void refreshStats();

    /**
     * 查询人脸记录列表
     * @param groupType "blacklist"|"whitelist"|"visitor"|""
     * @param search 搜索关键词 (姓名/手机号)
     * @param page 页码 (1-based)
     * @param pageSize 每页条数
     */
    Q_INVOKABLE void refreshRecords(const QString& groupType = "",
                                     const QString& search = "",
                                     int page = 1, int pageSize = 50);

    /** 添加人脸记录 */
    Q_INVOKABLE void addRecord(const QVariantMap& data);

    /** 更新人脸记录 */
    Q_INVOKABLE void updateRecord(const QString& personId, const QVariantMap& data);

    /** 删除人脸记录 */
    Q_INVOKABLE void deleteRecord(const QString& personId);

    /** 批量添加 */
    Q_INVOKABLE void batchAdd(const QVariantList& recordsData);

    /** 清空指定分组 */
    Q_INVOKABLE void clearGroup(const QString& groupType);

    /** 人脸比对 (embedding + topK) */
    Q_INVOKABLE void matchFace(const QVariantList& embedding, int topK = 5);

    /** 刷新人脸告警 */
    Q_INVOKABLE void refreshAlarms(qint64 since = 0, int limit = 100);

    /** 刷新通行记录 */
    Q_INVOKABLE void refreshPassRecords(int hours = 24, int limit = 100);

    /** 导出人脸库 */
    Q_INVOKABLE void exportDatabase();

    /** 导入人脸库 */
    Q_INVOKABLE void importDatabase(const QString& jsonData);

    /** 清理过期访客 */
    Q_INVOKABLE void cleanupExpired();

signals:
    void statsUpdated();
    void recordsUpdated();
    void loadingChanged();
    void alarmsUpdated();
    void passRecordsUpdated();

    void recordAdded(const QString& personId);
    void recordUpdated(const QString& personId);
    void recordDeleted(const QString& personId);
    void batchAdded(int added, int total);
    void groupCleared(const QString& groupType, int deleted);
    void matchResult(const QVariantList& matches);
    void exportReady(const QString& jsonData);
    void importDone(int imported);
    void cleanupDone(int disabled);
    void errorOccurred(int code, const QString& message);

private:
    void setLoading(bool v);

    ApiClient* m_api;
    QVariantMap m_stats;
    QVariantList m_records;
    QVariantList m_alarms;
    QVariantList m_passRecords;
    int m_total = 0;
    bool m_loading = false;
};
