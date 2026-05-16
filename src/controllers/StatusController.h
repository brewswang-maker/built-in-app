#pragma once
#include <QObject>
#include <QTimer>

class ApiClient;

class StatusController : public QObject {
    Q_OBJECT
    Q_PROPERTY(float cpuUsage READ cpuUsage NOTIFY statusUpdated)
    Q_PROPERTY(float gpuUsage READ gpuUsage NOTIFY statusUpdated)
    Q_PROPERTY(float memoryUsage READ memoryUsage NOTIFY statusUpdated)
    Q_PROPERTY(float temperature READ temperature NOTIFY statusUpdated)
    Q_PROPERTY(float tpuUtilization READ tpuUtilization NOTIFY statusUpdated)
    Q_PROPERTY(int tpuMemoryUsed READ tpuMemoryUsed NOTIFY statusUpdated)
    Q_PROPERTY(int activeModels READ activeModels NOTIFY statusUpdated)
    Q_PROPERTY(QString uptime READ uptime NOTIFY statusUpdated)
    Q_PROPERTY(QString systemTime READ systemTime NOTIFY statusUpdated)
    Q_PROPERTY(QString networkStatus READ networkStatus NOTIFY statusUpdated)

public:
    explicit StatusController(ApiClient* api, QObject* parent = nullptr);

    float cpuUsage() const { return m_cpuUsage; }
    float gpuUsage() const { return m_gpuUsage; }
    float memoryUsage() const { return m_memoryUsage; }
    float temperature() const { return m_temperature; }
    float tpuUtilization() const { return m_tpuUtilization; }
    int tpuMemoryUsed() const { return m_tpuMemoryUsed; }
    int activeModels() const { return m_activeModels; }
    QString uptime() const { return m_uptime; }
    QString systemTime() const { return m_systemTime; }
    QString networkStatus() const { return m_networkStatus; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void startPolling(int intervalMs = 5000);
    Q_INVOKABLE void stopPolling();

signals:
    void statusUpdated();
    void systemAlert(const QString& message);

private:
    ApiClient* m_api;
    QTimer* m_timer;
    float m_cpuUsage = 0;
    float m_gpuUsage = 0;
    float m_memoryUsage = 0;
    float m_temperature = 0;
    float m_tpuUtilization = 0;
    int m_tpuMemoryUsed = 0;
    int m_activeModels = 0;
    QString m_uptime;
    QString m_systemTime;
    QString m_networkStatus = "Connected";
};
