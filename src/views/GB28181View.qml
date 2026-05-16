// ========================================================================
// GB28181View.qml — GB28181设备管理 (SIP信令 + 目录订阅 + 级联)
// 超越Web端: 实时SIP信令监控、级联拓扑可视化
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: gb28181View

    // ── 顶部 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "📡 GB28181 设备管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            Button {
                text: "🔍 设备搜索"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.discoverDevices()
            }
            Button {
                text: "➕ 手动添加"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "🔄 刷新目录"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.refreshCatalog()
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: SIP服务器配置 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "SIP 服务器配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 6; width: parent.width - 24

                    Text { text: "SIP域:"; font.pixelSize: 11; color: "#8B8FA3" }
                    TextField { text: "3402000000"; font.pixelSize: 12; color: "#E8E8E8"; width: 160; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "SIP ID:"; font.pixelSize: 11; color: "#8B8FA3" }
                    TextField { text: "34020000002000000001"; font.pixelSize: 12; color: "#E8E8E8"; width: 160; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "端口:"; font.pixelSize: 11; color: "#8B8FA3" }
                    TextField { text: "5060"; font.pixelSize: 12; color: "#E8E8E8"; width: 160; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "密码:"; font.pixelSize: 11; color: "#8B8FA3" }
                    TextField { text: "12345678"; echoMode: TextInput.Password; font.pixelSize: 12; color: "#E8E8E8"; width: 160; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "流媒体:"; font.pixelSize: 11; color: "#8B8FA3" }
                    TextField { text: "127.0.0.1:5554"; font.pixelSize: 12; color: "#E8E8E8"; width: 160; background: Rectangle { color: "#252830"; radius: 4 } }
                }

                Button {
                    text: "💾 保存配置"
                    width: parent.width - 24
                    background: Rectangle { color: "#00D4AA"; radius: 6; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                // SIP信令监控
                Text { text: "📡 SIP 信令监控"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: 200; clip: true; spacing: 2
                    model: ListModel {
                        ListElement { time: "11:32:15"; msg: "← REGISTER 340200...01"; status: "200 OK" }
                        ListElement { time: "11:32:14"; msg: "→ 200 OK"; status: "" }
                        ListElement { time: "11:31:00"; msg: "→ CATALOG 查询"; status: "200 OK" }
                        ListElement { time: "11:30:55"; msg: "← 200 OK (5设备)"; status: "" }
                        ListElement { time: "11:28:10"; msg: "→ INVITE 通道01"; status: "推流中" }
                        ListElement { time: "11:28:09"; msg: "← 200 SDP"; status: "" }
                        ListElement { time: "11:15:30"; msg: "← NOTIFY 心跳"; status: "" }
                        ListElement { time: "11:10:00"; msg: "→ KEEPALIVE"; status: "" }
                    }
                    delegate: Rectangle {
                        width: ListView.view.width; height: 22; color: "transparent"
                        Row {
                            spacing: 6
                            Text { text: model.time; font.pixelSize: 9; color: "#4A4D58"; width: 50 }
                            Text { text: model.msg; font.pixelSize: 10; color: model.msg.charAt(0) === '←' ? "#3B82F6" : "#00D4AA"; width: 140 }
                            Text { text: model.status; font.pixelSize: 9; color: "#FFB800" }
                        }
                    }
                }
            }
        }

        // ── 中间: 设备列表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Row {
                    spacing: 12; width: parent.width
                    Text { text: "已注册设备"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Text { text: "在线: 5 / 总计: 6"; font.pixelSize: 12; color: "#8B8FA3" }
                }

                // 表头
                Rectangle {
                    width: parent.width - 24; height: 32; color: "#141720"; radius: 4
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8
                        Text { text: "设备ID"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 180 }
                        Text { text: "名称"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 100 }
                        Text { text: "厂商"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 80 }
                        Text { text: "通道数"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "状态"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "注册时间"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 100 }
                        Text { text: "操作"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 160 }
                    }
                }

                ListView {
                    width: parent.width - 24; height: parent.height - 90; clip: true; spacing: 2

                    model: ListModel {
                        ListElement { deviceId: "34020000001320000001"; name: "海康IPC-01"; mfr: "海康"; channels: 4; status: "online"; regTime: "2026-05-16 08:00" }
                        ListElement { deviceId: "34020000001320000002"; name: "大华IPC-02"; mfr: "大华"; channels: 2; status: "online"; regTime: "2026-05-16 08:01" }
                        ListElement { deviceId: "34020000001320000003"; name: "宇视NVR-01"; mfr: "宇视"; channels: 16; status: "online"; regTime: "2026-05-16 08:02" }
                        ListElement { deviceId: "34020000001320000004"; name: "海康IPC-03"; mfr: "海康"; channels: 1; status: "online"; regTime: "2026-05-16 08:03" }
                        ListElement { deviceId: "34020000001320000005"; name: "天地IPC-04"; mfr: "天地"; channels: 1; status: "online"; regTime: "2026-05-16 08:05" }
                        ListElement { deviceId: "34020000001320000006"; name: "华为IPC-05"; mfr: "华为"; channels: 2; status: "offline"; regTime: "2026-05-15 19:30" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 40; color: index % 2 ? "#0D1015" : "transparent"
                        radius: 4

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8; anchors.verticalCenter: parent.verticalCenter

                            Text { text: model.deviceId; font.pixelSize: 11; color: "#E8E8E8"; width: 180; elide: Text.ElideMiddle }
                            Text { text: model.name; font.pixelSize: 11; color: "#E8E8E8"; width: 100 }
                            Text { text: model.mfr; font.pixelSize: 11; color: "#8B8FA3"; width: 80 }
                            Text { text: model.channels; font.pixelSize: 11; color: "#E8E8E8"; width: 50 }
                            Rectangle {
                                width: 50; height: 20; radius: 4
                                color: model.status === "online" ? "#0A2A1A" : "#2A0A10"
                                Text {
                                    text: model.status === "online" ? "在线" : "离线"
                                    font.pixelSize: 10; font.bold: true
                                    color: model.status === "online" ? "#00D4AA" : "#FF3D71"
                                    anchors.centerIn: parent
                                }
                            }
                            Text { text: model.regTime; font.pixelSize: 10; color: "#8B8FA3"; width: 100 }

                            Row {
                                spacing: 4
                                Button {
                                    text: "预览"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                                Button {
                                    text: "目录"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                                Button {
                                    text: "录像"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 右侧: 级联拓扑 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 240
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "🔗 级联拓扑"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: topoCanvas
                    width: parent.width - 24; height: 300

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        // 上级平台
                        ctx.fillStyle = "#3B82F6"
                        ctx.fillRect(width/2-40, 10, 80, 30)
                        ctx.fillStyle = "#FFF"; ctx.font = "10px sans-serif"
                        ctx.fillText("上级平台", width/2-22, 30)

                        // 连线
                        ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(width/2, 40); ctx.lineTo(width/2, 70); ctx.stroke()

                        // 本级平台
                        ctx.fillStyle = "#00D4AA"
                        ctx.fillRect(width/2-50, 70, 100, 30)
                        ctx.fillStyle = "#0D0F12"; ctx.font = "10px sans-serif"
                        ctx.fillText("ShieldBox (本级)", width/2-38, 90)

                        // 下级设备连线
                        var devices = [
                            { x: 30, y: 140, name: "海康IPC-01", online: true },
                            { x: 100, y: 150, name: "大华IPC-02", online: true },
                            { x: 170, y: 140, name: "宇视NVR-01", online: true }
                        ]
                        for (var i = 0; i < devices.length; i++) {
                            ctx.strokeStyle = devices[i].online ? "#00D4AA" : "#FF3D71"
                            ctx.beginPath()
                            ctx.moveTo(width/2, 100)
                            ctx.lineTo(devices[i].x + 30, devices[i].y)
                            ctx.stroke()

                            ctx.fillStyle = devices[i].online ? "#1A3A2A" : "#3A1A1A"
                            ctx.fillRect(devices[i].x, devices[i].y, 60, 24)
                            ctx.fillStyle = devices[i].online ? "#00D4AA" : "#FF3D71"
                            ctx.font = "9px sans-serif"
                            ctx.fillText(devices[i].name, devices[i].x + 2, devices[i].y + 15)
                        }
                    }
                    Component.onCompleted: requestPaint()
                }
            }
        }
    }
}
