#include "AlgorithmController.h"
#include "models/AlgorithmListModel.h"
#include "utils/ApiClient.h"

#include <QJsonObject>
#include <QRegularExpression>

#include <memory>

namespace {

/// 生成风格三档键集 (与 web ParameterFormRenderer STYLE_TIERS 同口径)
const QStringList& styleTierKeys() {
    static const QStringList kKeys = {"strict", "standard", "creative"};
    return kKeys;
}

/// presets 键展示序重排: 灵敏度 high→balanced→low / 生成风格 strict→standard
///   →creative 优先, 未知键按字典序追加尾部。为什么必须重排: QJsonObject 迭代
///   为键字母序 (balanced/high/low), 不重排则内置端显示序与 YAML 定义序、web
///   端展示序 (JS 对象保插入序) 不一致。
QVariantList orderedPresetKeys(const QJsonObject& presets) {
    static const QStringList kPreferred = {"high", "balanced", "low",
                                           "strict", "standard", "creative"};
    QVariantList out;
    for (const auto& k : kPreferred) {
        if (presets.contains(k)) out.append(k);
    }
    QStringList rest;
    for (auto it = presets.begin(); it != presets.end(); ++it) {
        if (!kPreferred.contains(it.key())) rest.append(it.key());
    }
    rest.sort();
    for (const auto& k : rest) out.append(k);
    return out;
}

}  // namespace

AlgorithmController::AlgorithmController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void AlgorithmController::setAlgorithmModel(AlgorithmListModel* model) {
    m_algoModel = model;
}

