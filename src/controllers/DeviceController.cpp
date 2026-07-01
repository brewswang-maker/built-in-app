#include "DeviceController.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
#include "models/DeviceListModel.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <algorithm>

DeviceController::DeviceController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
    // 订阅 WsMessageRouter.device_status 实时消息
    m_wsRouter = WsMessageRouter::instance();
    if (m_wsRouter) {
        QObject::connect(m_wsRouter, &WsMessageRouter::deviceStatusReceived,
                         this, &DeviceController::onDeviceStatusWsReceived);
    }
}

// =====================================================================
// 规范 16323eda 枚举常量
// =====================================================================

QStringList DeviceController::supportedStatuses() {
    // 6 种状态: online / offline / error / maintenance / warning / unknown
    return { "online", "offline", "error", "maintenance", "warning", "unknown" };
}

QStringList DeviceController::supportedTypes() {
    // 6 种类型: camera / sensor / gateway / nvr / dvr / actuator
    return { "camera", "sensor", "gateway", "nvr", "dvr", "actuator" };
}

QStringList DeviceController::supportedSortFields() {
    // 5 种排序字段: name / ip / status / lastSeenAt / createdAt
    return { "name", "ip", "status", "lastSeenAt", "createdAt" };
}

void DeviceController::onDeviceStatusWsReceived(const QJsonObject& payload) {
    // payload: {device_id, channel_id?, status, last_seen_at?, reason?}
    QString deviceId = payload.value("device_id").toString();
    QString newStatus = payload.value("status").toString();
    if (deviceId.isEmpty() || newStatus.isEmpty()) return;

    qInfo() << "[DeviceController] WS device_status:" << deviceId << "->" << newStatus;

    // 更新 m_devices 列表中的对应设备状态
    for (int i = 0; i < m_devices.size(); ++i) {
        QVariantMap dev = m_devices[i].toMap();
        if (dev.value("device_id").toString() == deviceId ||
            dev.value("id").toString() == deviceId) {
            dev["status"] = newStatus;
            if (payload.contains("last_seen_at")) {
                dev["last_seen_at"] = payload.value("last_seen_at").toVariant();
            }
            m_devices[i] = dev;
            break;
        }
    }

    // 更新 stats
    if (m_stats.contains(newStatus)) {
        m_stats[newStatus] = m_stats.value(newStatus).toInt() + 1;
    }

    emit devicesUpdated();
    emit statsUpdated();

    // 触发增量 UI 刷新
    if (m_deviceModel) {
        m_deviceModel->setDevices(m_devices);
    }
}

void DeviceController::setDeviceModel(DeviceListModel* model) {
    m_deviceModel = model;
}

