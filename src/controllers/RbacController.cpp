#include "RbacController.h"
#include "utils/ApiClient.h"
#include <QJsonObject>
#include <QJsonArray>

RbacController::RbacController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void RbacController::setCurrentUser(const QString& user, const QString& role,
                                     const QVariantList& roles) {
    m_currentUser = user;
    m_currentRole = role;
    m_currentUserRoles = roles;
    emit currentUserChanged();
}

void RbacController::refreshUsers() {
    m_api->get("/api/v1/users",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items/users/data:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "users", "data"});
            m_users.clear();
            for (const auto& v : arr) m_users.append(v.toVariant().toMap());
            emit usersUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshRoles() {
    m_api->get("/api/v1/rbac/roles",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items/roles/data:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "roles", "data"});
            m_roles.clear();
            for (const auto& v : arr) m_roles.append(v.toVariant().toMap());
            emit rolesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshPermissionTree() {
    m_api->get("/api/v1/rbac/permissions/tree",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{...权限树...}}
            m_permTree = ApiClient::unwrapData(obj).toVariantMap();
            emit permTreeUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshCurrentUser() {
    m_api->get("/api/v1/auth/me",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{user:{...}, permissions:[...], roles:[...]}}
            QJsonObject data = ApiClient::unwrapData(obj);
            // [P0-B 2026-09-21] 后端 data 无顶层 username/role 字段, 从 user 子对象取
            //   (RestApiHandlers.cpp:1352-1361: data={user,permissions,roles})
            QJsonObject userObj = data.value("user").toObject();
            QString user = data.value("username").toString();
            if (user.isEmpty()) user = userObj.value("username").toString();
            QVariantList roles = data.value("roles").toArray().toVariantList();
            QString role = data.value("role").toString();
            if (role.isEmpty() && !roles.isEmpty())
                role = roles.first().toMap().value("name").toString();
            // [P0-B 2026-09-21] 真权限点集合替换角色名启发式:
            //   admin/super_admin 仍直通; 其余按 auth/me 下发的
            //   permissions("resource:operation") 精确判定, 未下发=拒绝(fail-closed)。
            m_grantedPerms.clear();
            const auto perms = data.value("permissions").toArray();
            for (const auto& p : perms) m_grantedPerms.insert(p.toString());
            setCurrentUser(user, role, roles);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::createUser(const QVariantMap& body) {
    m_api->post("/api/v1/users", QJsonObject::fromVariantMap(body),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{user_id/id}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString id = data.value("user_id").toString();
            emit userCreated(id);
            refreshUsers();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::updateUser(const QString& userId, const QVariantMap& body) {
    m_api->put(QString("/api/v1/users/%1").arg(userId),
               QJsonObject::fromVariantMap(body),
        [this](QJsonObject) { refreshUsers(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::deleteUser(const QString& userId) {
    m_api->del(QString("/api/v1/users/%1").arg(userId),
        [this, userId]() { emit userDeleted(userId); refreshUsers(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::resetPassword(const QString& userId, const QString& newPwd) {
    QJsonObject body; body["password"] = newPwd;
    m_api->post(QString("/api/v1/users/%1/reset-password").arg(userId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::createRole(const QVariantMap& body) {
    m_api->post("/api/v1/rbac/roles", QJsonObject::fromVariantMap(body),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{role_id/id}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString id = data.value("role_id").toString();
            emit roleCreated(id);
            refreshRoles();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::updateRole(const QString& roleId, const QVariantMap& body) {
    m_api->put(QString("/api/v1/rbac/roles/%1").arg(roleId),
               QJsonObject::fromVariantMap(body),
        [this](QJsonObject) { refreshRoles(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::deleteRole(const QString& roleId) {
    m_api->del(QString("/api/v1/rbac/roles/%1").arg(roleId),
        [this, roleId]() { emit roleDeleted(roleId); refreshRoles(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::assignRole(const QString& userId, const QString& roleId) {
    QJsonObject body; body["role_id"] = roleId;
    m_api->post(QString("/api/v1/rbac/users/%1/roles").arg(userId), body,
        [this](QJsonObject) { refreshUsers(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::revokeRole(const QString& userId, const QString& roleId) {
    m_api->del(QString("/api/v1/rbac/users/%1/roles/%2").arg(userId, roleId),
        [this]() { refreshUsers(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

bool RbacController::hasPermission(const QString& resource,
                                    const QString& operation) const {
    // [P0-B 2026-09-21] 权限点精确判定, 替换原「角色名包含资源关键字」启发式
    //   (启发式曾致 viewer 角色名含 "device" 字样即放行 device.delete)。
    //   数据源: GET /api/v1/auth/me → data.permissions ("resource:operation"),
    //   与后端网关 RBACManager::hasPermission (SecurityManager.cpp:176) 对齐。
    for (const auto& r : m_currentUserRoles) {
        QString name = r.toMap().value("name").toString();
        if (name == "admin" || name == "super_admin") return true;
    }
    // 未就绪(未登录/未刷新)时拒绝 (fail-closed)
    return m_grantedPerms.contains(resource + ":" + operation);
}