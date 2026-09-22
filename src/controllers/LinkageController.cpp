#include "LinkageController.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>

// ─── 静态常量: 43 类已知动作类型 (规范 82ec775a: 与 box-sdk LinkageEngine.h:132-201 1:1 对齐) ───
static const char* kKnownActions[] = {
    // CLIENT_* (26 类, 100-125)
    "CLIENT_SHOW_LIVE",        "CLIENT_SHOW_PLAYBACK",    "CLIENT_SHOW_IMAGE",
    "CLIENT_VOICE_TALK",       "CLIENT_PLAY_TONE",        "CLIENT_TTS_BROADCAST",
    "CLIENT_OVERLAY_INFO",     "CLIENT_SHOW_MAP",         "CLIENT_SUPPRESS_POPUP",
    "CLIENT_EXECUTE_PLAN",     "CLIENT_TV_WALL",          "CLIENT_RECORD_VIDEO",
    "CLIENT_RECORD_EVENT",     "CLIENT_ADD_BOOKMARK",     "CLIENT_CAPTURE_IMAGE",
    "CLIENT_ALARM_OUTPUT",     "CLIENT_PTZ_CONTROL",      "CLIENT_PTZ_PRESET_START",
    "CLIENT_PTZ_PRESET_END",   "CLIENT_PTZ_CRUISE",       "CLIENT_PTZ_TRACK",
    "CLIENT_ACCESS_OPEN",      "CLIENT_SEND_SMS",         "CLIENT_SEND_EMAIL",
    "CLIENT_ALARM_MODE",       "CLIENT_ESCALATE",
    // WEB_* (12 类, 200-217)
    "WEB_POPUP",               "WEB_EMAIL",               "WEB_WEBHOOK",
    "WEB_DASHBOARD_ALERT",     "WEB_SHOW_LIVE",           "WEB_SHOW_PLAYBACK",
    "WEB_SHOW_IMAGE",          "WEB_PLAY_TONE",           "WEB_TTS_BROADCAST",
    "WEB_CAPTURE_IMAGE",       "WEB_SEND_SMS",            "WEB_RECORD_EVENT",
    // APP_* (5 类, 300-304)
    "APP_PUSH_NOTIFY",         "APP_SHOW_LIVE",           "APP_SHOW_IMAGE",
    "APP_SHOW_PLAYBACK",       "APP_HANDLE_DISPOSE",
    // MP_* (3 类, 400-402)
    "MP_SUBSCRIBE_MSG",        "MP_SHOW_IMAGE",           "MP_SHOW_LIVE",
    // SYS_* (12 类, 500-511)
    "SYS_MQTT_PUBLISH",        "SYS_MODBUS_WRITE",        "SYS_ONVIF_TRIGGER",
    "SYS_RELAY_SWITCH",        "SYS_HTTP_CALLBACK",       "SYS_CLOUD_FORWARD",
    "SYS_START_INFERENCE",     "SYS_STOP_INFERENCE",      "SYS_START_STREAM",
    "SYS_STOP_STREAM",         "SYS_DEPLOY_PIPELINE",     "SYS_UNDEPLOY_PIPELINE"
};
static constexpr int kKnownActionCount = sizeof(kKnownActions) / sizeof(kKnownActions[0]);
// 静态断言: 58 类 (规范 82ec775a: 数字与后端 LinkageEngine.h 1:1 严格一致)
// 26 CLIENT_*(100-125) + 12 WEB_*(200-217) + 5 APP_*(300-304) + 3 MP_*(400-402) + 12 SYS_*(500-511) = 58
static_assert(sizeof(kKnownActions) / sizeof(kKnownActions[0]) == 58,
              "LinkageController: known action count must be 58 to match LinkageEngine.h");

LinkageController::LinkageController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
    buildKnownActionSet();
}

void LinkageController::buildKnownActionSet() {
    for (int i = 0; i < kKnownActionCount; ++i) {
        QString name = QString::fromLatin1(kKnownActions[i]);
        m_knownActionTypes.insert(name);
        // 按前缀分桶
        int us = name.indexOf('_');
        if (us > 0) {
            QString prefix = name.left(us);
            m_actionByPrefix[prefix].append(name);
        }
    }
    // 排序(让 QML 显示稳定)
    for (auto it = m_actionByPrefix.begin(); it != m_actionByPrefix.end(); ++it) {
        std::sort(it->begin(), it->end());
    }
}

