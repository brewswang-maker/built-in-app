#include "ConfigController.h"
#include "utils/ApiClient.h"
#include <QSettings>

// [FIX api-contract 2026-09-22] 本地偏好键(后端无对应存储), 落 QSettings;
// 其余键走后端 PUT /api/v1/settings/basic(partial-friendly, 仅处理 present keys)。
static const QStringList kLocalOnlyKeys = {
    "timezone", "language", "screenBrightness", "alertVolume",
    "alertPopup", "alertSoundLight", "autoDismiss"
};

ConfigController::ConfigController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void ConfigController::loadConfig() {
    // [FIX api-contract 2026-09-22] canonical = /api/v1/settings/basic(信封);
    // 旧实现读 /api/v1/config 裸顶层(无 deviceName/logLevel 等字段) → 字段全空。
    m_api->get("/api/v1/settings/basic",
        [this](QJsonObject resp) {
            m_config = ApiClient::unwrapData(resp).toVariantMap();
            // 合并本地偏好(QSettings)
            QSettings local("ShieldBox", "GUI");
            for (const QString& key : kLocalOnlyKeys) {
                if (local.contains(key))
                    m_config[key] = local.value(key);
            }
            emit configUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::saveConfig(const QString& key, const QVariant& value) {
    if (kLocalOnlyKeys.contains(key)) {
        // 本地偏好: 直接落 QSettings, 不打扰后端
        QSettings local("ShieldBox", "GUI");
        local.setValue(key, value);
        m_config[key] = value;
        emit configUpdated();
        emit configSaved();
        return;
    }
    // 设备级设置: PUT /api/v1/settings/basic(partial-friendly)
    QJsonObject body;
    body[key] = QJsonValue::fromVariant(value);
    m_api->put("/api/v1/settings/basic", body,
        [this](QJsonObject) {
            emit configSaved();
            loadConfig();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::exportConfig() {
    m_api->post("/api/v1/config/export", QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::importConfig(const QString& path) {
    QJsonObject body;
    body["path"] = path;
    m_api->post("/api/v1/config/import", body,
        [this](QJsonObject) { loadConfig(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::getNetworkConfig() {
    // [FIX api-contract 2026-09-22] 响应为信封 + 字段映射:
    // 后端 ipAddress/netmask/dns1 → QML 消费的 ip/subnet/dns。
    m_api->get("/api/v1/config/network",
        [this](QJsonObject resp) {
            const QJsonObject d = ApiClient::unwrapData(resp);
            QVariantMap net = d.toVariantMap();
            if (net.contains("ipAddress") && !net.contains("ip"))
                net["ip"] = net["ipAddress"];
            if (net.contains("netmask") && !net.contains("subnet"))
                net["subnet"] = net["netmask"];
            if (net.contains("dns1") && !net.contains("dns"))
                net["dns"] = net["dns1"];
            m_networkConfig = net;
            emit networkConfigUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::setNetworkConfig(const QVariantMap& config) {
    // [FIX api-contract 2026-09-22] 反向映射后 PUT(后端为占位确认实现)
    QVariantMap body = config;
    if (config.contains("ip") && !config.contains("ipAddress"))
        body["ipAddress"] = config["ip"];
    if (config.contains("subnet") && !config.contains("netmask"))
        body["netmask"] = config["subnet"];
    if (config.contains("dns") && !config.contains("dns1"))
        body["dns1"] = config["dns"];
    m_api->put("/api/v1/config/network", QJsonObject::fromVariantMap(body),
        [this](QJsonObject) {
            emit networkConfigUpdated();
            getNetworkConfig();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::getAlgorithmList() {
    m_api->getList("/api/v1/algorithms",
        [this](QJsonArray arr) {
            m_algorithms.clear();
            for (const auto& item : arr)
                m_algorithms.append(item.toVariant().toMap());
            emit algorithmsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::configureAlgorithm(const QString& id, const QVariantMap& params) {
    m_api->put(QString("/api/v1/algorithms/%1/config").arg(id),
               QJsonObject::fromVariantMap(params),
        [this](QJsonObject) {
            getAlgorithmList();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
