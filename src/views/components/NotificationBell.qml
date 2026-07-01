// ========================================================================
// NotificationBell.qml — Header通知铃铛组件 (对标Web端)
// 显示未读数徽章，点击弹出NotificationPopup
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: bellRoot
    width: 40
    height: 32

    property int unreadCount: 0
    signal clicked()

    Button {
        anchors.fill: parent
        flat: true
        onClicked: bellRoot.clicked()

        background: Rectangle { color: "transparent" }
        contentItem: AppIcon {
            name: "bell"
            size: 18
            iconColor: "#E8E8E8"
            anchors.centerIn: parent
        }

        // Shake animation on new notification
        SequentialAnimation on rotation {
            id: shakeAnim
            running: false
            NumberAnimation { from: 0; to: 15; duration: 100 }
            NumberAnimation { from: 15; to: -15; duration: 100 }
            NumberAnimation { from: -15; to: 10; duration: 80 }
            NumberAnimation { from: 10; to: -10; duration: 80 }
            NumberAnimation { from: -10; to: 0; duration: 60 }
        }
    }

    // Unread badge
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        width: unreadCount > 0 ? Math.max(16, unreadBadge.implicitWidth + 8) : 0
        height: 16; radius: 8; color: "#FF3D71"
        visible: unreadCount > 0

        Text {
            id: unreadBadge
            anchors.centerIn: parent
            text: unreadCount > 99 ? "99+" : unreadCount
            font.pixelSize: 9; font.bold: true; color: "#FFF"
        }
    }

    onUnreadCountChanged: {
        if (unreadCount > 0) shakeAnim.start()
    }
}
