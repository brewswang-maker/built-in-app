#pragma once
/**
 * @file RbacController.h
 * @brief RBAC 用户/角色/权限 Controller
 *
 * 对齐后端端点：
 *   - GET    /api/v1/users
 *   - PUT    /api/v1/users/:id
 *   - DELETE /api/v1/users/:id
 *   - POST   /api/v1/users/:id/reset-password
 *   - POST   /api/v1/users/import
 *   - GET    /api/v1/rbac/roles
 *   - POST   /api/v1/rbac/roles
 *   - PUT    /api/v1/rbac/roles/:id
 *   - DELETE /api/v1/rbac/roles/:id
 *   - GET    /api/v1/rbac/permissions
 *   - GET    /api/v1/rbac/permissions/tree
 *   - GET    /api/v1/rbac/users
 *   - POST   /api/v1/rbac/users/:userId/roles
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class RbacController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList users READ users NOTIFY usersUpdated)
    Q_PROPERTY(QVariantList roles READ roles NOTIFY rolesUpdated)
    Q_PROPERTY(QVariantMap permTree READ permTree NOTIFY permTreeUpdated)
    Q_PROPERTY(QVariantList currentUserRoles READ currentUserRoles NOTIFY currentUserChanged)
    Q_PROPERTY(QString currentUser READ currentUser NOTIFY currentUserChanged)
    Q_PROPERTY(QString currentRole READ currentRole NOTIFY currentUserChanged)

public:
    explicit RbacController(ApiClient* api, QObject* parent = nullptr);

    QVariantList users() const { return m_users; }
    QVariantList roles() const { return m_roles; }
    QVariantMap permTree() const { return m_permTree; }
    QVariantList currentUserRoles() const { return m_currentUserRoles; }
    QString currentUser() const { return m_currentUser; }
    QString currentRole() const { return m_currentRole; }

    Q_INVOKABLE void refreshUsers();
    Q_INVOKABLE void refreshRoles();
    Q_INVOKABLE void refreshPermissionTree();
    Q_INVOKABLE void refreshCurrentUser();

    Q_INVOKABLE void createUser(const QVariantMap& body);
    Q_INVOKABLE void updateUser(const QString& userId, const QVariantMap& body);
    Q_INVOKABLE void deleteUser(const QString& userId);
    Q_INVOKABLE void resetPassword(const QString& userId, const QString& newPwd);

    Q_INVOKABLE void createRole(const QVariantMap& body);
    Q_INVOKABLE void updateRole(const QString& roleId, const QVariantMap& body);
    Q_INVOKABLE void deleteRole(const QString& roleId);
    Q_INVOKABLE void assignRole(const QString& userId, const QString& roleId);
    Q_INVOKABLE void revokeRole(const QString& userId, const QString& roleId);

    Q_INVOKABLE bool hasPermission(const QString& resource, const QString& operation) const;

signals:
    void usersUpdated();
    void rolesUpdated();
    void permTreeUpdated();
    void currentUserChanged();
    void userCreated(const QString& userId);
    void userDeleted(const QString& userId);
    void roleCreated(const QString& roleId);
    void roleDeleted(const QString& roleId);
    void errorOccurred(int code, const QString& message);

private:
    void setCurrentUser(const QString& user, const QString& role,
                        const QVariantList& roles);

    ApiClient* m_api;
    QVariantList m_users;
    QVariantList m_roles;
    QVariantMap m_permTree;
    QVariantList m_currentUserRoles;
    QString m_currentUser;
    QString m_currentRole;
};