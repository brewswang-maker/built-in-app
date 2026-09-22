#pragma once
/**
 * @file DeviceController.h
 * @brief 设备管理 Controller（v5.1/v6.2 对齐 Web 管理台 + 规范 16323eda 设备状态枚举）
 *
 * 功能：
 *   - 列表/分页/搜索/筛选（6 种状态 + 6 种类型 + 协议/分组/标签）
 *   - 排序（name/ip/status/lastSeenAt/createdAt 升/降）
 *   - 添加/编辑/删除/详情
 *   - 批量操作（启用/禁用/删除/同步时间/分组移动）
 *   - 设备分组与标签
 *
 * 对齐后端端点：
 *   - GET    /api/v1/devices?page=&pageSize=&search=&status=&type=&protocol=&sortBy=&sortOrder=
 *   - GET    /api/v1/devices/stats
 *   - GET    /api/v1/devices/:id
 *   - GET    /api/v1/devices/:id/channels
 *   - POST   /api/v1/devices
 *   - PUT    /api/v1/devices/:id
 *   - DELETE /api/v1/devices/:id
 *   - POST   /api/v1/devices/discover
 *   - POST   /api/v1/devices/:id/reboot
 *   - POST   /api/v1/devices/:id/sync-time
 *   - POST   /api/v1/devices/:id/sync
 *   - GET    /api/v1/devices/:id/info
 *   - GET    /api/v1/devices/:id/status
 *   - GET    /api/v1/devices/:id/health
 *   - GET    /api/v1/devices/:id/device-status
 *
 * 状态枚举 (规范 16323eda):
 *   online / offline / error / maintenance / warning / unknown
 *
 * 类型枚举 (规范 16323eda):
 *   camera / sensor / gateway / nvr / dvr / actuator
 *
 * 排序字段 (规范 16323eda):
 *   name / ip / status / lastSeenAt / createdAt
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QJsonObject>

class ApiClient;
class DeviceListModel;
class WsMessageRouter;

class DeviceController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesUpdated)
    Q_PROPERTY(QVariantList filteredDevices READ filteredDevices NOTIFY filterChanged)
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsUpdated)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY statsUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int deviceCount READ deviceCount NOTIFY devicesUpdated)
    Q_PROPERTY(int onlineCount READ onlineCount NOTIFY statsUpdated)
    Q_PROPERTY(int offlineCount READ offlineCount NOTIFY statsUpdated)
    Q_PROPERTY(int alarmCount READ alarmCount NOTIFY statsUpdated)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY filterChanged)
    Q_PROPERTY(QString statusFilter READ statusFilter WRITE setStatusFilter NOTIFY filterChanged)
    Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY filterChanged)
    Q_PROPERTY(QString protocolFilter READ protocolFilter WRITE setProtocolFilter NOTIFY filterChanged)
    Q_PROPERTY(QString groupFilter READ groupFilter WRITE setGroupFilter NOTIFY filterChanged)
    Q_PROPERTY(QString sortBy READ sortBy WRITE setSortBy NOTIFY filterChanged)
    Q_PROPERTY(QString sortOrder READ sortOrder WRITE setSortOrder NOTIFY filterChanged)
    Q_PROPERTY(int page READ page WRITE setPage NOTIFY filterChanged)
    Q_PROPERTY(int pageSize READ pageSize WRITE setPageSize NOTIFY filterChanged)
    Q_PROPERTY(int total READ total NOTIFY devicesUpdated)
    Q_PROPERTY(QStringList supportedStatuses READ supportedStatuses CONSTANT)
    Q_PROPERTY(QStringList supportedTypes READ supportedTypes CONSTANT)
    Q_PROPERTY(QStringList supportedSortFields READ supportedSortFields CONSTANT)

public:
    explicit DeviceController(ApiClient* api, QObject* parent = nullptr);

    QVariantList devices() const { return m_devices; }
    QVariantList filteredDevices() const { return m_filtered; }
    QVariantList groups() const { return m_groups; }
    QVariantMap stats() const { return m_stats; }
    bool loading() const { return m_loading; }
    int deviceCount() const { return m_devices.size(); }
    int onlineCount() const { return m_stats.value("online").toInt(); }
    int offlineCount() const { return m_stats.value("offline").toInt(); }
    int alarmCount() const { return m_stats.value("alarm").toInt(); }
    QString searchText() const { return m_searchText; }
    QString statusFilter() const { return m_statusFilter; }
    QString typeFilter() const { return m_typeFilter; }
    QString protocolFilter() const { return m_protocolFilter; }
    QString groupFilter() const { return m_groupFilter; }
    QString sortBy() const { return m_sortBy; }
    QString sortOrder() const { return m_sortOrder; }
    int page() const { return m_page; }
    int pageSize() const { return m_pageSize; }
    int total() const { return m_total; }

    /** 6 种状态枚举 (规范 16323eda) */
    static QStringList supportedStatuses();
    /** 6 种类型枚举 (规范 16323eda) */
    static QStringList supportedTypes();
    /** 5 种排序字段 (规范 16323eda) */
    static QStringList supportedSortFields();

    void setDeviceModel(DeviceListModel* model);

    void setSearchText(const QString& s);
    void setStatusFilter(const QString& s);
    void setTypeFilter(const QString& s);
    void setProtocolFilter(const QString& s);
    void setGroupFilter(const QString& s);
    void setSortBy(const QString& s);
    void setSortOrder(const QString& s);
    void setPage(int p);
    void setPageSize(int p);

    /**
     * @brief 拉取设备列表(规范 16323eda: 完整查询参数)
     * @param page 页码(1-based)
     * @param pageSize 每页条数
     * @param search 关键字(name/ip/serialNumber/tags 模糊匹配)
     * @param status 6 状态之一(空 = 不限)
     * @param type 6 类型之一(空 = 不限)
     * @param protocol 协议(空 = 不限)
     * @param sortBy 排序字段(name/ip/status/lastSeenAt/createdAt, 默认 createdAt)
     * @param sortOrder asc/desc(默认 desc)
     */
    Q_INVOKABLE void refreshDevices(int page, int pageSize,
                                    const QString& search,
                                    const QString& status,
                                    const QString& type,
                                    const QString& protocol,
                                    const QString& sortBy,
                                    const QString& sortOrder);

    /** 无参便捷重载: 用当前 Q_PROPERTY 拉取(供 QML 调用) */
    Q_INVOKABLE void refreshDevices();

    /** 0 参数便捷版本, 用当前 Q_PROPERTY 拉取 */
    Q_INVOKABLE void refreshAll();

    Q_INVOKABLE void refreshStats();
    Q_INVOKABLE void refreshGroups();
    // [FIX api-contract 2026-09-22] 签名对齐 QML 表单字段(name/deviceType/location);
    // 旧签名 port/username/password 均无消费方(调用点恒传 0/空)且后端
    // POST /devices 必填 device_id(缺→400)。
    Q_INVOKABLE void addDevice(const QString& protocol, const QString& ip,
                               const QString& name, const QString& deviceType,
                               const QString& location);
    Q_INVOKABLE void updateDevice(const QString& deviceId, const QVariantMap& body);
    Q_INVOKABLE void removeDevice(const QString& deviceId);
    Q_INVOKABLE void discoverDevices(const QString& protocol);
    Q_INVOKABLE void getDeviceDetail(const QString& deviceId);
    Q_INVOKABLE void getDeviceChannels(const QString& deviceId);
    Q_INVOKABLE void getDeviceHealth(const QString& deviceId);
    Q_INVOKABLE void rebootDevice(const QString& deviceId);
    Q_INVOKABLE void syncTime(const QString& deviceId);
    Q_INVOKABLE void batchDelete(const QVariantList& deviceIds);
    Q_INVOKABLE void batchSetGroup(const QVariantList& deviceIds, const QString& groupId);
    Q_INVOKABLE void batchAddTag(const QVariantList& deviceIds, const QString& tag);
    Q_INVOKABLE void createGroup(const QString& name, const QString& description);
    Q_INVOKABLE void deleteGroup(const QString& groupId);
    Q_INVOKABLE void applyFilters();