int LinkageController::enabledRules() const {
    int c = 0;
    for (const auto& r : m_rules)
        if (r.toMap().value("enabled").toBool()) c++;
    return c;
}

QStringList LinkageController::knownActionTypes() const {
    QStringList out = m_knownActionTypes.values();
    std::sort(out.begin(), out.end());
    return out;
}

// [P1-#1 v3.0 R1] inline in header

void LinkageController::refreshActionTypes() {
    if (!m_api) return;
    m_api->get("/api/v1/linkage/action-types",
        [this](QJsonObject obj) {
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "items"});
            m_actionTypes.clear();
            m_actionSchemas.clear();
            for (const auto& v : arr) {
                QJsonObject t = v.toObject();
                QString typeName = t.value("type_name").toString();
                m_actionTypes.append(t.toVariantMap());
                if (t.contains("param_schema") && t["param_schema"].isObject() && !typeName.isEmpty()) {
                    m_actionSchemas[typeName] = t["param_schema"].toObject().toVariantMap();
                }
            }
            emit actionTypesUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, QStringLiteral("refreshActionTypes failed: ") + msg);
        });
}

QVariantMap LinkageController::actionTypesByPrefix() const {
    QVariantMap out;
    for (auto it = m_actionByPrefix.constBegin(); it != m_actionByPrefix.constEnd(); ++it) {
        out.insert(it.key(), it.value());
    }
    return out;
}

QStringList LinkageController::allRuleIds(const QString& excludeId) const {
    QStringList ids;
    for (const auto& r : m_rules) {
        QVariantMap m = r.toMap();
        QString rid = m.value("id").toString();
        if (rid.isEmpty()) rid = m.value("rule_id").toString();
        if (rid.isEmpty()) continue;
        if (rid == excludeId) continue;
        ids.append(rid);
    }
    ids.sort();
    return ids;
}

static QVariantMap makeErr(int code, const QString& field, const QString& message) {
    QVariantMap r;
    r["ok"] = false;
    r["code"] = code;
    r["field"] = field;
    r["message"] = message;
    return r;
}

static QVariantMap makeOk() {
    QVariantMap r;
    r["ok"] = true;
    r["code"] = 0;
    r["field"] = "";
    r["message"] = "";
    return r;
}

QVariantMap LinkageController::validateConditionTreeRec(const QVariantMap& node, int depth) const {
    if (depth > 3) {
        return makeErr(-1, "condition_tree", "条件树嵌套深度不能超过 3 层");
    }
    QString nt = node.value("node_type").toString().toUpper();
    if (nt.isEmpty()) nt = "LEAF";
    if (nt == "LEAF") {
        if (!node.contains("leaf_type") && !node.contains("field")) {
            return makeErr(-1, "condition_tree.leaf_type", "LEAF 节点必须指定 leaf_type/field");
        }
        if (!node.contains("op")) {
            return makeErr(-1, "condition_tree.op", "LEAF 节点必须指定比较运算符 op");
        }
        if (!node.contains("value")) {
            return makeErr(-1, "condition_tree.value", "LEAF 节点必须提供 value");
        }
        return makeOk();
    }
    if (nt != "AND" && nt != "OR" && nt != "NOT") {
        return makeErr(-1, "condition_tree.node_type", "未知节点类型: " + nt);
    }
    QVariantList children = node.value("children").toList();
    if (nt == "NOT" && children.size() != 1) {
        return makeErr(-1, "condition_tree.children", "NOT 节点必须且只能有 1 个子节点");
    }
    if ((nt == "AND" || nt == "OR") && children.size() < 2) {
        return makeErr(-1, "condition_tree.children", QString("%1 节点至少需要 2 个子节点, 当前: %2").arg(nt).arg(children.size()));
    }
    for (int i = 0; i < children.size(); ++i) {
        QVariantMap c = children[i].toMap();
        QVariantMap r = validateConditionTreeRec(c, depth + 1);
        if (!r.value("ok").toBool()) {
            r["field"] = QString("condition_tree.children[%1].%2").arg(i).arg(r.value("field").toString());
            return r;
        }
    }
    return makeOk();
}

