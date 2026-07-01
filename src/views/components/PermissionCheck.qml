// ========================================================================
// PermissionCheck.qml — RBAC 按钮级权限包装组件 (对标 web-admin v-permission)
// 用法: PermissionCheck { perm: "device.delete"; Button { ... } }
// 或:   PermissionCheck { perm: "user.create"; mode: "hide" | "disable" }
// Controller: rbacController.hasPermission(resource, operation)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: permCheck

    // "device.delete" resource="device", operation="delete"
    property string perm: ""
    // "hide"(默认) 或 "disable"
    property string mode: "hide"
    // 子内容
    default property alias content: container.data

    readonly property bool granted: {
        if (perm.length === 0) return true
        var parts = perm.split(".")
        if (parts.length < 2) return true
        return rbacController.hasPermission(parts[0], parts[1])
    }

    visible: mode === "hide" ? granted : true
    opacity: mode === "disable" && !granted ? 0.4 : 1.0

    Item {
        id: container
        anchors.fill: parent
    }

    // 无权限时拦截点击的遮罩
    MouseArea {
        id: blockMouse
        anchors.fill: parent
        hoverEnabled: true
        z: 999
        enabled: permCheck.mode === "disable" && !permCheck.granted
        propagateComposedEvents: false
        onEntered: {
            if (!permCheck.granted) {
                tip.text = "无权限: " + permCheck.perm
                tip.open()
            }
        }
        onExited: tip.close()
        onClicked: {
            // 静默拦截
        }

        ToolTip {
            id: tip
            delay: 200
            timeout: 2000
        }
    }
}