signals:
    void devicesUpdated();
    void statsUpdated();
    void groupsUpdated();
    void filterChanged();
    void loadingChanged();
    void deviceAdded(const QString& deviceId);
    void deviceUpdated(const QString& deviceId);
    void deviceRemoved(const QString& deviceId);
    void groupCreated(const QString& groupId);
    void deviceDiscovered(const QVariantList& results);
    void deviceDetailReady(const QVariantMap& detail);
    void errorOccurred(int code, const QString& message);

private slots:
    void onDeviceStatusWsReceived(const QJsonObject& payload);

private:
    void setLoading(bool loading);
    QStringList serializeStatusFilter() const;
    QStringList serializeTypeFilter() const;

    ApiClient* m_api;
    DeviceListModel* m_deviceModel = nullptr;
    WsMessageRouter* m_wsRouter = nullptr;
    QVariantList m_devices;
    QVariantList m_filtered;
    QVariantList m_groups;
    QVariantMap m_stats;
    bool m_loading = false;
    QString m_searchText;
    QString m_statusFilter;
    QString m_typeFilter;
    QString m_protocolFilter;
    QString m_groupFilter;
    QString m_sortBy;
    QString m_sortOrder;
    int m_page = 1;
    int m_pageSize = 50;
    int m_total = 0;
};