QVariantMap LinkageController::validateConditionTree(const QVariantMap& tree) const {
    if (tree.isEmpty()) return makeOk();   // 空树视为未启用
    return validateConditionTreeRec(tree, 0);
}

QVariantMap LinkageController::validateMergeCond(const QVariantMap& merge) const {
    if (merge.isEmpty()) return makeOk();
    bool enabled = merge.value("enabled", false).toBool();
    if (!enabled) return makeOk();
    int wnd = merge.value("window_ms", 0).toInt();
    if (wnd < 0 || wnd > 60000) {
        return makeErr(-1, "merge_cond.window_ms",
            QString("合并窗口必须在 0-60000ms 之间, 当前: %1").arg(wnd));
    }
    int mc = merge.value("max_merge_count", 0).toInt();
    if (mc < 0 || mc > 1000) {
        return makeErr(-1, "merge_cond.max_merge_count",
            QString("最大合并数必须在 0-1000 之间, 当前: %1").arg(mc));
    }
    QString by = merge.value("merge_by").toString();
    if (!by.isEmpty() && by != "channel" && by != "type" && by != "location") {
        return makeErr(-1, "merge_cond.merge_by",
            "合并维度必须为 channel/type/location, 当前: " + by);
    }
    return makeOk();
}

QVariantMap LinkageController::validateTimeCond(const QVariantMap& time) const {
    if (time.isEmpty()) return makeOk();
    static const QRegularExpression reHour("^([01]?\\d|2[0-3]):[0-5]\\d$");
    QString ts = time.value("time_start").toString();
    QString te = time.value("time_end").toString();
    if (!ts.isEmpty() && !reHour.match(ts).hasMatch()) {
        return makeErr(-1, "time_cond.time_start",
            "起始时间格式必须为 HH:MM, 当前: " + ts);
    }
    if (!te.isEmpty() && !reHour.match(te).hasMatch()) {
        return makeErr(-1, "time_cond.time_end",
            "结束时间格式必须为 HH:MM, 当前: " + te);
    }
    QVariantList wd = time.value("weekdays").toList();
    for (int i = 0; i < wd.size(); ++i) {
        int d = wd[i].toInt();
        if (d < 1 || d > 7) {
            return makeErr(-1, QString("time_cond.weekdays[%1]").arg(i),
                QString("星期值必须在 1-7 之间 (1=周一 .. 7=周日), 当前: %1").arg(d));
        }
    }
    return makeOk();
}

QVariantMap LinkageController::validateSuppression(const QVariantMap& sup) const {
    if (sup.isEmpty()) return makeOk();
    QString mg = sup.value("mutex_group").toString();
    if (mg.length() > 64) {
        return makeErr(-1, "mutex_group", QString("互斥组 ID 长度不能超过 64, 当前: %1").arg(mg.length()));
    }
    QString sar = sup.value("suppress_after_rule").toString();
    if (!sar.isEmpty()) {
        bool found = false;
        for (const auto& r : m_rules) {
            QVariantMap m = r.toMap();
            QString rid = m.value("id").toString();
            if (rid.isEmpty()) rid = m.value("rule_id").toString();
            if (rid == sar) { found = true; break; }
        }
        if (!found) {
            return makeErr(-1, "suppress_after_rule",
                "抑制链引用的规则 ID 不存在: " + sar);
        }
    }
    return makeOk();
}

