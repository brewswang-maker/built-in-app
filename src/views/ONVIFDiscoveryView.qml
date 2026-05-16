// ========================================================================
// ONVIFDiscoveryView.qml — ONVIF设备自动发现与管理
// 超越Web端: WS-Discovery实时扫描动画、SOAP协议调试器
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: onvifView

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
                property bool scanning: false
                onClicked: { scanning = !scanning; scanAnim.running = scanning }
            }
            Button {
                text: "➕ 手动添加"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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

                        // 设备标记
                        var devices = [
                            { dx: -40, dy: -30, name: "IPC-01", online: true },
                            { dx: 50, dy: -60, name: "IPC-02", online: true },
                            { dx: -70, dy: 20, name: "NVR-01", online: true },
                            { dx: 30, dy: 50, name: "IPC-03", online: true },
                            { dx: 60, dy: 10, name: "IPC-04", online: false },
                            { dx: -20, dy: 70, name: "IPC-05", online: true }
                        ]
                        for (var d = 0; d < devices.length; d++) {
                            var dev = devices[d]
                            ctx.fillStyle = dev.online ? "#00D4AA" : "#FF3D71"
                            ctx.beginPath()
                            ctx.arc(cx + dev.dx, cy + dev.dy, 5, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.fillStyle = "#8B8FA3"
                            ctx.font = "9px sans-serif"
                            ctx.fillText(dev.name, cx + dev.dx + 8, cy + dev.dy + 3)
                        }

                        // 本机标记
                        ctx.fillStyle = "#3B82F6"
                        ctx.beginPath(); ctx.arc(cx, cy, 7, 0, 2 * Math.PI); ctx.fill()
                        ctx.fillStyle = "#FFF"; ctx.font = "bold 9px sans-serif"
                        ctx.fillText("ShieldBox", cx + 10, cy + 3)
                    }

                    Timer { interval: 50; running: scanAnim.running; repeat: true; onTriggered: radarCanvas.requestPaint() }
                }

                // 子网信息
                Rectangle {
                    width: parent.width - 24; height: 80; color: "#0D0F12"; radius: 6
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text { text: "网络信息"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Text { text: "子网: 192.168.1.0/24"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "本机: 192.168.1.200"; font.pixelSize: 11; color: "#8B8FA3" }
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
                    Text { text: "6台"; font.pixelSize: 12; color: "#8B8FA3" }
                }

                ListView {
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { ip: "192.168.1.100"; name: "海康 DS-2CD3T46"; type: "IPC"; mac: "A0:BD:1D:xx:xx:01"; status: "online"; services: "Streaming,Event,PTZ" }
                        ListElement { ip: "192.168.1.101"; name: "大华 DH-IPC-HFW"; type: "IPC"; mac: "A0:BD:1D:xx:xx:02"; status: "online"; services: "Streaming,Event" }
                        ListElement { ip: "192.168.1.102"; name: "宇视 IPC6222SR"; type: "IPC"; mac: "A0:BD:1D:xx:xx:03"; status: "online"; services: "Streaming,PTZ" }
                        ListElement { ip: "192.168.1.110"; name: "海康 DS-7616NI"; type: "NVR"; mac: "A0:BD:1D:xx:xx:04"; status: "online"; services: "Streaming,Recording" }
                        ListElement { ip: "192.168.1.103"; name: "天地 TP-IPC-B"; type: "IPC"; mac: "A0:BD:1D:xx:xx:05"; status: "online"; services: "Streaming" }
                        ListElement { ip: "192.168.1.104"; name: "华为 IPC6212"; type: "IPC"; mac: "A0:BD:1D:xx:xx:06"; status: "offline"; services: "-" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 64; color: "#141720"; radius: 6

                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4

                            Row {
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: model.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: model.name; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                                Text { text: model.type; font.pixelSize: 11; color: "#3B82F6" }
                                Rectangle { width: 36; height: 16; radius: 3; color: model.status === "online" ? "#0A2A1A" : "#2A0A10"
                                    Text { text: model.status; font.pixelSize: 9; color: model.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.centerIn: parent }
                                }
                                Item { width: 20 }
                                Button { text: "添加"; font.pixelSize: 10; background: Rectangle { color: "#00D4AA"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "配置"; font.pixelSize: 10; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                            Row {
                                spacing: 12
                                Text { text: "IP: " + model.ip; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "MAC: " + model.mac; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "服务: " + model.services; font.pixelSize: 10; color: "#8B8FA3" }
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
                    width: parent.width - 24
                    model: ["GetDeviceInformation", "GetProfiles", "GetStreamUri", "GetCapabilities", "GetSnapshotUri", "RelativeMove", "AbsoluteMove", "ContinuousMove"]
                    background: Rectangle { color: "#252830"; radius: 6 }
                }

                TextField {
                    width: parent.width - 24; height: 28
                    text: "192.168.1.100"
                    placeholderText: "设备IP"
                    font.pixelSize: 12; color: "#E8E8E8"
                    background: Rectangle { color: "#252830"; radius: 4 }
                }

                Row {
                    spacing: 8
                    TextField { width: 80; text: "admin"; placeholderText: "用户名"; font.pixelSize: 11; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                    TextField { width: 80; text: "******"; placeholderText: "密码"; echoMode: TextInput.Password; font.pixelSize: 11; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                }

                Button {
                    text: "▶ 发送请求"
                    width: parent.width - 24
                    background: Rectangle { color: "#3B82F6"; radius: 6; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }

                Text { text: "响应:"; font.pixelSize: 12; color: "#8B8FA3" }

                ScrollView {
                    width: parent.width - 24; height: 200; clip: true
                    TextArea {
                        text: '<?xml version="1.0"?>\n<env:Envelope>\n  <env:Body>\n    <tds:GetDeviceInformationResponse>\n      <tds:Manufacturer>Hikvision</tds:Manufacturer>\n      <tds:Model>DS-2CD3T46</tds:Model>\n      <tds:FirmwareVersion>V5.7.1</tds:FirmwareVersion>\n      <tds:SerialNumber>DS2CD3T46...</tds:SerialNumber>\n      <tds:HardwareId>1684X</tds:HardwareId>\n    </tds:GetDeviceInformationResponse>\n  </env:Body>\n</env:Envelope>'
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
}
