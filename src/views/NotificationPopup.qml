// ========================================================================
// NotificationPopup.qml — 通知面板 (告警/系统/任务通知)
// Controller: alarmController + statusController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: notifPopup
    width: 360; height: 460
    x: parent.width - width - 16; y: 56
    modal: false; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property int currentTab: 0
    property int unreadCount: alarmController.hasUnread ? 1 : 0

    background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830"; border.width: 1 }

    Component.onCompleted: {
        alarmController.refreshAlarms(20)
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() {
            notifListView.model = alarmController.alarms
            unreadCount = alarmController.hasUnread ? alarmController.alarmCount : 0
        }
        function onNewAlarm() {
            unreadCount++
        }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── 头部 ──
        Rectangle {
            Layout.fillWidth: true; height: 44; color: "#1A1D23"; radius: 12

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14

                Text { text: "🔔 通知"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Rectangle {
                    visible: unreadCount > 0; width: 24; height: 18; radius: 9; color: "#FF3D71"
                    Text { text: unreadCount > 99 ? "99+" : unreadCount; font.pixelSize: 9; color: "#FFF"; font.bold: true; anchors.centerIn: parent }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "全部已读"; font.pixelSize: 10
                    background: Rectangle { color: "transparent" }
                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#3B82F6" }
                    onClicked: {
                        unreadCount = 0
                        alarmController.refreshAlarms(20)
                    }
                }
                Button {
                    text: "✕"; font.pixelSize: 14
                    background: Rectangle { color: "transparent" }
                    contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#8B8FA3" }
                    onClicked: notifPopup.close()
                }
            }
        }

        // ── Tab切换 ──
        Row {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.topMargin: 8; spacing: 2

            Repeater {
                model: ["全部", "告警", "系统", "任务"]
                delegate: Button {
                    text: modelData; font.pixelSize: 11
                    background: Rectangle { color: notifPopup.currentTab === index ? "#3B82F6" : "#252830"; radius: 4; width: 56; height: 24 }
                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: notifPopup.currentTab === index ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: notifPopup.currentTab = index
                }
            }
        }

        // ── 通知列表 ──
        ListView {
            id: notifListView
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: 8; clip: true; spacing: 2
            model: alarmController.alarms

            delegate: Rectangle {
                width: ListView.view.width; height: 58; color: "#0D0F12"; radius: 6
                property var nData: modelData || model

                Row {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    // 类型图标
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: nData.level === "critical" ? "#2A0A10" : nData.level === "warning" ? "#2A2A0A" : "#0A1A2A"
                        Text {
                            text: nData.type === "alarm" ? "⚠️" : nData.type === "system" ? "🔧" : "📋"
                            font.pixelSize: 14; anchors.centerIn: parent
                        }
                    }

                    // 内容
                    Column {
                        spacing: 2; width: parent.width - 80
                        Text {
                            text: nData.type === "alarm" ? (nData.algoType || "告警") + " — " + (nData.channel || "通道") : (nData.title || "系统通知")
                            font.pixelSize: 11; color: "#E8E8E8"; font.bold: true
                            elide: Text.ElideRight; width: parent.width
                        }
                        Text {
                            text: nData.message || nData.detail || ""
                            font.pixelSize: 10; color: "#8B8FA3"
                            elide: Text.ElideRight; width: parent.width
                        }
                        Text { text: nData.time || ""; font.pixelSize: 9; color: "#4A4D58" }
                    }

                    // 操作
                    Column {
                        spacing: 2
                        Button {
                            text: "✓"; font.pixelSize: 10
                            visible: nData.status === "unhandled"
                            background: Rectangle { color: "#00D4AA"; radius: 3; width: 22; height: 18 }
                            contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: alarmController.confirmAlarm(nData.id || "")
                        }
                        Button {
                            text: "✕"; font.pixelSize: 10
                            visible: nData.status === "unhandled"
                            background: Rectangle { color: "#FF3D71"; radius: 3; width: 22; height: 18 }
                            contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: alarmController.markFalseAlarm(nData.id || "")
                        }
                    }
                }
            }
        }

        // ── 底栏 ──
        Rectangle {
            Layout.fillWidth: true; height: 36; color: "#1A1D23"; radius: 12
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                Text { text: "查看全部 →"; font.pixelSize: 11; color: "#3B82F6"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }
                Item { Layout.fillWidth: true }
                Text { text: "清空通知"; font.pixelSize: 10; color: "#8B8FA3"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: alarmController.refreshAlarms(0) }
                }
            }
        }
    }
}
