#include "DeviceController.h"
#include "utils/ApiClient.h"

DeviceController::DeviceController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void DeviceController::setLoading(bool loading) {
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void DeviceController::refreshDevices() {
    setLoading(true);
    m_api->getList("/api/v1/devices",
        [this](QJsonArray arr) {
            m_devices.clear();
            for (const auto& item : arr) {
                m_devices.append(item.toVariant().toMap());
            }
            emit devicesUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void DeviceController::addDevice(const QString& protocol, const QString& ip,
                                  int port, const QString& username, const QString& password) {
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
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void DeviceController::removeDevice(const QString& deviceId) {
    m_api->del(QString("/api/v1/devices/%1").arg(deviceId),
        [this, deviceId]() {
            emit deviceRemoved(deviceId);
            refreshDevices();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void DeviceController::discoverDevices(const QString& protocol) {
    setLoading(true);
    QJsonObject body;
    body["protocol"] = protocol;
    m_api->post("/api/v1/devices/discover", body,
        [this](QJsonObject resp) {
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
        [this](QJsonObject resp) {
            // Update detail in model
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}