void DeviceController::setLoading(bool loading) {
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void DeviceController::setSearchText(const QString& s) {
    if (m_searchText != s) { m_searchText = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setStatusFilter(const QString& s) {
    if (m_statusFilter != s) { m_statusFilter = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setTypeFilter(const QString& s) {
    if (m_typeFilter != s) { m_typeFilter = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setProtocolFilter(const QString& s) {
    if (m_protocolFilter != s) { m_protocolFilter = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setGroupFilter(const QString& s) {
    if (m_groupFilter != s) { m_groupFilter = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setSortBy(const QString& s) {
    if (m_sortBy != s) { m_sortBy = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setSortOrder(const QString& s) {
    if (m_sortOrder != s) { m_sortOrder = s; emit filterChanged(); applyFilters(); }
}
void DeviceController::setPage(int p) {
    if (m_page != p) { m_page = p; emit filterChanged(); refreshDevices(); }
}
void DeviceController::setPageSize(int p) {
    if (m_pageSize != p) { m_pageSize = p; emit filterChanged(); refreshDevices(); }
}

void DeviceController::refreshDevices() {
    // 兼容旧代码: 不传参时使用当前 Q_PROPERTY
    refreshDevices(m_page, m_pageSize, m_searchText, m_statusFilter,
                   m_typeFilter, m_protocolFilter, m_sortBy, m_sortOrder);
}

void DeviceController::refreshDevices(int page, int pageSize,
                                      const QString& search, const QString& status,
                                      const QString& type, const QString& protocol,
                                      const QString& sortBy, const QString& sortOrder) {
    setLoading(true);
    // 同步到成员属性(便于 QML 端保持状态)
    m_page = page;
    m_pageSize = pageSize;
    if (m_searchText != search) m_searchText = search;
    if (m_statusFilter != status) m_statusFilter = status;
    if (m_typeFilter != type) m_typeFilter = type;
    if (m_protocolFilter != protocol) m_protocolFilter = protocol;
    if (m_sortBy != sortBy) m_sortBy = sortBy;
    if (m_sortOrder != sortOrder) m_sortOrder = sortOrder;

    QString path = QString("/api/v1/devices?page=%1&pageSize=%2")
                       .arg(page).arg(pageSize);
    if (!search.isEmpty()) {
        path += QString("&search=%1").arg(QString(search.toUtf8().toPercentEncoding()));
    }
    // 规范 16323eda: 6 状态之一(空 = 不限)
    if (!status.isEmpty()) {
        path += QString("&status=%1").arg(status);
    }
    // 规范 16323eda: 6 类型之一(空 = 不限)
    if (!type.isEmpty()) {
        path += QString("&type=%1").arg(type);
    }
    if (!protocol.isEmpty()) {
        path += QString("&protocol=%1").arg(protocol);
    }
    // 规范 16323eda: 5 排序字段(name/ip/status/lastSeenAt/createdAt) + asc/desc
    QString sb = sortBy.isEmpty() ? QString("createdAt") : sortBy;
    QString so = sortOrder.isEmpty() ? QString("desc") : sortOrder;
    path += QString("&sortBy=%1&sortOrder=%2").arg(sb).arg(so);

    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{devices:[...],items:[...],total:N}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "devices"});
            m_devices.clear();
            for (const auto& item : arr)
                m_devices.append(item.toVariant().toMap());
            m_total = data.value("total").toInt(m_devices.size());
            if (m_deviceModel) m_deviceModel->setDevices(m_devices);
            emit devicesUpdated();
            applyFilters();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void DeviceController::refreshStats() {
    m_api->get("/api/v1/devices/stats",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{online:N,offline:N,...}}
            m_stats = ApiClient::unwrapData(obj).toVariantMap();
            emit statsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::refreshGroups() {
    // 后端没有专门的 /devices/groups，使用 settings 或本地缓存；
    // 这里先用 /api/v1/config 兜底拉取 device_groups
    m_api->get("/api/v1/config",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{device_groups:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"device_groups"});
            m_groups.clear();
            for (const auto& v : arr) m_groups.append(v.toVariant().toMap());
            emit groupsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::refreshAll() {
    refreshDevices();
    refreshStats();
    refreshGroups();
}

void DeviceController::addDevice(const QString& protocol, const QString& ip,
                                  int port, const QString& username,
                                  const QString& password) {
    QJsonObject body;
    body["protocol"] = protocol;
    body["ip_address"] = ip;
    body["port"] = port;
    body["username"] = username;
    body["password"] = password;
    m_api->post("/api/v1/devices", body,
        [this](QJsonObject resp) {
            QString id = resp["device_id"].toString();
            emit deviceAdded(id);
            refreshDevices();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::updateDevice(const QString& deviceId, const QVariantMap& updates) {
    m_api->put(QString("/api/v1/devices/%1").arg(deviceId),
               QJsonObject::fromVariantMap(updates),
        [this, deviceId](QJsonObject) {
            emit deviceUpdated(deviceId);
            refreshDevices();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::removeDevice(const QString& deviceId) {
    m_api->del(QString("/api/v1/devices/%1").arg(deviceId),
        [this, deviceId]() {
            emit deviceRemoved(deviceId);
            refreshDevices();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::discoverDevices(const QString& protocol) {
    setLoading(true);
    QJsonObject body; body["protocol"] = protocol;
    m_api->post("/api/v1/devices/discover", body,
        [this](QJsonObject obj) {
            // 后端响应信封: {code,message,data:{devices:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"devices", "items", "list"});
            QVariantList results;
            for (const auto& v : arr) results.append(v.toVariant());
            emit deviceDiscovered(results);
            refreshDevices();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void DeviceController::getDeviceDetail(const QString& deviceId) {
    m_api->get(QString("/api/v1/devices/%1").arg(deviceId),
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            emit deviceDetailReady(data.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::getDeviceChannels(const QString& deviceId) {
    m_api->get(QString("/api/v1/devices/%1/channels").arg(deviceId),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::getDeviceHealth(const QString& deviceId) {
    m_api->get(QString("/api/v1/devices/%1/health").arg(deviceId),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::rebootDevice(const QString& deviceId) {
    m_api->post(QString("/api/v1/devices/%1/reboot").arg(deviceId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::syncTime(const QString& deviceId) {
    m_api->post(QString("/api/v1/devices/%1/sync-time").arg(deviceId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::batchDelete(const QVariantList& deviceIds) {
    // 后端 /api/v1/devices 没有 batch endpoint, 通过循环调用实现
    for (const auto& v : deviceIds) {
        QString id = v.toString();
        if (id.isEmpty()) continue;
        m_api->del(QString("/api/v1/devices/%1").arg(id),
            [this, id]() { emit deviceRemoved(id); },
            [this](int code, QString msg) { emit errorOccurred(code, msg); });
    }
    // 重新拉取一次
    refreshDevices();
}

void DeviceController::batchSetGroup(const QVariantList& deviceIds,
                                      const QString& groupId) {
    for (const auto& v : deviceIds) {
        QString id = v.toString();
        if (id.isEmpty()) continue;
        QJsonObject body;
        body["group_id"] = groupId;
        m_api->put(QString("/api/v1/devices/%1").arg(id), body,
            [](QJsonObject) {},
            [this](int code, QString msg) { emit errorOccurred(code, msg); });
    }
    refreshDevices();
}

void DeviceController::batchAddTag(const QVariantList& deviceIds, const QString& tag) {
    for (const auto& v : deviceIds) {
        QString id = v.toString();
        if (id.isEmpty()) continue;
        QJsonObject body;
        QJsonArray tags;
        tags.append(tag);
        body["tags"] = tags;
        m_api->put(QString("/api/v1/devices/%1").arg(id), body,
            [](QJsonObject) {},
            [this](int code, QString msg) { emit errorOccurred(code, msg); });
    }
    refreshDevices();
}

void DeviceController::createGroup(const QString& name, const QString& description) {
    // 后端未提供专门的 groups POST 端点，使用 config PUT 实现
    QJsonObject body;
    QJsonObject grp;
    grp["name"] = name;
    grp["description"] = description;
    QJsonArray arr;
    for (const auto& g : m_groups) arr.append(QJsonObject::fromVariantMap(g.toMap()));
    arr.append(grp);
    body["device_groups"] = arr;
    m_api->put("/api/v1/config", body,
        [this, name](QJsonObject) {
            emit groupCreated(name);
            refreshGroups();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void DeviceController::deleteGroup(const QString& groupId) {
    QJsonArray arr;
    for (const auto& g : m_groups) {
        QVariantMap m = g.toMap();
        if (m.value("id").toString() != groupId &&
            m.value("name").toString() != groupId)
            arr.append(QJsonObject::fromVariantMap(m));
    }
    QJsonObject body; body["device_groups"] = arr;
    m_api->put("/api/v1/config", body,
        [this](QJsonObject) { refreshGroups(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

QStringList DeviceController::serializeStatusFilter() const {
    // 当前只支持单值筛选(规范 16323eda: 6 状态之一)
    if (m_statusFilter.isEmpty()) return {};
    return { m_statusFilter };
}

QStringList DeviceController::serializeTypeFilter() const {
    // 当前只支持单值筛选(规范 16323eda: 6 类型之一)
    if (m_typeFilter.isEmpty()) return {};
    return { m_typeFilter };
}

void DeviceController::applyFilters() {
    m_filtered.clear();
    QString kw = m_searchText.trimmed().toLower();
    for (const auto& v : m_devices) {
        QVariantMap m = v.toMap();
        // 状态筛选 (规范 16323eda: 6 状态 online/offline/error/maintenance/warning/unknown)
        if (!m_statusFilter.isEmpty()) {
            QString status = m.value("status").toString();
            if (m_statusFilter == "online" && status != "online") continue;
            if (m_statusFilter == "offline" && status != "offline") continue;
            if (m_statusFilter == "error" && status != "error") continue;
            if (m_statusFilter == "maintenance" && status != "maintenance") continue;
            if (m_statusFilter == "warning" && status != "warning") continue;
            if (m_statusFilter == "unknown" && status != "unknown") continue;
        }
        // 类型筛选 (规范 16323eda: 6 类型 camera/sensor/gateway/nvr/dvr/actuator)
        if (!m_typeFilter.isEmpty()) {
            QString t = m.value("type").toString();
            if (t.isEmpty()) t = m.value("device_type").toString().toLower();
            if (m_typeFilter == "camera" && t != "camera" && t != "ipcamera") continue;
            if (m_typeFilter == "sensor" && t != "sensor") continue;
            if (m_typeFilter == "gateway" && t != "gateway" && t != "edgebox") continue;
            if (m_typeFilter == "nvr" && t != "nvr") continue;
            if (m_typeFilter == "dvr" && t != "dvr") continue;
            if (m_typeFilter == "actuator" && t != "actuator") continue;
        }
        // 协议筛选
        if (!m_protocolFilter.isEmpty() &&
            m.value("protocol").toString() != m_protocolFilter) continue;
        // 分组筛选
        if (!m_groupFilter.isEmpty()) {
            QString gid = m.value("group_id").toString();
            if (gid != m_groupFilter) continue;
        }
        // 关键词
        if (!kw.isEmpty()) {
            QString blob = (m.value("device_name").toString() + " " +
                            m.value("name").toString() + " " +
                            m.value("device_id").toString() + " " +
                            m.value("id").toString() + " " +
                            m.value("ip_address").toString() + " " +
                            m.value("ip").toString()).toLower();
            if (!blob.contains(kw)) continue;
        }
        m_filtered.append(m);
    }

    // 客户端排序 (规范 16323eda: 5 字段 asc/desc)
    if (!m_sortBy.isEmpty()) {
        bool desc = (m_sortOrder == "desc");
        std::sort(m_filtered.begin(), m_filtered.end(),
                  [this, desc](const QVariant& a, const QVariant& b) {
            QVariantMap am = a.toMap();
            QVariantMap bm = b.toMap();
            QString field = m_sortBy;
            // 字段名兼容: lastSeenAt -> last_seen_at; createdAt -> created_at
            QString aVal, bVal;
            if (field == "lastSeenAt") {
                aVal = am.value("last_seen_at").toString();
                if (aVal.isEmpty()) aVal = am.value("lastSeenAt").toString();
                bVal = bm.value("last_seen_at").toString();
                if (bVal.isEmpty()) bVal = bm.value("lastSeenAt").toString();
            } else if (field == "createdAt") {
                aVal = am.value("created_at").toString();
                if (aVal.isEmpty()) aVal = am.value("createdAt").toString();
                bVal = bm.value("created_at").toString();
                if (bVal.isEmpty()) bVal = bm.value("createdAt").toString();
            } else if (field == "name") {
                aVal = am.value("name").toString();
                if (aVal.isEmpty()) aVal = am.value("device_name").toString();
                bVal = bm.value("name").toString();
                if (bVal.isEmpty()) bVal = bm.value("device_name").toString();
            } else if (field == "ip") {
                aVal = am.value("ip").toString();
                if (aVal.isEmpty()) aVal = am.value("ip_address").toString();
                bVal = bm.value("ip").toString();
                if (bVal.isEmpty()) bVal = bm.value("ip_address").toString();
            } else if (field == "status") {
                aVal = am.value("status").toString();
                bVal = bm.value("status").toString();
            } else {
                aVal = am.value(field).toString();
                bVal = bm.value(field).toString();
            }
            if (desc) return aVal > bVal;
            return aVal < bVal;
        });
    }

    emit filterChanged();
}
