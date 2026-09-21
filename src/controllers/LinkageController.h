#pragma once
/**
 * @file LinkageController.h
 * @brief 联动规则 Controller (v7.5 严格校验对齐 + v7.6 完整字段)
 *
 * 功能:
 *   - 规则 CRUD (list / create / update / delete / toggle)
 *   - 严格前端校验 (AddRuleError 7 类, 镜像 box-sdk LinkageEngine::AddRuleError)
 *   - 已知动作类型校验 (58 类: CLIENT_* 26 / WEB_* 12 / APP_* 5 / MP_* 3 / SYS_* 12)
 *   - 优先级范围校验 [0, 100]
 *   - 重复 rule_id 检测 (与本地缓存比对)
 *   - 条件树 (AND/OR/LEAF) 深度限制 + 结构校验
 *   - merge_cond / time_cond / mutex_group / suppress_after_rule 验证
 *
 * 对齐规范:
 *   - 82ec775a (代码真实性): 所有校验使用真实已知动作类型集合, 严禁字符串白名单绕过
 *   - 72d2dd9b (联动规则完整字段定义)
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QSet>
#include <QString>
#include <QHash>

class ApiClient;

class LinkageController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rules READ rules NOTIFY rulesUpdated)
    Q_PROPERTY(QVariantList logs READ logs NOTIFY logsUpdated)
    Q_PROPERTY(int totalRules READ totalRules NOTIFY rulesUpdated)
    Q_PROPERTY(int enabledRules READ enabledRules NOTIFY rulesUpdated)

public:
    enum AddRuleError {
        Ok = 0,
        EmptyRuleId = 1,
        EmptyName = 2,
        DuplicateId = 3,
        UnknownActionType = 4,
        NoActions = 5,
        InvalidPriority = 6,
        UnknownTimeTemplate = 7
    };
    Q_ENUM(AddRuleError)

    explicit LinkageController(ApiClient* api, QObject* parent = nullptr);

    QVariantList rules() const { return m_rules; }
    QVariantList logs() const { return m_logs; }
    int totalRules() const { return m_rules.size(); }
    int enabledRules() const;

    Q_INVOKABLE void refreshRules();
    Q_INVOKABLE void createRule(const QVariantMap& rule);
    Q_INVOKABLE void updateRule(const QString& ruleId, const QVariantMap& updates);
    Q_INVOKABLE void deleteRule(const QString& ruleId);
    Q_INVOKABLE void toggleRule(const QString& ruleId, bool enabled);
    Q_INVOKABLE void refreshLogs(int limit = 50);
    Q_INVOKABLE void getRuleStats();

    Q_INVOKABLE QVariantMap validateRule(const QVariantMap& rule, bool isUpdate = false) const;
    Q_INVOKABLE void createRuleChecked(const QVariantMap& rule);
    Q_INVOKABLE void updateRuleChecked(const QString& ruleId, const QVariantMap& updates);

    // [P1-2 dry-run 2026-09-20] 规则模拟测试 (对齐 Web LinkageRuleView.vue:4918 调用)
    //   payload: rule_id/alarm_type/channel_id_str/severity/confidence/region_id/location_id
    //   响应 data 信封: {matched, rule_details[], simulated_actions[]}
    Q_INVOKABLE void dryRunRule(const QVariantMap& payload);

    Q_INVOKABLE QStringList knownActionTypes() const;
    Q_INVOKABLE QVariantMap actionTypesByPrefix() const;

    // [P1-#1 v3.0 R1] 动作类型元数据 (含 param_schema)
    Q_PROPERTY(QVariantList actionTypesMeta READ actionTypesMeta CONSTANT)
    Q_PROPERTY(QVariantMap actionParamSchemas READ actionParamSchemas CONSTANT)
    QVariantList actionTypesMeta() const { return m_actionTypes; }
    QVariantMap actionParamSchemas() const { return m_actionSchemas; }
    Q_INVOKABLE void refreshActionTypes();  // GET /api/v1/linkage/action-types

    // P1 #5 条件树相关
    Q_INVOKABLE QStringList allRuleIds(const QString& excludeId = QString()) const;
    Q_INVOKABLE QVariantMap validateConditionTree(const QVariantMap& tree) const;

    // P1 #6 互斥与抑制
    Q_INVOKABLE QVariantMap validateSuppression(const QVariantMap& sup) const;

    // P1 #7 合并窗口
    Q_INVOKABLE QVariantMap validateMergeCond(const QVariantMap& merge) const;

    // P1 #8 时间条件
    Q_INVOKABLE QVariantMap validateTimeCond(const QVariantMap& time) const;

signals:
    void rulesUpdated();
    void actionTypesUpdated();
    void logsUpdated();
    void ruleCreated(const QVariantMap& rule);
    void ruleDeleted(const QString& ruleId);
    void statsReceived(const QVariantMap& stats);
    void errorOccurred(int code, const QString& message);
    void validationFailed(int code, const QString& field, const QString& message);
    // [P1-2 dry-run] 模拟测试结果 / 失败
    void dryRunFinished(const QVariantMap& result);
    void dryRunFailed(const QString& message);

private:
    void buildKnownActionSet();
    QVariantMap validateConditionTreeRec(const QVariantMap& node, int depth) const;

    ApiClient* m_api;
    QVariantList m_rules;
    QVariantList m_logs;
    QSet<QString> m_knownActionTypes;
    QHash<QString, QStringList> m_actionByPrefix;
    QVariantList m_actionTypes;
    QVariantMap m_actionSchemas;
};