QVariantMap LinkageController::validateRule(const QVariantMap& rule, bool isUpdate) const {
    QVariantMap result;
    result["ok"] = false;
    result["code"] = Ok;
    result["field"] = "";
    result["message"] = "";

    // 1. rule_id 校验
    QString ruleId = rule.value("id").toString();
    if (ruleId.isEmpty()) ruleId = rule.value("rule_id").toString();
    if (ruleId.isEmpty()) {
        result["code"] = EmptyRuleId;
        result["field"] = "id";
        result["message"] = "规则 ID 不能为空";
        return result;
    }

    // 2. name 校验
    QString name = rule.value("name").toString();
    if (name.trimmed().isEmpty()) {
        result["code"] = EmptyName;
        result["field"] = "name";
        result["message"] = "规则名称不能为空";
        return result;
    }

    // 3. priority 校验 (后端 [0, 100], 文档写 1-100 但 addRuleChecked 实际允许 0)
    int priority = rule.value("priority", 50).toInt();
    if (priority < 0 || priority > 100) {
        result["code"] = InvalidPriority;
        result["field"] = "priority";
        result["message"] = QString("优先级必须在 0-100 之间,当前值: %1").arg(priority);
        return result;
    }

    // 4. actions 校验
    QVariantList actions = rule.value("actions").toList();
    if (actions.isEmpty()) {
        result["code"] = NoActions;
        result["field"] = "actions";
        result["message"] = "至少需要选择 1 个联动动作";
        return result;
    }
    for (int i = 0; i < actions.size(); ++i) {
        QVariantMap a = actions[i].toMap();
        QString at = a.value("type").toString();
        if (at.isEmpty()) {
            result["code"] = UnknownActionType;
            result["field"] = QString("actions[%1].type").arg(i);
            result["message"] = QString("动作 #%1 缺少 type 字段").arg(i + 1);
            return result;
        }
        if (!m_knownActionTypes.contains(at)) {
            result["code"] = UnknownActionType;
            result["field"] = QString("actions[%1].type").arg(i);
            result["message"] = QString("未知的动作类型: %1").arg(at);
            return result;
        }
    }

    // 5. 重复 ID 检测 (仅创建模式, 更新模式允许)
    if (!isUpdate) {
        for (const auto& r : m_rules) {
            QVariantMap existing = r.toMap();
            QString existId = existing.value("id").toString();
            if (existId.isEmpty()) existId = existing.value("rule_id").toString();
            if (existId == ruleId) {
                result["code"] = DuplicateId;
                result["field"] = "id";
                result["message"] = QString("规则 ID 已存在: %1").arg(ruleId);
                return result;
            }
        }
    }

    // 6. 时间模板存在性 (可选字段, 无引用即跳过)
    if (rule.contains("time_template_id") && !rule.value("time_template_id").toString().isEmpty()) {
        // 真实模板列表需后端下发, 此处仅做格式校验
        QString tid = rule.value("time_template_id").toString();
        if (tid.length() > 64) {
            result["code"] = UnknownTimeTemplate;
            result["field"] = "time_template_id";
            result["message"] = "时间模板 ID 长度超限";
            return result;
        }
    }

    // 7. P1 #7 merge_cond 校验
    if (rule.contains("merge_cond")) {
        QVariantMap mr = validateMergeCond(rule.value("merge_cond").toMap());
        if (!mr.value("ok").toBool()) { result = mr; return result; }
    }

    // 8. P1 #8 time_cond 校验
    if (rule.contains("time_cond")) {
        QVariantMap tr = validateTimeCond(rule.value("time_cond").toMap());
        if (!tr.value("ok").toBool()) { result = tr; return result; }
    }

    // 9. P1 #5 condition_tree 校验
    if (rule.contains("condition_tree")) {
        QVariantMap ctr = validateConditionTree(rule.value("condition_tree").toMap());
        if (!ctr.value("ok").toBool()) { result = ctr; return result; }
    }

    // 10. P1 #6 mutex/suppress 校验
    QVariantMap sup;
    sup["mutex_group"] = rule.value("mutex_group");
    sup["suppress_after_rule"] = rule.value("suppress_after_rule");
    {
        QVariantMap sr = validateSuppression(sup);
        if (!sr.value("ok").toBool()) { result = sr; return result; }
    }

    result["ok"] = true;
    result["code"] = Ok;
    return result;
}

