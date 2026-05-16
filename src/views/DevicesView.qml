// ========================================================================
// DevicesView.qml — 设备管理中心 (设备列表 + 拓扑图 + 批量操作)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: devicesView

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "📹 设备管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            TextField { width: 200; height: 32; placeholderText: "搜索设备..."; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            Button { text: "➕ 添加设备"; font.pixelSize: 12; background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "🔍 发现设备"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "🔄 刷新"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    // ── 统计卡片 ──
    Rectangle {
        id: statsRow
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 64; color: "transparent"

        Row {
            anchors.fill: parent; spacing: 8

            Repeater {
                model: [
                    { icon: "📹", label: "总设备", value: "16", color: "#3B82F6" },
                    { icon: "🟢", label: "在线", value: "12", color: "#00D4AA" },
                    { icon: "🔴", label: "离线", value: "3", color: "#FF3D71" },
                    { icon: "🟡", label: "维护", value: "1", color: "#FFB800" },
                    { icon: "📡", label: "GB28181", value: "8", color: "#8B5CF6" },
                    { icon: "🔌", label: "ONVIF", value: "6", color: "#06B6D4" },
                    { icon: "📹", label: "总通道", value: "48", color: "#EC4899" },
                    { icon: "🧠", label: "AI通道", value: "32", color: "#F59E0B" }
                ]

                delegate: Rectangle {
                    width: (statsRow.width - 56) / 8; height: 64; color: "#141720"; radius: 8
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 2
                        Row { spacing: 4; Text { text: model.icon; font.pixelSize: 12 }; Text { text: model.label; font.pixelSize: 10; color: "#8B8FA3" } }
                        Text { text: model.value; font.pixelSize: 22; font.bold: true; color: model.color }
                    }
                }
            }
        }
    }

    // ── 设备列表 ──
    Rectangle {
        anchors.top: statsRow.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; color: "#0D0F12"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            // 表头
            Rectangle {
                width: parent.width - 24; height: 32; color: "#141720"; radius: 4
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    Text { text: "状态"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 40 }
                    Text { text: "设备名称"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 120 }
                    Text { text: "IP地址"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 110 }
                    Text { text: "协议"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 60 }
                    Text { text: "厂商/型号"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 140 }
                    Text { text: "通道"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 40 }
                    Text { text: "AI算法"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 120 }
                    Text { text: "码流"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 60 }
                    Text { text: "操作"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 200 }
                }
            }

            ListView {
                width: parent.width - 24; height: parent.height - 80; clip: true; spacing: 2

                model: ListModel {
                    ListElement { name: "海康IPC-01"; ip: "192.168.1.100"; proto: "GB28181"; mfr: "海康 DS-2CD3T46"; channels: 4; status: "online"; algo: "入侵,烟火"; bitrate: "6Mbps" }
                    ListElement { name: "大华IPC-02"; ip: "192.168.1.101"; proto: "ONVIF"; mfr: "大华 DH-IPC-HFW"; channels: 2; status: "online"; algo: "PPE检测"; bitrate: "4Mbps" }
                    ListElement { name: "宇视NVR-01"; ip: "192.168.1.102"; proto: "GB28181"; mfr: "宇视 IPC6222SR"; channels: 16; status: "online"; algo: "入侵,PPE,烟火"; bitrate: "48Mbps" }
                    ListElement { name: "海康IPC-03"; ip: "192.168.1.103"; proto: "RTSP"; mfr: "海康 DS-2CD2T47"; channels: 1; status: "online"; algo: "车牌识别"; bitrate: "4Mbps" }
                    ListElement { name: "天地IPC-04"; ip: "192.168.1.104"; proto: "ONVIF"; mfr: "天地 TP-IPC-B2"; channels: 1; status: "online"; algo: "-"; bitrate: "2Mbps" }
                    ListElement { name: "华为IPC-05"; ip: "192.168.1.105"; proto: "GB28181"; mfr: "华为 IPC6212"; channels: 2; status: "offline"; algo: "-"; bitrate: "-" }
                    ListElement { name: "海康IPC-06"; ip: "192.168.1.106"; proto: "EHOME"; mfr: "海康 DS-2CD3T26"; channels: 1; status: "online"; algo: "入侵"; bitrate: "2Mbps" }
                    ListElement { name: "大华NVR-02"; ip: "192.168.1.110"; proto: "ONVIF"; mfr: "大华 DH-NVR4216"; channels: 16; status: "online"; algo: "-"; bitrate: "32Mbps" }
                    ListElement { name: "宇视IPC-07"; ip: "192.168.1.107"; proto: "GB28181"; mfr: "宇视 IPC6222SD"; channels: 1; status: "offline"; algo: "入侵"; bitrate: "-" }
                    ListElement { name: "海康球机-08"; ip: "192.168.1.108"; proto: "GB28181"; mfr: "海康 DS-2DE4425IW"; channels: 1; status: "maintenance"; algo: "人脸"; bitrate: "-" }
                }

                delegate: Rectangle {
                    width: ListView.view.width; height: 44; color: index % 2 ? "#0D1015" : "transparent"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                        Rectangle { width: 8; height: 8; radius: 4; color: model.status === "online" ? "#00D4AA" : model.status === "maintenance" ? "#FFB800" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: model.name; font.pixelSize: 12; color: "#E8E8E8"; width: 120; elide: Text.ElideMiddle }
                        Text { text: model.ip; font.pixelSize: 11; color: "#3B82F6"; width: 110 }
                        Text { text: model.proto; font.pixelSize: 11; color: "#8B5CF6"; width: 60 }
                        Text { text: model.mfr; font.pixelSize: 10; color: "#8B8FA3"; width: 140; elide: Text.ElideMiddle }
                        Text { text: model.channels; font.pixelSize: 11; color: "#E8E8E8"; width: 40 }
                        Text { text: model.algo; font.pixelSize: 10; color: "#00D4AA"; width: 120; elide: Text.ElideMiddle }
                        Text { text: model.bitrate; font.pixelSize: 10; color: "#8B8FA3"; width: 60 }

                        Row {
                            spacing: 4
                            Button { text: "详情"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "预览"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "配置"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "重启"; font.pixelSize: 9; visible: model.status === "online"; background: Rectangle { color: "#FFB800"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#0D0F12"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
            }
        }
    }
}
