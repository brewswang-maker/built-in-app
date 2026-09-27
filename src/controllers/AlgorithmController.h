#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QHash>
#include <QJsonObject>

class ApiClient;
class AlgorithmListModel;

class AlgorithmController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList algorithms READ algorithms NOTIFY algorithmsUpdated)
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsUpdated)
    // [M3-2 内置端对齐 2026-09-27] 灵敏度/生成风格档位卡数据源 (仅勾选事件中
    //   有档位设计的算法; 详见 refreshAlgoTiers 注释)
    Q_PROPERTY(QVariantList algoTiers READ algoTiers NOTIFY algoTiersUpdated)
    Q_PROPERTY(float tpuUsage READ tpuUsage NOTIFY tpuUsageUpdated)
    Q_PROPERTY(int activeModels READ activeModels NOTIFY tpuUsageUpdated)
    Q_PROPERTY(int tpuMemoryUsed READ tpuMemoryUsed NOTIFY tpuUsageUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit AlgorithmController(ApiClient* api, QObject* parent = nullptr);

    QVariantList algorithms() const { return m_algorithms; }
    QVariantList models() const { return m_models; }
    QVariantList algoTiers() const { return m_algoTiers; }
    float tpuUsage() const { return m_tpuUsage; }
    int activeModels() const { return m_activeModels; }
    int tpuMemoryUsed() const { return m_tpuMemoryUsed; }
    bool loading() const { return m_loading; }

    void setAlgorithmModel(AlgorithmListModel* model);

    Q_INVOKABLE void refreshAlgorithms();
    Q_INVOKABLE void refreshModels();
    Q_INVOKABLE void refreshTpuUsage();
    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void getAlgorithmConfig(const QString& algoId);
    Q_INVOKABLE void updateAlgorithmConfig(const QString& algoId, const QVariantMap& config);
    Q_INVOKABLE void activateModel(const QString& modelId);
    Q_INVOKABLE void deactivateModel(const QString& modelId);
    Q_INVOKABLE void deleteModel(const QString& modelId);
    /// 拉取勾选事件类型的档位信息 (param-meta; 无档位设计的事件不出卡)
    Q_INVOKABLE void refreshAlgoTiers(const QVariantList& eventTypes);
    /// 切换档位 (整组覆盖 → box_config; 重启服务后对推理生效)
    Q_INVOKABLE void setAlgoTier(const QString& eventType, const QString& algoKey,
                                 const QString& tier);

signals:
    void algorithmsUpdated();
    void modelsUpdated();
    void algoTiersUpdated();
    void tpuUsageUpdated();
    void loadingChanged();
    void algorithmConfigReceived(const QString& algoId, const QVariantMap& config);
    void configUpdated(const QString& algoId);
    void modelActivated(const QString& modelId);
    void modelDeactivated(const QString& modelId);
    /// 档位切换成功 (eventType/tier 供 UI 提示; 失败走 errorOccurred)
    void tierApplied(const QString& eventType, const QString& tier);
    void errorOccurred(int code, const QString& message);

private:
    /// param-meta data 节 → 档位卡条目 (无 tier/presets 算法返回空 map)
    static QVariantMap parseTierMeta(const QString& eventType, const QJsonObject& data);

    ApiClient* m_api;
    AlgorithmListModel* m_algoModel = nullptr;
    QVariantList m_algorithms;
    QVariantList m_models;
    QVariantList m_algoTiers;
    /// eventType → 档位条目 (空 map = 已知无档位设计, 会话内不重复请求)
    QHash<QString, QVariantMap> m_tierMetaCache;
    /// 刷新竞态序号 (仅最新一轮可写回 algoTiers)
    int m_tierSeq = 0;
    float m_tpuUsage = 0;
    int m_activeModels = 0;
    int m_tpuMemoryUsed = 0;
    bool m_loading = false;
};
