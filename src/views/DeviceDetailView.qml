// ========================================================================
// DeviceDetailView.qml — 设备详情 (通道管理 + 算法配置 + 码流信息)
// 超越Web端: 实时码流参数调节、SNMPTrap监听、继电器/IO控制
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: deviceDetail

    property string deviceId: ""
    property string deviceName: "海康IPC-01"

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Button {
                text: "← 返回"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Text { text: "📹 " + deviceName; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA" }
            Text { text: "在线"; font.pixelSize: 12; color: "#00D4AA" }
            Item { Layout.fillWidth: true }
            Button { text: "🔄 刷新"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "🗑 删除"; font.pixelSize: 12; background: Rectangle { color: "#FF3D71"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 设备信息 + 通道 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 380
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                // 设备基本信息
                Text { text: "📋 设备信息"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 6; width: parent.width - 24
                    Text { text: "设备ID:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "34020000001320000001"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "IP地址:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "192.168.1.100"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "协议:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "GB28181"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "厂商:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "海康威视"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "型号:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "DS-2CD3T46WDV3"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "固件:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "V5.7.1 build 210312"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "通道数:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "4 (在线:3 / 离线:1)"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "注册时间:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "2026-05-16 08:00:15"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "运行时长:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "3小时32分"; font.pixelSize: 11; color: "#E8E8E8" }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                // 通道列表
                Text { text: "📹 通道列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: 180; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { ch: "CH1"; name: "主码流"; type: "H.265 4K@25fps"; bitrate: "6144kbps"; status: "online" }
                        ListElement { ch: "CH2"; name: "子码流"; type: "H.264 1080P@15fps"; bitrate: "2048kbps"; status: "online" }
                        ListElement { ch: "CH3"; name: "三码流"; type: "H.264 720P@15fps"; bitrate: "1024kbps"; status: "online" }
                        ListElement { ch: "CH4"; name: "四码流"; type: "JPEG 640x480@1fps"; bitrate: "256kbps"; status: "offline" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#0D0F12"; radius: 4
                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2
                            Row {
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: model.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: model.ch + " " + model.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                Button { text: "预览"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 3; width: 32; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                            Text { text: model.type + " | " + model.bitrate; font.pixelSize: 10; color: "#8B8FA3" }
                        }
                    }
                }
            }
        }

        // ── 中间: 算法配置 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "🧠 算法配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { name: "人员入侵检测"; model: "person_detect.bmodel"; enabled: true; confidence: 0.85; fps: 25.4; tpu: "32%" }
                        ListElement { name: "烟火检测"; model: "fire_smoke.bmodel"; enabled: true; confidence: 0.80; fps: 28.1; tpu: "22%" }
                        ListElement { name: "安全帽检测"; model: "ppe_detect.bmodel"; enabled: true; confidence: 0.90; fps: 22.0; tpu: "18%" }
                        ListElement { name: "区域入侵"; model: "region_detect.bmodel"; enabled: false; confidence: 0.75; fps: 0; tpu: "0%" }
                        ListElement { name: "车牌识别"; model: "plate_recog.bmodel"; enabled: false; confidence: 0.88; fps: 0; tpu: "0%" }
                        ListElement { name: "人脸比对"; model: "face_recog.bmodel"; enabled: false; confidence: 0.92; fps: 0; tpu: "0%" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 72; color: "#141720"; radius: 6

                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4

                            Row {
                                spacing: 8; width: parent.width
                                Switch {
                                    checked: model.enabled
                                    onCheckedChanged: console.log(model.name, checked)
                                }
                                Text { text: model.name; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                                Item { width: 10 }
                                Text { text: model.fps > 0 ? model.fps + " FPS" : "未启用"; font.pixelSize: 11; color: model.fps > 0 ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "TPU " + model.tpu; font.pixelSize: 10; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
                            }

                            Row {
                                spacing: 12
                                Text { text: "模型:" + model.model; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "置信度:" + (model.confidence * 100) + "%"; font.pixelSize: 10; color: "#8B8FA3" }
                                Button { text: "设置ROI"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 3; width: 48; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "测试"; font.pixelSize: 9; background: Rectangle { color: "#3B82F6"; radius: 3; width: 32; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }
            }
        }

        // ── 右侧: IO控制面板 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 220
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "⚡ IO控制"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 继电器输出
                GroupBox {
                    title: "继电器输出"
                    width: parent.width - 24; font.pixelSize: 12; label.color: "#E8E8E8"

                    Column { spacing: 6; width: parent.width
                        Repeater {
                            model: ["继电器1 (警灯)", "继电器2 (警铃)", "继电器3 (门禁)"]
                            delegate: Row {
                                spacing: 8
                                Text { text: modelData; font.pixelSize: 11; color: "#E8E8E8"; width: 120 }
                                Button { text: "触发"; font.pixelSize: 10; background: Rectangle { color: "#FF3D71"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }

                // DI输入状态
                GroupBox {
                    title: "DI输入状态"
                    width: parent.width - 24; font.pixelSize: 12; label.color: "#E8E8E8"

                    Column { spacing: 6; width: parent.width
                        Repeater {
                            model: [
                                { name: "DI1 (门磁)", state: "闭合" },
                                { name: "DI2 (红外)", state: "断开" },
                                { name: "DI3 (烟感)", state: "正常" }
                            ]
                            delegate: Row {
                                spacing: 8
                                Rectangle { width: 8; height: 8; radius: 4; color: modelData.state === "闭合" || modelData.state === "正常" ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.name; font.pixelSize: 11; color: "#E8E8E8"; width: 80 }
                                Text { text: modelData.state; font.pixelSize: 11; color: "#8B8FA3" }
                            }
                        }
                    }
                }

                // 串口通信
                GroupBox {
                    title: "串口通信"
                    width: parent.width - 24; font.pixelSize: 12; label.color: "#E8E8E8"

                    Column { spacing: 6; width: parent.width
                        Text { text: "RS485: /dev/ttyS3"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "波特率: 9600"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "协议: Pelco-D"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "状态: 已连接"; font.pixelSize: 11; color: "#00D4AA" }
                    }
                }
            }
        }
    }
}