void LinkageController::createRule(const QVariantMap& rule) {
    QJsonObject body = QJsonObject::fromVariantMap(rule);
    m_api->post("/api/v1/linkage/rules", body,
        [this](QJsonObject obj) {
            // [FIX api-contract 2026-09-22] 响应为信封, 需 unwrapData;
            // 旧实现读信封顶层 → ruleCreated 载荷全空。
            emit ruleCreated(ApiClient::unwrapData(obj).toVariantMap());
            refreshRules();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::createRuleChecked(const QVariantMap& rule) {
    QVariantMap v = validateRule(rule, /*isUpdate=*/false);
    if (!v.value("ok").toBool()) {
        emit validationFailed(v.value("code").toInt(),
                              v.value("field").toString(),
                              v.value("message").toString());
        return;
    }
    createRule(rule);
}

void LinkageController::updateRuleChecked(const QString& ruleId, const QVariantMap& updates) {
    // 更新模式下,把 ruleId 注入校验上下文(优先看 updates.id, 否则用参数)
    QVariantMap merged = updates;
    if (!merged.contains("id") && !merged.contains("rule_id")) {
        merged["id"] = ruleId;
    }
    QVariantMap v = validateRule(merged, /*isUpdate=*/true);
    if (!v.value("ok").toBool()) {
        emit validationFailed(v.value("code").toInt(),
                              v.value("field").toString(),
                              v.value("message").toString());
        return;
    }
    updateRule(ruleId, updates);
}

// [P1-2 dry-run 2026-09-20] 规则模拟测试 (对齐 Web LinkageRuleView.vue:4918 调用样例)
//   后端契约: POST /api/v1/linkage/rules/dry-run (RestApiHandlers.cpp:19373)
//   通道走 channel_id_str 主形态 (GB28181 20 位编码, 防 int32 截断 [CID-P1 2026-09-16] 治理)
void LinkageController::dryRunRule(const QVariantMap& payload) {
    if (!m_api) {
        emit dryRunFailed(QStringLiteral("ApiClient 未初始化"));
        return;
    }
    QJsonObject body = QJsonObject::fromVariantMap(payload);
    m_api->post("/api/v1/linkage/rules/dry-run", body,
        [this](QJsonObject obj) {
            // 后端 makeOkResponse 信封: {code, message, data:{matched,...}} → 解包 data
            emit dryRunFinished(ApiClient::unwrapData(obj).toVariantMap());
        },
        [this](int code, QString msg) {
            emit dryRunFailed(QStringLiteral("dry-run 失败 [%1]: %2").arg(code).arg(msg));
        });
}

void LinkageController::updateRule(const QString& ruleId, const QVariantMap& updates) {
    QJsonObject body = QJsonObject::fromVariantMap(updates);
    m_api->put(QString("/api/v1/linkage/rules/%1").arg(ruleId), body,
        [this](QJsonObject) { refreshRules(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::deleteRule(const QString& ruleId) {
    m_api->del(QString("/api/v1/linkage/rules/%1").arg(ruleId),
        [this, ruleId]() {
            emit ruleDeleted(ruleId);
            refreshRules();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::toggleRule(const QString& ruleId, bool enabled) {
    QJsonObject body;
    body["enabled"] = enabled;
    m_api->put(QString("/api/v1/linkage/rules/%1").arg(ruleId), body,
        [this](QJsonObject) { refreshRules(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::refreshRules() {
    m_api->getList("/api/v1/linkage/rules",
        [this](QJsonArray arr) {
            m_rules.clear();
            for (const auto& item : arr)
                m_rules.append(item.toVariant().toMap());
            emit rulesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::refreshLogs(int limit) {
    m_api->getList(QString("/api/v1/linkage/logs?limit=%1").arg(limit),
        [this](QJsonArray arr) {
            m_logs.clear();
            for (const auto& item : arr)
                m_logs.append(item.toVariant().toMap());
            emit logsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::getRuleStats() {
    m_api->get("/api/v1/linkage/stats",
        [this](QJsonObject obj) {
            // [FIX api-contract 2026-09-22] 该端点信封 data 为数组
            // [{activeRules,successRate,totalTriggers,...}], 取首元素;
            // 旧实现直接 toVariantMap() 读信封顶层 → 字段全空。
            const QJsonValue dataVal = obj.value("data");
            QJsonObject data;
            if (dataVal.isArray() && !dataVal.toArray().isEmpty())
                data = dataVal.toArray().first().toObject();
            else
                data = ApiClient::unwrapData(obj);
            emit statsReceived(data.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