void AlgorithmController::refreshAlgorithms() {
    m_loading = true;
    emit loadingChanged();

    m_api->getList("/api/v1/algorithms",
        [this](QJsonArray arr) {
            m_loading = false;
            m_algorithms.clear();
            for (const auto& item : arr)
                m_algorithms.append(item.toVariant().toMap());
            emit algorithmsUpdated();
            emit loadingChanged();

            if (m_algoModel)
                m_algoModel->setAlgorithms(m_algorithms);
        },
        [this](int code, QString msg) {
            m_loading = false;
            emit loadingChanged();
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::refreshModels() {
    m_api->getList("/api/v1/models",
        [this](QJsonArray arr) {
            m_models.clear();
            for (const auto& item : arr)
                m_models.append(item.toVariant().toMap());
            emit modelsUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::refreshTpuUsage() {
    m_api->get("/api/v1/models/tpu-usage",
        [this](QJsonObject resp) {
            // [FIX api-contract 2026-09-22] 响应为信封, 需 unwrapData;
            // 旧实现读裸顶层 → 三项恒为 0。
            const QJsonObject data = ApiClient::unwrapData(resp);
            m_tpuUsage = data["utilization"].toDouble();
            m_activeModels = data["active_models"].toInt();
            m_tpuMemoryUsed = data["memory_used"].toInt();
            emit tpuUsageUpdated();
        },
        [](int, QString) {});
}

void AlgorithmController::refreshAll() {
    refreshAlgorithms();
    refreshModels();
    refreshTpuUsage();
}

void AlgorithmController::getAlgorithmConfig(const QString& algoId) {
    m_api->get(QString("/api/v1/algorithms/%1/config").arg(algoId),
        [this, algoId](QJsonObject resp) {
            // [FIX api-contract 2026-09-22] 响应为信封, 需 unwrapData 后再转 map。
            QVariantMap config = ApiClient::unwrapData(resp).toVariantMap();
            emit algorithmConfigReceived(algoId, config);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::updateAlgorithmConfig(const QString& algoId, const QVariantMap& config) {
    QJsonObject body = QJsonObject::fromVariantMap(config);
    m_api->put(QString("/api/v1/algorithms/%1/config").arg(algoId), body,
        [this, algoId](QJsonObject) {
            emit configUpdated(algoId);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::activateModel(const QString& modelId) {
    m_api->post(QString("/api/v1/models/%1/activate").arg(modelId), QJsonObject(),
        [this, modelId](QJsonObject) {
            emit modelActivated(modelId);
            refreshModels();
            refreshTpuUsage();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::deactivateModel(const QString& modelId) {
    m_api->post(QString("/api/v1/models/%1/deactivate").arg(modelId), QJsonObject(),
        [this, modelId](QJsonObject) {
            emit modelDeactivated(modelId);
            refreshModels();
            refreshTpuUsage();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::deleteModel(const QString& modelId) {
    m_api->del(QString("/api/v1/models/%1").arg(modelId),
        [this]() {
            refreshModels();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

// ═════════════════════════════════════════════════════════════════════
// [M3-2 内置端对齐 2026-09-27] 灵敏度/生成风格档位 (tier) — 与 web
//   LinkageRuleView.vue(AlgoParamCard)+ParameterFormRenderer 同源契约:
//   ① GET /api/v1/algorithms/:id/param-meta — :id 传事件 canonical key
//      (后端 resolveParamMetaAlgoId 声明域反查), data.tier={current,presets}
//      仅候选有档位设计的算法存在; 无 tier 节点 → 该事件不出档位卡。
//   ② PUT /api/v1/algo/:algo/tier {tier} — algo=短名 (algo_id 尾段 = box_config
//      节名), 整组覆盖写入; 重启服务后对推理生效 (restart_required)。
//   为什么走 param-meta 而不是硬编码算法清单: SSOT=算法 YAML tier_presets 节,
//   后续新增档位算法 (改 YAML) 内置端零代码改动自动出现 — 与事件类型批次
//   同一条纪律 (禁止硬编码)。
// ═════════════════════════════════════════════════════════════════════

QVariantMap AlgorithmController::parseTierMeta(const QString& eventType,
                                               const QJsonObject& data) {
    QVariantMap entry;
    const QJsonObject tier = data.value("tier").toObject();
    const QJsonObject presets = tier.value("presets").toObject();
    const QString algoId = data.value("algo_id").toString();
    if (presets.isEmpty() || algoId.isEmpty()) return entry;  // 无档位设计

    const QVariantList keys = orderedPresetKeys(presets);
    bool isStyle = !keys.isEmpty();
    for (const auto& k : keys) {
        if (!styleTierKeys().contains(k.toString())) { isStyle = false; break; }
    }
    entry["eventType"] = eventType;
    entry["algoId"] = algoId;
    entry["algoKey"] = algoId.section('.', -1);  // 尾段: PUT 路由 + box_config 节名
    entry["name"] = data.value("algo_name").toString();  // 空则 QML 用事件显示名
    entry["isStyle"] = isStyle;
    // current 缺省托底与后端 param-meta 同口径 (box_config 未写键 → balanced)
    entry["current"] = tier.value("current").toString("balanced");
    entry["presets"] = keys;
    return entry;
}

void AlgorithmController::refreshAlgoTiers(const QVariantList& eventTypes) {
    // 规范化输入: canonical key 去空去重保序
    QStringList types;
    for (const auto& v : eventTypes) {
        const QString et = v.toString().trimmed();
        if (et.isEmpty() || types.contains(et)) continue;
        types << et;
    }

    const int seq = ++m_tierSeq;
    auto collected = std::make_shared<QHash<QString, QVariantMap>>();
    auto pending = std::make_shared<int>(0);

    // 批次完成收敛: 按输入序重建列表; 过期批次 (更晚一轮已发起) 整体丢弃
    auto finish = [this, seq, collected, pending, types]() {
        if (seq != m_tierSeq) return;
        QVariantList out;
        for (const auto& et : types) {
            const auto it = collected->constFind(et);
            if (it != collected->constEnd()) out.append(*it);
        }
        m_algoTiers = out;
        emit algoTiersUpdated();
    };

    for (const auto& et : types) {
        // 缓存命中: 已知有档位直接收编; 已知无档位 (空 map) 直接跳过
        const auto cit = m_tierMetaCache.constFind(et);
        if (cit != m_tierMetaCache.constEnd()) {
            if (!cit->isEmpty()) collected->insert(et, *cit);
            continue;
        }
        ++(*pending);
        m_api->get(QString("/api/v1/algorithms/%1/param-meta").arg(et),
            [this, et, collected, pending, finish](QJsonObject resp) {
                const QVariantMap entry =
                    parseTierMeta(et, ApiClient::unwrapData(resp));
                // 空 map 同样缓存 = 该事件已知无档位 (避免反复请求)
                m_tierMetaCache.insert(et, entry);
                if (!entry.isEmpty()) collected->insert(et, entry);
                if (--(*pending) == 0) finish();
            },
            [this, collected, pending, finish](int code, QString msg) {
                // 失败不缓存 (下次勾选可重试), 但必须消账使批次能收敛
                if (--(*pending) == 0) finish();
                emit errorOccurred(code, msg);
            });
    }
    if (*pending == 0) finish();  // 全部缓存命中 (或空入参清空) 直达
}

void AlgorithmController::setAlgoTier(const QString& eventType, const QString& algoKey,
                                      const QString& tier) {
    // 与后端泛化路由护栏同口径 [a-z0-9-]{1,32} (防非法节名拼进路径; 后端 400
    //   仍是最终防线, 此层只做应用侧快速拒绝 + 可读错误)
    static const QRegularExpression kAlgoKeyRe(QStringLiteral("^[a-z0-9-]{1,32}$"));
    if (!kAlgoKeyRe.match(algoKey).hasMatch() || tier.isEmpty()) {
        emit errorOccurred(-1, QStringLiteral("invalid algoKey/tier: %1/%2")
                                   .arg(algoKey, tier));
        return;
    }
    QJsonObject body;
    body["tier"] = tier;
    m_api->put(QString("/api/v1/algo/%1/tier").arg(algoKey), body,
        [this, eventType, tier](QJsonObject resp) {
            const QJsonObject data = ApiClient::unwrapData(resp);
            const QString applied = data.value("tier").toString(tier);
            // PUT 整组覆盖 → 本地生效档位=请求档位 (与 web 切换后重读 config
            //   等效, 省一次往返); 缓存与列表双写保持后续刷新一致
            auto it = m_tierMetaCache.find(eventType);
            if (it != m_tierMetaCache.end() && !it->isEmpty())
                (*it)["current"] = applied;
            for (int i = 0; i < m_algoTiers.size(); ++i) {
                QVariantMap m = m_algoTiers[i].toMap();
                if (m.value("eventType").toString() == eventType) {
                    m["current"] = applied;
                    m_algoTiers[i] = m;
                }
            }
            emit algoTiersUpdated();
            emit tierApplied(eventType, applied);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}
