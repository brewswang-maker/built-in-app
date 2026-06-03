#pragma once
#include <QObject>
#include <QVariantList>

class ApiClient;
class DeviceListModel;

class DeviceController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int deviceCount READ deviceCount NOTIFY devicesUpdated)

public:
    explicit DeviceController(ApiClient* api, QObject* parent = nullptr);

    QVariantList devices() const { return m_devices; }
    bool loading() const { return m_loading; }
    int deviceCount() const { return m_devices.size(); }

    void setDeviceModel(DeviceListModel* model);

    Q_INVOKABLE void refreshDevices();
    Q_INVOKABLE void addDevice(const QString& protocol, const QString& ip,
                               int port, const QString& username, const QString& password);
    Q_INVOKABLE void removeDevice(const QString& deviceId);
    Q_INVOKABLE void discoverDevices(const QString& protocol);
    Q_INVOKABLE void getDeviceDetail(const QString& deviceId);

signals:
    void devicesUpdated();
    void loadingChanged();
    void deviceAdded(const QString& deviceId);
    void deviceRemoved(const QString& deviceId);
    void errorOccurred(int code, const QString& message);

private:
    void setLoading(bool loading);

    ApiClient* m_api;
    DeviceListModel* m_deviceModel = nullptr;
    QVariantList m_devices;
    bool m_loading = false;
};
