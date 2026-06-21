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
            QJsonArray arr = obj.value("items").toArray();
            if (arr.isEmpty()) arr = obj.value("users").toArray();
            if (arr.isEmpty() && obj.value("data").isArray())
                arr = obj.value("data").toArray();
            m_users.clear();
            for (const auto& v : arr) m_users.append(v.toVariant().toMap());
            emit usersUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshRoles() {
    m_api->get("/api/v1/rbac/roles",
        [this](QJsonObject obj) {
            QJsonArray arr = obj.value("items").toArray();
            if (arr.isEmpty()) arr = obj.value("roles").toArray();
            if (arr.isEmpty() && obj.value("data").isArray())
                arr = obj.value("data").toArray();
            m_roles.clear();
            for (const auto& v : arr) m_roles.append(v.toVariant().toMap());
            emit rolesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshPermissionTree() {
    m_api->get("/api/v1/rbac/permissions/tree",
        [this](QJsonObject obj) {
            m_permTree = obj.toVariantMap();
            emit permTreeUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::refreshCurrentUser() {
    m_api->get("/api/v1/auth/me",
        [this](QJsonObject obj) {
            QString user = obj.value("username").toString();
            QString role = obj.value("role").toString();
            QVariantList roles = obj.value("roles").toArray().toVariantList();
            setCurrentUser(user, role, roles);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RbacController::createUser(const QVariantMap& body) {
    m_api->post("/api/v1/users", QJsonObject::fromVariantMap(body),
        [this](QJsonObject obj) {
            QString id = obj.value("user_id").toString();
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
            QString id = obj.value("role_id").toString();
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
    // 简单校验：当前用户角色名包含资源关键字
    for (const auto& r : m_currentUserRoles) {
        QString name = r.toMap().value("name").toString();
        if (name == "admin" || name == "super_admin") return true;
        if (name.contains(resource, Qt::CaseInsensitive)) return true;
    }
    Q_UNUSED(operation);
    return false;
}