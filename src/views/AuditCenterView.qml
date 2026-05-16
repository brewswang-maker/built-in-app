// ========================================================================
// AuditCenterView.qml — 审计中心 (操作日志 + 安全审计 + 合规报告)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: auditCenter

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "📋 审计中心"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            TextField { width: 180; height: 32; placeholderText: "搜索日志..."; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            ComboBox { width: 100; model: ["全部类型", "登录", "配置", "设备", "告警", "算法", "系统"]; background: Rectangle { color: "#252830"; radius: 6 }; contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
            ComboBox { width: 80; model: ["全部级别", "信息", "警告", "错误", "严重"]; background: Rectangle { color: "#252830"; radius: 6 }; contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

            Button { text: "📥 导出"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 统计卡片 + 操作时间线 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 260
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📊 审计概览"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 统计卡片
                Column { spacing: 4; width: parent.width - 24
                    Repeater {
                        model: [
                            { label: "今日操作", value: "156", color: "#3B82F6" },
                            { label: "配置变更", value: "12", color: "#FFB800" },
                            { label: "安全事件", value: "3", color: "#FF3D71" },
                            { label: "告警处理", value: "89", color: "#00D4AA" }
                        ]
                        delegate: Rectangle {
                            width: parent.width; height: 36; color: "#0D0F12"; radius: 6
                            Row {
                                anchors.fill: parent; anchors.margins: 8; spacing: 8
                                Text { text: model.label; font.pixelSize: 11; color: "#8B8FA3" }
                                Item { width: 10 }
                                Text { text: model.value; font.pixelSize: 16; font.bold: true; color: model.color }
                            }
                        }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                Text { text: "🕐 最近操作"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: parent.height - 310; clip: true; spacing: 2

                    model: ListModel {
                        ListElement { time: "12:03:15"; user: "admin"; action: "修改算法配置"; detail: "人员检测阈值 0.5→0.6"; level: "info" }
                        ListElement { time: "12:01:42"; user: "admin"; action: "处理告警"; detail: "入侵告警 #1234 已确认"; level: "info" }
                        ListElement { time: "11:58:30"; user: "system"; action: "设备掉线"; detail: "华为IPC-05 连接超时"; level: "warning" }
                        ListElement { time: "11:55:12"; user: "admin"; action: "添加设备"; detail: "大华NVR-02 (ONVIF)"; level: "info" }
                        ListElement { time: "11:50:00"; user: "system"; action: "模型加载"; detail: "ppe_detect.bmodel → Slot3"; level: "info" }
                        ListElement { time: "11:45:33"; user: "admin"; action: "导出录像"; detail: "2026-05-16 10:00-11:00 CH1"; level: "info" }
                        ListElement { time: "11:42:18"; user: "system"; action: "安全扫描"; detail: "检测到3次异常登录尝试"; level: "error" }
                        ListElement { time: "11:38:00"; user: "admin"; action: "系统升级"; detail: "OTA v2.3.1 → v2.3.2 (A分区)"; level: "warning" }
                        ListElement { time: "11:30:15"; user: "admin"; action: "登录"; detail: "本地终端登录成功"; level: "info" }
                        ListElement { time: "11:25:00"; user: "system"; action: "自动备份"; detail: "配置数据库备份完成"; level: "info" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 36; color: "#0D0F12"; radius: 4
                        Column {
                            anchors.fill: parent; anchors.margins: 6; spacing: 1
                            Row {
                                spacing: 6
                                Rectangle { width: 6; height: 6; radius: 3; color: model.level === "error" ? "#FF3D71" : model.level === "warning" ? "#FFB800" : "#3B82F6"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: model.time; font.pixelSize: 9; color: "#4A4D58" }
                                Text { text: model.user; font.pixelSize: 9; color: "#3B82F6" }
                                Text { text: model.action; font.pixelSize: 9; color: "#E8E8E8"; font.bold: true }
                            }
                            Text { text: model.detail; font.pixelSize: 8; color: "#8B8FA3"; elide: Text.ElideRight; width: parent.width }
                        }
                    }
                }
            }
        }

        // ── 右侧: 详细日志表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "操作日志 (详细)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 表头
                Rectangle {
                    width: parent.width - 24; height: 28; color: "#141720"; radius: 4
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Text { text: "时间"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 70 }
                        Text { text: "用户"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "类型"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "操作"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 100 }
                        Text { text: "详情"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 200 }
                        Text { text: "IP"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 90 }
                        Text { text: "结果"; font.pixelSize: 10; font.bold: true; color: "#8B8FA3"; width: 40 }
                    }
                }

                ListView {
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 1

                    model: ListModel {
                        ListElement { time: "12:03:15"; user: "admin"; type: "配置"; action: "修改推理参数"; detail: "人员检测置信度 0.50→0.60, NMS 0.45→0.40"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "12:01:42"; user: "admin"; type: "告警"; action: "处理告警"; detail: "入侵告警 #1234 确认为误报, 已关闭"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "11:58:30"; user: "system"; type: "设备"; action: "设备掉线"; detail: "华为IPC-05 (192.168.1.105) 心跳超时60s"; ip: "-"; result: "异常" }
                        ListElement { time: "11:55:12"; user: "admin"; type: "设备"; action: "添加ONVIF设备"; detail: "大华NVR-02, IP:192.168.1.110, 16通道"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "11:50:00"; user: "system"; type: "算法"; action: "模型热加载"; detail: "ppe_detect_1684x.bmodel → TPU Slot3, INT8, 7.8MB"; ip: "-"; result: "成功" }
                        ListElement { time: "11:45:33"; user: "admin"; type: "录像"; action: "导出录像片段"; detail: "2026-05-16 10:00:00-11:00:00, CH1 海康IPC-01, MP4 1.2GB"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "11:42:18"; user: "system"; type: "安全"; action: "异常登录检测"; detail: "IP 192.168.1.200 连续3次SSH密码错误, 已自动封禁30min"; ip: "192.168.1.200"; result: "已拦截" }
                        ListElement { time: "11:38:00"; user: "admin"; type: "系统"; action: "OTA升级"; detail: "v2.3.1→v2.3.2, A分区, 完整包 45.2MB, MD5验证通过"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "11:30:15"; user: "admin"; type: "登录"; action: "本地终端登录"; detail: "Qt/QML内置应用, 用户:admin, 认证:本地密码"; ip: "127.0.0.1"; result: "成功" }
                        ListElement { time: "11:25:00"; user: "system"; type: "系统"; action: "自动备份"; detail: "SQLite数据库 → /data/backup/db_20260516_112500.sqlite, 2.3MB"; ip: "-"; result: "成功" }
                        ListElement { time: "11:20:00"; user: "system"; type: "设备"; action: "设备注册"; detail: "海康球机-08 GB28181 Register, SIP:34020000001320000008"; ip: "192.168.1.108"; result: "成功" }
                        ListElement { time: "11:15:30"; user: "admin"; type: "流媒体"; action: "手动拉流"; detail: "rtsp://192.168.1.103:554/live → ZLMediaKit, RTSP→RTMP/HLS"; ip: "127.0.0.1"; result: "成功" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 28; color: index % 2 ? "#0D1015" : "transparent"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                            Text { text: model.time; font.pixelSize: 10; color: "#4A4D58"; width: 70 }
                            Text { text: model.user; font.pixelSize: 10; color: "#3B82F6"; width: 50 }
                            Rectangle { width: 36; height: 14; radius: 3; color: "#1A1D23"
                                Text { text: model.type; font.pixelSize: 8; color: "#8B8FA3"; anchors.centerIn: parent }
                            }
                            Text { text: model.action; font.pixelSize: 10; color: "#E8E8E8"; width: 100 }
                            Text { text: model.detail; font.pixelSize: 9; color: "#8B8FA3"; width: 200; elide: Text.ElideMiddle }
                            Text { text: model.ip; font.pixelSize: 9; color: "#4A4D58"; width: 90 }
                            Text { text: model.result; font.pixelSize: 10; color: model.result === "成功" ? "#00D4AA" : model.result === "异常" ? "#FF3D71" : "#FFB800"; width: 40 }
                        }
                    }
                }
            }
        }
    }
}
