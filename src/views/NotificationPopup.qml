// ========================================================================
// NotificationPopup.qml — 通知中心弹窗 (对标Web端NotificationBell+Popup)
// 显示系统通知、告警摘要、任务完成、OTA更新等消息
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: notifPopup
    width: 360
    height: 480
    color: "transparent"
    flags: Qt.Popup | Qt.FramelessWindowHint

    property var notifications: []
    property int unreadCount: 0

    signal markRead(int index)
    signal markAllRead()
    signal clearAll()

    Rectangle {
        anchors.fill: parent; radius: 12; color: "#1A1D23"
        border.color: "#252830"; border.width: 1

        Column {
            anchors.fill: parent; spacing: 0

            // Header
            Rectangle {
                width: parent.width; height: 44; color: "#141720"; radius: 12
                // Bottom corners square
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 12; color: "#141720" }

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Text { text: "🔔 通知中心"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    Rectangle { width: 24; height: 20; radius: 10; color: "#FF3D71"; visible: notifPopup.unreadCount > 0
                        Text { text: notifPopup.unreadCount; font.pixelSize: 10; color: "#FFF"; font.bold: true; anchors.centerIn: parent } }

                    Item { Layout.fillWidth: true }

                    Button { text: "全部已读"; font.pixelSize: 10
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#3B82F6" }
                        onClicked: notifPopup.markAllRead()
                    }
                    Button { text: "清空"; font.pixelSize: 10
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FF6B35" }
                        onClicked: notifPopup.clearAll()
                    }
                }
            }

            // Filter tabs
            Row {
                width: parent.width; height: 32; spacing: 0

                Repeater {
                    model: ["全部", "告警", "系统", "任务"]
                    delegate: Button {
                        width: parent.parent.width / 4; height: 32
                        text: modelData; font.pixelSize: 11
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#252830" }

            // Notification list
            ListView {
                width: parent.width; height: parent.height - 44 - 32 - 1
                spacing: 1; clip: true

                model: ListModel {
                    ListElement { type: "alarm"; icon: "🚨"; title: "严重告警: 周界入侵"; detail: "3号厂区东围墙检测到人员翻越"; time: "2分钟前"; read: false; level: "critical" }
                    ListElement { type: "system"; icon: "🔄"; title: "固件更新可用"; detail: "v2.3.3 已发布，包含安全补丁"; time: "15分钟前"; read: false; level: "info" }
                    ListElement { type: "task"; icon: "🧠"; title: "联邦学习 Round 48 完成"; detail: "精度: 92.6% (+0.2%)"; time: "1小时前"; read: false; level: "success" }
                    ListElement { type: "alarm"; icon: "⚠️"; title: "设备离线告警"; detail: "摄像头 CH-07 断开连接"; time: "2小时前"; read: true; level: "warning" }
                    ListElement { type: "task"; icon: "📦"; title: "模型热替换完成"; detail: "person_detect_v3.2.bmodel 已加载到Slot 1"; time: "3小时前"; read: true; level: "success" }
                    ListElement { type: "system"; icon: "📊"; title: "日报已生成"; detail: "5月15日安全日报已保存"; time: "6小时前"; read: true; level: "info" }
                }

                delegate: Rectangle {
                    width: ListView.view.width; height: 64
                    color: modelData.read ? "transparent" : "#0A1520"
                    opacity: modelData.read ? 0.6 : 1.0

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10

                        // Type icon with level color
                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: modelData.level === "critical" ? "#2A0A0A" :
                                   modelData.level === "warning" ? "#2A1A0A" :
                                   modelData.level === "success" ? "#0A2A1A" : "#0A0A2A"
                            Text { text: modelData.icon; font.pixelSize: 16; anchors.centerIn: parent }
                        }

                        // Content
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            Text { text: modelData.title; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.detail; font.pixelSize: 10; color: "#8B8FA3"; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.time; font.pixelSize: 9; color: "#4A4D58" }
                        }

                        // Unread dot
                        Rectangle { width: 8; height: 8; radius: 4; color: "#3B82F6"; visible: !modelData.read }
                    }

                    MouseArea { anchors.fill: parent; onClicked: notifPopup.markRead(index) }
                }
            }
        }
    }
}
