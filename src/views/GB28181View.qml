// ========================================================================
// GB28181View.qml — GB28181设备管理 (SIP信令 + 目录订阅 + 级联)
// 数据源: deviceController (box-sdk REST API)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: gb28181View

    // ── SIP配置属性 ──
    property string sipDomain: ""
    property string sipId: ""
    property string sipPort: ""
    property string sipPassword: ""
    property string mediaServer: ""

    Component.onCompleted: {
        deviceController.refreshDevices()
        configController.loadConfig()
    }

    // ── 监听设备数据更新 ──
    Connections {
        target: deviceController
        function onDevicesUpdated() {
            deviceListView.model = deviceController.devices
            updateOnlineCount()
        }
    }

    // ── 监听配置加载完成 ──
    Connections {
        target: configController
        function onConfigUpdated() {
            var cfg = configController.config
            if (cfg["sip_domain"]) sipDomain = cfg["sip_domain"]
            if (cfg["sip_id"]) sipId = cfg["sip_id"]
            if (cfg["sip_port"]) sipPort = cfg["sip_port"]
            if (cfg["sip_password"]) sipPassword = cfg["sip_password"]
            if (cfg["media_server"]) mediaServer = cfg["media_server"]
        }
    }

    function updateOnlineCount() {
        var devices = deviceController.devices
        var online = 0
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].status === "online") online++
        }
        onlineCountText.text = "在线: " + online + " / 总计: " + devices.length
    }

    // ── 顶部 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "GB28181 设备管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            Button {
                text: "设备搜索"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.discoverDevices("gb28181")
            }
            Button {
                text: "手动添加"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: addDevicePopup.open()
            }
            Button {
                text: "刷新目录"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.refreshDevices()
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

                    Text { text: "SIP域:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        id: sipDomainField
                        text: sipDomain; font.pixelSize: 12; color: "#E8E8E8"; width: 160
                        background: Rectangle { color: "#252830"; radius: 4 }
                        onAccepted: configController.saveConfig("sip_domain", text)
                    }

                    Text { text: "SIP ID:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        id: sipIdField
                        text: sipId; font.pixelSize: 12; color: "#E8E8E8"; width: 160
                        background: Rectangle { color: "#252830"; radius: 4 }
                        onAccepted: configController.saveConfig("sip_id", text)
                    }

                    Text { text: "端口:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        id: sipPortField
                        text: sipPort; font.pixelSize: 12; color: "#E8E8E8"; width: 160
                        background: Rectangle { color: "#252830"; radius: 4 }
                        onAccepted: configController.saveConfig("sip_port", text)
                    }

                    Text { text: "密码:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        id: sipPasswordField
                        text: sipPassword; echoMode: TextInput.Password; font.pixelSize: 12; color: "#E8E8E8"; width: 160
                        background: Rectangle { color: "#252830"; radius: 4 }
                        onAccepted: configController.saveConfig("sip_password", text)
                    }

                    Text { text: "流媒体:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        id: mediaServerField
                        text: mediaServer; font.pixelSize: 12; color: "#E8E8E8"; width: 160
                        background: Rectangle { color: "#252830"; radius: 4 }
                        onAccepted: configController.saveConfig("media_server", text)
                    }
                }

                Button {
                    text: "保存配置"
                    width: parent.width - 24
                    background: Rectangle { color: "#00D4AA"; radius: 6; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        configController.saveConfig("sip_domain", sipDomainField.text)
                        configController.saveConfig("sip_id", sipIdField.text)
                        configController.saveConfig("sip_port", sipPortField.text)
                        configController.saveConfig("sip_password", sipPasswordField.text)
                        configController.saveConfig("media_server", mediaServerField.text)
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                Text { text: "SIP 信令监控"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                ListView {
                    id: sipLogView
                    width: parent.width - 24; height: 200; clip: true; spacing: 2
                    model: ListModel { id: sipLogModel }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 22; color: "transparent"
                        Row {
                            spacing: 6
                            Text { text: model.time; font.pixelSize: 12; color: "#4A4D58"; width: 50 }
                            Text { text: model.msg; font.pixelSize: 12; color: false ? "#3B82F6" : "#00D4AA"; width: 140 }
                            Text { text: model.status; font.pixelSize: 12; color: "#FFB800" }
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
                    Text { id: onlineCountText; text: "加载中..."; font.pixelSize: 12; color: "#8B8FA3" }
                }

                // 表头
                Rectangle {
                    width: parent.width - 24; height: 32; color: "#141720"; radius: 4
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8
                        Text { text: "设备ID"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 180 }
                        Text { text: "名称"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 100 }
                        Text { text: "厂商"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 80 }
                        Text { text: "通道数"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "状态"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 50 }
                        Text { text: "注册时间"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 100 }
                        Text { text: "操作"; font.pixelSize: 12; font.bold: true; color: "#8B8FA3"; width: 160 }
                    }
                }

                ListView {
                    id: deviceListView
                    width: parent.width - 24; height: parent.height - 90; clip: true; spacing: 2
                    model: deviceController.devices

                    delegate: Rectangle {
                        width: ListView.view.width; height: 40; color: index % 2 ? "#0D1015" : "transparent"
                        radius: 4

                        property var deviceData: modelData || model

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8; anchors.verticalCenter: parent.verticalCenter

                            Text { text: deviceData.deviceId || ""; font.pixelSize: 12; color: "#E8E8E8"; width: 180; elide: Text.ElideMiddle }
                            Text { text: deviceData.name || ""; font.pixelSize: 12; color: "#E8E8E8"; width: 100 }
                            Text { text: deviceData.manufacturer || ""; font.pixelSize: 12; color: "#8B8FA3"; width: 80 }
                            Text { text: (deviceData.channels !== undefined) ? deviceData.channels : "0"; font.pixelSize: 12; color: "#E8E8E8"; width: 50 }
                            Rectangle {
                                width: 50; height: 20; radius: 4
                                color: deviceData.status === "online" ? "#0A2A1A" : "#2A0A10"
                                Text {
                                    text: deviceData.status === "online" ? "在线" : "离线"
                                    font.pixelSize: 12; font.bold: true
                                    color: deviceData.status === "online" ? "#00D4AA" : "#FF3D71"
                                    anchors.centerIn: parent
                                }
                            }
                            Text { text: deviceData.registerTime || ""; font.pixelSize: 12; color: "#8B8FA3"; width: 100 }

                            Row {
                                spacing: 4
                                Button {
                                    text: "预览"; font.pixelSize: 12
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: mediaController.startStream(deviceData.deviceId, "ch1")
                                }
                                Button {
                                    text: "目录"; font.pixelSize: 12
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: deviceController.getDeviceDetail(deviceData.deviceId)
                                }
                                Button {
                                    text: "录像"; font.pixelSize: 12
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: mediaController.startStream(deviceData.deviceId, "record")
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

                Text { text: "级联拓扑"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: topoCanvas
                    width: parent.width - 24; height: 300

                    property var topoDevices: deviceController.devices

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

                        // 下级设备连线 — 从controller数据绘制
                        var devices = topoDevices
                        var maxShow = Math.min(devices.length, 6)
                        var spacing = Math.max(40, (width - 60) / maxShow)
                        for (var i = 0; i < maxShow; i++) {
                            var dev = devices[i]
                            var dx = 30 + i * spacing
                            var dy = 140 + (i % 2) * 15
                            var online = dev.status === "online"

                            ctx.strokeStyle = online ? "#00D4AA" : "#FF3D71"
                            ctx.beginPath()
                            ctx.moveTo(width/2, 100)
                            ctx.lineTo(dx + 30, dy)
                            ctx.stroke()

                            ctx.fillStyle = online ? "#1A3A2A" : "#3A1A1A"
                            ctx.fillRect(dx, dy, 60, 24)
                            ctx.fillStyle = online ? "#00D4AA" : "#FF3D71"
                            ctx.font = "9px sans-serif"
                            var label = (dev.name || "设备").substring(0, 8)
                            ctx.fillText(label, dx + 2, dy + 15)
                        }
                    }

                    Connections {
                        target: deviceController
                        function onDevicesUpdated() { topoCanvas.requestPaint() }
                    }
                    Component.onCompleted: requestPaint()
                }
            }
        }
    }

    // ── 手动添加设备弹窗 ──
    Popup {
        id: addDevicePopup
        anchors.centerIn: parent
        width: 360; height: 280
        background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10
            Text { text: "添加GB28181设备"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            TextField { id: addIp; width: 320; placeholderText: "设备IP地址"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: addPort; width: 320; text: "5060"; placeholderText: "SIP端口"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: addUser; width: 320; placeholderText: "用户名"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: addPass; width: 320; placeholderText: "密码"; echoMode: TextInput.Password; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            Row {
                spacing: 12
                Button {
                    text: "取消"
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: addDevicePopup.close()
                }
                Button {
                    text: "添加"
                    background: Rectangle { color: "#00D4AA"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        deviceController.addDevice("gb28181", addIp.text, parseInt(addPort.text), addUser.text, addPass.text)
                        addDevicePopup.close()
                    }
                }
            }
        }
    }
}
