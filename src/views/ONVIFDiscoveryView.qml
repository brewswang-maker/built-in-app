// ========================================================================
// ONVIFDiscoveryView.qml — ONVIF设备自动发现与管理
// 数据源: deviceController (box-sdk REST API)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: onvifView

    property bool scanning: false

    Component.onCompleted: {
        deviceController.refreshDevices()
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() {
            discoveredListView.model = deviceController.devices
            updateDeviceCount()
        }
    }

    function updateDeviceCount() {
        var devices = deviceController.devices
        var count = devices.length
        deviceCountText.text = count + "台"
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "🔌 ONVIF 设备发现"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            Button {
                text: scanning ? "⏹ 停止扫描" : "🔍 开始扫描"
                font.pixelSize: 12
                background: Rectangle { color: scanning ? "#FF3D71" : "#3B82F6"; radius: 6; width: 120; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    scanning = !scanning
                    scanAnim.running = scanning
                    if (scanning) {
                        deviceController.discoverDevices("onvif")
                    }
                }
            }
            Button {
                text: "➕ 手动添加"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: addOnvifPopup.open()
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 扫描雷达动画 + 网络拓扑 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 300
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📡 网络扫描"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 雷达扫描动画
                Canvas {
                    id: radarCanvas
                    width: parent.width - 24; height: 260

                    property real angle: 0
                    property var radarDevices: deviceController.devices

                    SequentialAnimation on angle {
                        id: scanAnim
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 360; duration: 3000 }
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        var cx = width/2, cy = 130, r = 110
                        ctx.clearRect(0, 0, width, height)

                        // 同心圆
                        for (var i = 3; i >= 1; i--) {
                            ctx.strokeStyle = "#1A2A3A"
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.arc(cx, cy, r * i / 3, 0, 2 * Math.PI)
                            ctx.stroke()
                        }

                        // 十字线
                        ctx.beginPath(); ctx.moveTo(cx - r, cy); ctx.lineTo(cx + r, cy); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(cx, cy - r); ctx.lineTo(cx, cy + r); ctx.stroke()

                        // 扫描扇形
                        if (scanAnim.running) {
                            var grad = ctx.createConicGradient(angle * Math.PI / 180 - Math.PI/2, cx, cy)
                            grad.addColorStop(0, "rgba(0,212,170,0.3)")
                            grad.addColorStop(0.12, "rgba(0,212,170,0.0)")
                            grad.addColorStop(1, "rgba(0,212,170,0.0)")
                            ctx.fillStyle = grad
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.fill()
                        }

                        // 设备标记 — 从controller数据绘制
                        var devices = radarDevices
                        var maxShow = Math.min(devices.length, 8)
                        var positions = [
                            {dx:-40, dy:-30}, {dx:50, dy:-60}, {dx:-70, dy:20},
                            {dx:30, dy:50}, {dx:60, dy:10}, {dx:-20, dy:70},
                            {dx:0, dy:-80}, {dx:-60, dy:-50}
                        ]
                        for (var d = 0; d < maxShow; d++) {
                            var dev = devices[d]
                            var pos = positions[d]
                            var online = dev.status === "online"
                            ctx.fillStyle = online ? "#00D4AA" : "#FF3D71"
                            ctx.beginPath()
                            ctx.arc(cx + pos.dx, cy + pos.dy, 5, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.fillStyle = "#8B8FA3"
                            ctx.font = "9px sans-serif"
                            var label = (dev.name || "设备").substring(0, 8)
                            ctx.fillText(label, cx + pos.dx + 8, cy + pos.dy + 3)
                        }

                        // 本机标记
                        ctx.fillStyle = "#3B82F6"
                        ctx.beginPath(); ctx.arc(cx, cy, 7, 0, 2 * Math.PI); ctx.fill()
                        ctx.fillStyle = "#FFF"; ctx.font = "bold 9px sans-serif"
                        ctx.fillText("ShieldBox", cx + 10, cy + 3)
                    }

                    Connections {
                        target: deviceController
                        function onDevicesUpdated() { radarCanvas.requestPaint() }
                    }

                    Timer { interval: 50; running: scanAnim.running; repeat: true; onTriggered: radarCanvas.requestPaint() }
                }

                // 子网信息 — 从config获取
                Rectangle {
                    width: parent.width - 24; height: 80; color: "#0D0F12"; radius: 6
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text { text: "网络信息"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Text { text: "子网: " + (configController.networkConfig.subnet || "192.168.1.0/24"); font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "本机: " + (configController.networkConfig.hostIp || "192.168.1.200"); font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "扫描范围: 192.168.1.1 - 192.168.1.254"; font.pixelSize: 11; color: "#8B8FA3" }
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
                    spacing: 12
                    Text { text: "已发现设备"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Text { id: deviceCountText; text: "0台"; font.pixelSize: 12; color: "#8B8FA3" }
                }

                ListView {
                    id: discoveredListView
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4
                    model: deviceController.devices

                    delegate: Rectangle {
                        width: ListView.view.width; height: 64; color: "#141720"; radius: 6

                        property var devData: modelData || model

                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4

                            Row {
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: devData.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: devData.name || ""; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                                Text { text: devData.type || "IPC"; font.pixelSize: 11; color: "#3B82F6" }
                                Rectangle {
                                    width: 36; height: 16; radius: 3
                                    color: devData.status === "online" ? "#0A2A1A" : "#2A0A10"
                                    Text { text: devData.status || "unknown"; font.pixelSize: 9; color: devData.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.centerIn: parent }
                                }
                                Item { width: 20 }
                                Button {
                                    text: "添加"; font.pixelSize: 10
                                    background: Rectangle { color: "#00D4AA"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: deviceController.addDevice("onvif", devData.ip, 80, "", "")
                                }
                                Button {
                                    text: "配置"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: deviceController.getDeviceDetail(devData.deviceId)
                                }
                            }
                            Row {
                                spacing: 12
                                Text { text: "IP: " + (devData.ip || ""); font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "MAC: " + (devData.mac || ""); font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "服务: " + (devData.services || "-"); font.pixelSize: 10; color: "#8B8FA3" }
                            }
                        }
                    }
                }
            }
        }

        // ── 右侧: SOAP调试器 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "🔧 SOAP 调试器"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ComboBox {
                    id: soapMethodCombo
                    width: parent.width - 24
                    model: ["GetDeviceInformation", "GetProfiles", "GetStreamUri", "GetCapabilities", "GetSnapshotUri", "RelativeMove", "AbsoluteMove", "ContinuousMove"]
                    background: Rectangle { color: "#252830"; radius: 6 }
                }

                TextField {
                    id: soapDeviceIp
                    width: parent.width - 24; height: 28
                    placeholderText: "设备IP"
                    font.pixelSize: 12; color: "#E8E8E8"
                    background: Rectangle { color: "#252830"; radius: 4 }
                }

                Row {
                    spacing: 8
                    TextField { id: soapUser; width: 80; placeholderText: "用户名"; font.pixelSize: 11; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                    TextField { id: soapPass; width: 80; placeholderText: "密码"; echoMode: TextInput.Password; font.pixelSize: 11; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                }

                Button {
                    text: "▶ 发送请求"
                    width: parent.width - 24
                    background: Rectangle { color: "#3B82F6"; radius: 6; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        // 通过deviceController发起SOAP请求
                        deviceController.getDeviceDetail(soapDeviceIp.text)
                    }
                }

                Text { text: "响应:"; font.pixelSize: 12; color: "#8B8FA3" }

                ScrollView {
                    width: parent.width - 24; height: 200; clip: true
                    TextArea {
                        id: soapResponseArea
                        text: "等待请求..."
                        font.pixelSize: 10; color: "#00D4AA"
                        font.family: "monospace"
                        wrapMode: Text.WordWrap
                        background: Rectangle { color: "#0A0C10"; radius: 4 }
                        readOnly: true
                    }
                }
            }
        }
    }

    // ── 手动添加ONVIF设备弹窗 ──
    Popup {
        id: addOnvifPopup
        anchors.centerIn: parent
        width: 360; height: 300
        background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10
            Text { text: "➕ 添加ONVIF设备"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            TextField { id: onvifIp; width: 320; placeholderText: "设备IP地址"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: onvifPort; width: 320; text: "80"; placeholderText: "ONVIF端口"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: onvifUser; width: 320; placeholderText: "用户名"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            TextField { id: onvifPass; width: 320; placeholderText: "密码"; echoMode: TextInput.Password; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            Row {
                spacing: 12
                Button {
                    text: "取消"
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: addOnvifPopup.close()
                }
                Button {
                    text: "添加"
                    background: Rectangle { color: "#00D4AA"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        deviceController.addDevice("onvif", onvifIp.text, parseInt(onvifPort.text), onvifUser.text, onvifPass.text)
                        addOnvifPopup.close()
                    }
                }
            }
        }
    }
}
