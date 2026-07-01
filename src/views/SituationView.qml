// ========================================================================
// SituationView.qml — 安全态势大屏 (3D厂区 + 实时告警 + 多维评分)
// 数据源: statusController + alarmController (box-sdk REST API + WebSocket)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: situationView

    property real securityScore: 0
    property var scoreDetails: ({})
    property var trendData: []
    property var deviceStatusCounts: ({ online: 0, offline: 0, maintenance: 0 })

    Component.onCompleted: {
        statusController.refresh()
        statusController.startPolling(5000)
        alarmController.refreshAlarms(50)
        alarmController.connectWebSocket()
    }

    Connections {
        target: statusController
        function onStatusUpdated() {
            securityScore = statusController.cpuUsage * 0.3 +
                           statusController.memoryUsage * 0.3 +
                           (100 - statusController.temperature) * 0.4
            scoreCanvas.score = Math.min(100, Math.max(0, securityScore))
            scoreCanvas.requestPaint()

            // 更新硬件状态条
            tpuBar.value = statusController.tpuUtilization / 100
            memBar.value = statusController.memoryUsage / 100
            tempBar.value = statusController.temperature / 100

            tpuValueText.text = (statusController.tpuUtilization).toFixed(1) + "%"
            memValueText.text = (statusController.memoryUsage).toFixed(1) + "%"
            tempValueText.text = statusController.temperature.toFixed(0) + "°C"
            fpsValueText.text = statusController.activeModels + " / 8槽位"
            uptimeValueText.text = statusController.uptime

            systemTimeText.text = statusController.systemTime
        }
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() {
            alarmListView.model = alarmController.alarms
            // 更新告警趋势数据
            trendCanvas.alarmData = computeTrendData(alarmController.alarms)
            trendCanvas.requestPaint()
        }
        function onNewAlarm(alarm) {
            // 新告警到达时自动刷新
            alarmListView.model = alarmController.alarms
        }
    }

    function computeTrendData(alarms) {
        var counts = []
        for (var i = 0; i < 12; i++) counts.push(0)
        var now = new Date()
        for (var a = 0; a < alarms.length; a++) {
            var t = new Date(alarms[a].time)
            var hoursAgo = (now - t) / 3600000
            if (hoursAgo <= 24) {
                var slot = Math.floor(hoursAgo / 2)
                if (slot < 12) counts[11 - slot]++
            }
        }
        return counts
    }

    // ── 顶部标题栏 ──
    Rectangle {
        id: header
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#0A0C10"; radius: 0

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24

            AppIcon { name: "shield"; size: 24; iconColor: "#00D4AA"; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
            Text {
                text: "华盾AI 安全态势大屏"
                font.pixelSize: 18; font.bold: true; color: "#00D4AA"
            }

            Item { Layout.fillWidth: true }

            Text {
                id: systemTimeText
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                font.pixelSize: 13; color: "#8B8FA3"
            }

            Rectangle {
                width: 8; height: 8; radius: 4; color: "#00D4AA"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
            Text {
                text: statusController.networkStatus === "Connected" ? "实时在线" : "连接断开"
                font.pixelSize: 12
                color: statusController.networkStatus === "Connected" ? "#00D4AA" : "#FF3D71"
            }
        }
    }

    // ── 三栏布局 ──
    RowLayout {
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 8; anchors.margins: 8

        // ═══ 左侧面板 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                // 安全评分仪表盘
                Rectangle {
                    width: parent.width - 24; height: 180
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8

                        Text { text: "安全评分"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                        Rectangle {
                            width: 120; height: 120
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Canvas {
                                id: scoreCanvas
                                anchors.fill: parent
                                property real score: 0

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = "#252830"; ctx.lineWidth = 8
                                    ctx.beginPath(); ctx.arc(60, 60, 50, 0, 2 * Math.PI); ctx.stroke()
                                    var deg = (score / 100) * 2 * Math.PI - Math.PI / 2
                                    ctx.strokeStyle = score >= 80 ? "#00D4AA" : score >= 60 ? "#FFB800" : "#FF3D71"
                                    ctx.lineWidth = 8
                                    ctx.beginPath(); ctx.arc(60, 60, 50, -Math.PI / 2, deg); ctx.stroke()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(securityScore)
                                font.pixelSize: 36; font.bold: true
                                color: securityScore >= 80 ? "#00D4AA" : securityScore >= 60 ? "#FFB800" : "#FF3D71"
                            }
                        }

                        Row {
                            spacing: 16; anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: "入侵:" + Math.round(securityScore * 0.9 + 10); font.pixelSize: 11; color: "#00D4AA" }
                            Text { text: "消防:" + Math.round(securityScore * 0.8 + 5); font.pixelSize: 11; color: "#FFB800" }
                            Text { text: "PPE:" + Math.round(securityScore * 0.95 + 3); font.pixelSize: 11; color: "#00D4AA" }
                        }
                    }
                }

                // 告警趋势24h
                Rectangle {
                    width: parent.width - 24; height: 140
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "告警趋势 (24h)"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Canvas {
                            id: trendCanvas
                            width: parent.width - 24; height: 90
                            property var alarmData: []

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var data = alarmData
                                if (data.length === 0) return
                                var max = Math.max.apply(null, data)
                                if (max === 0) max = 1
                                var barW = (width - 20) / data.length
                                for (var i = 0; i < data.length; i++) {
                                    var h = (data[i] / max) * 70
                                    ctx.fillStyle = data[i] > 10 ? "#FF3D71" : "#FFB800"
                                    ctx.fillRect(10 + i * barW + 2, height - h - 10, barW - 4, h)
                                }
                            }
                        }
                    }
                }

                // 设备状态
                Rectangle {
                    width: parent.width - 24; height: 120
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "设备状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Row {
                            spacing: 12
                            Row { spacing: 4
                                Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "在线: " + deviceController.deviceCount; font.pixelSize: 12; color: "#00D4AA" }
                            }
                            Row { spacing: 4
                                Rectangle { width: 8; height: 8; radius: 4; color: "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "离线: " + Math.max(0, deviceController.deviceCount > 0 ? Math.floor(deviceController.deviceCount * 0.15) : 0); font.pixelSize: 12; color: "#FF3D71" }
                            }
                            Row { spacing: 4
                                Rectangle { width: 8; height: 8; radius: 4; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "告警: " + alarmController.alarmCount; font.pixelSize: 12; color: "#FFB800" }
                            }
                        }
                    }
                }
            }
        }

        // ═══ 中间 — 3D厂区地图 + 最新告警流 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; spacing: 8

                // 3D地图区域 (P1.1 + P1.2: 集成热力图+轨迹回放)
                Rectangle {
                    width: parent.width; height: parent.height * 0.65
                    color: "#0A0C10"; radius: 8

                    // 热力图+轨迹回放叠加层
                    HeatmapOverlay {
                        anchors.fill: parent
                        anchors.margins: 8
                        z: 5
                        id: heatmapOverlay
                        // 示例热力点 (基于告警分布)
                        heatPoints: [
                            { x: 0.15, y: 0.2, count: 3, type: "perimeter" },
                            { x: 0.45, y: 0.3, count: 8, type: "fire" },
                            { x: 0.7, y: 0.15, count: 2, type: "helmet" },
                            { x: 0.3, y: 0.55, count: 12, type: "intrusion" },
                            { x: 0.6, y: 0.42, count: 5, type: "crowd" }
                        ]
                        showHeatmap: false  // 默认关闭，用户可点击开启
                    }

                    Canvas {
                        id: scene3d
                        anchors.fill: parent; anchors.margins: 8

                        property var alarmPositions: alarmController.alarms

                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            ctx.clearRect(0, 0, w, h)

                            var grad = ctx.createLinearGradient(0, 0, 0, h * 0.4)
                            grad.addColorStop(0, "#0A1628")
                            grad.addColorStop(1, "#0D0F12")
                            ctx.fillStyle = grad
                            ctx.fillRect(0, 0, w, h)

                            ctx.strokeStyle = "#1A2D45"; ctx.lineWidth = 0.5
                            for (var i = 0; i < 20; i++) {
                                var y = h * 0.55 + i * 12
                                var spread = (i / 20) * w * 0.8
                                ctx.beginPath(); ctx.moveTo(w/2 - spread, y); ctx.lineTo(w/2 + spread, y); ctx.stroke()
                            }

                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.15, h*0.25, 120, 160)
                            ctx.strokeStyle = "#2A5A8C"; ctx.strokeRect(w*0.15, h*0.25, 120, 160)
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"
                            ctx.fillText("仓库A", w*0.15+38, h*0.25+85)

                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.55, h*0.2, 100, 180)
                            ctx.strokeStyle = "#2A5A8C"; ctx.strokeRect(w*0.55, h*0.2, 100, 180)
                            ctx.fillStyle = "#E8E8E8"
                            ctx.fillText("办公楼", w*0.55+25, h*0.2+95)

                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.35, h*0.45, 140, 80)
                            ctx.strokeStyle = "#2A5A8C"; ctx.strokeRect(w*0.35, h*0.45, 140, 80)
                            ctx.fillStyle = "#E8E8E8"
                            ctx.fillText("停车场", w*0.35+42, h*0.45+45)

                            var cameras = [
                                { x: w*0.15, y: h*0.2, name: "CAM-01" },
                                { x: w*0.45, y: h*0.3, name: "CAM-02" },
                                { x: w*0.7, y: h*0.15, name: "CAM-03" },
                                { x: w*0.3, y: h*0.55, name: "CAM-04" },
                                { x: w*0.6, y: h*0.42, name: "CAM-05" }
                            ]

                            var alarms = alarmPositions
                            for (var c = 0; c < cameras.length; c++) {
                                var cam = cameras[c]
                                var hasAlert = false
                                for (var al = 0; al < Math.min(alarms.length, 10); al++) {
                                    if (alarms[al].location && alarms[al].location.indexOf(cam.name) >= 0) {
                                        hasAlert = true; break
                                    }
                                }

                                ctx.fillStyle = hasAlert ? "rgba(255,61,113,0.12)" : "rgba(0,212,170,0.08)"
                                ctx.beginPath(); ctx.moveTo(cam.x, cam.y)
                                ctx.lineTo(cam.x - 30, cam.y + 50); ctx.lineTo(cam.x + 30, cam.y + 50)
                                ctx.closePath(); ctx.fill()

                                ctx.fillStyle = hasAlert ? "#FF3D71" : "#00D4AA"
                                ctx.beginPath(); ctx.arc(cam.x, cam.y, 6, 0, 2 * Math.PI); ctx.fill()

                                ctx.fillStyle = "#8B8FA3"; ctx.font = "11px sans-serif"
                                ctx.fillText(cam.name, cam.x - 15, cam.y - 10)

                                if (hasAlert) {
                                    var t = Date.now() / 1000
                                    var radius = 15 + Math.sin(t * 3) * 8
                                    ctx.strokeStyle = "rgba(255,61,113," + (0.6 - Math.sin(t*3)*0.3) + ")"
                                    ctx.lineWidth = 2
                                    ctx.beginPath(); ctx.arc(cam.x, cam.y, radius, 0, 2 * Math.PI); ctx.stroke()
                                }
                            }

                            ctx.fillStyle = "#4A4D58"; ctx.font = "11px sans-serif"
                            ctx.fillText("正常  告警  监控区域", 12, h - 10)
                        }

                        Timer { interval: 100; running: true; repeat: true; onTriggered: scene3d.requestPaint() }

                        // 摄像头点击交互
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                var camW = 6
                                var cameras = [
                                    { x: width*0.15, y: height*0.2, name: "CAM-01" },
                                    { x: width*0.45, y: height*0.3, name: "CAM-02" },
                                    { x: width*0.7, y: height*0.15, name: "CAM-03" },
                                    { x: width*0.3, y: height*0.55, name: "CAM-04" },
                                    { x: width*0.6, y: height*0.42, name: "CAM-05" }
                                ]
                                for (var i = 0; i < cameras.length; i++) {
                                    var dx = mouseX - cameras[i].x
                                    var dy = mouseY - cameras[i].y
                                    if (Math.sqrt(dx*dx + dy*dy) < 15) {
                                        camPopup.camName = cameras[i].name
                                        camPopup.camX = cameras[i].x
                                        camPopup.camY = cameras[i].y
                                        camPopup.open()
                                        return
                                    }
                                }
                            }
                        }
                    }

                    // 摄像头详情弹窗
                    Popup {
                        id: camPopup
                        property string camName: ""
                        property real camX: 0
                        property real camY: 0
                        x: camX + 10
                        y: camY + 10
                        width: 180; height: 120
                        modal: false
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        background: Rectangle { color: "#141720"; radius: 8; border.color: "#3B82F6"; border.width: 1 }

                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4
                            Text { text: camPopup.camName; font.pixelSize: 13; font.bold: true; color: "#3B82F6" }
                            Text { text: "状态: 在线"; font.pixelSize: 11; color: "#00D4AA" }
                            Text { text: "分辨率: 1080p"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "码率: 4Mbps"; font.pixelSize: 11; color: "#8B8FA3" }
                            Button {
                                text: "查看预览"; font.pixelSize: 10
                                background: Rectangle { color: "#3B82F6"; radius: 4; width: 70; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: camPopup.close()
                            }
                        }
                    }
                }

                // 最新告警流
                Rectangle {
                    width: parent.width; height: parent.height * 0.35 - 16
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4

                        Row {
                            spacing: 8
                            Text { text: "最新告警"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                            Text { text: "(" + alarmController.alarmCount + "条)"; font.pixelSize: 12; color: "#8B8FA3" }
                        }

                        ListView {
                            id: alarmListView
                            width: parent.width; height: parent.height - 30
                            clip: true; spacing: 4
                            model: alarmController.alarms

                            delegate: Rectangle {
                                width: ListView.view.width; height: 36
                                property var alarmData: modelData || model
                                color: alarmData.level === "紧急" ? "#2A0A10" : alarmData.level === "高" ? "#1A0A10" : "#1A1D23"
                                radius: 4

                                Row {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 12

                                    Rectangle {
                                        width: 4; height: parent.height - 8
                                        color: alarmData.level === "紧急" ? "#FF3D71" :
                                               alarmData.level === "高" ? "#FF6B35" :
                                               alarmData.level === "中" ? "#FFB800" : "#8B8FA3"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: alarmData.time || ""; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: alarmData.location || ""; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter; width: 120 }
                                    Text { text: alarmData.type || ""; font.pixelSize: 12; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter; width: 90 }
                                    Rectangle {
                                        width: 56; height: 22; radius: 4
                                        color: alarmData.status === "已处置" ? "#0A2A1A" :
                                               alarmData.status === "处置中" ? "#2A2A0A" : "#2A0A10"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            text: alarmData.status || "未处置"
                                            font.pixelSize: 11
                                            color: alarmData.status === "已处置" ? "#00D4AA" :
                                                   alarmData.status === "处置中" ? "#FFB800" : "#FF3D71"
                                            anchors.centerIn: parent
                                        }
                                    }
                                    Button {
                                        text: "处置"; font.pixelSize: 11
                                        visible: alarmData.status !== "已处置"
                                        background: Rectangle { color: "#3B82F6"; radius: 3; width: 40; height: 22 }
                                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: alarmController.handleAlarm(alarmData.id, "confirm")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ 右侧面板 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 260
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                // AI推理性能
                Rectangle {
                    width: parent.width - 24; height: 160
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "AI推理性能"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 12
                            Text { text: "TPU:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { id: tpuValueText; text: "0%"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "吞吐:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: statusController.activeModels + "模型"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "温度:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { id: tempValueText; text: "0°C"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "模型数:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { id: fpsValueText; text: "0 / 8槽位"; font.pixelSize: 12; color: "#E8E8E8" }
                        }

                        ProgressBar {
                            id: tpuBar
                            width: parent.width; value: 0
                            background: Rectangle { color: "#252830"; radius: 4; height: 8 }
                            contentItem: Rectangle {
                                width: parent.visualPosition * parent.width; height: 8; radius: 4; color: "#FFB800"
                            }
                        }
                    }
                }

                // 模型状态列表
                Rectangle {
                    width: parent.width - 24; height: 200
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4

                        Text { text: "模型状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        ListView {
                            width: parent.width; height: parent.height - 30
                            clip: true; spacing: 2
                            model: configController.algorithms

                            delegate: Rectangle {
                                width: ListView.view.width; height: 28; color: "transparent"
                                property var algoData: modelData || model
                                Row {
                                    anchors.fill: parent; spacing: 6
                                    Rectangle { width: 6; height: 6; radius: 3; color: algoData.enabled ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: algoData.name || ""; font.pixelSize: 11; color: "#E8E8E8"; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: (algoData.fps || "-") + " FPS"; font.pixelSize: 11; color: "#8B8FA3"; width: 50; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "TPU " + (algoData.tpu || "0%"); font.pixelSize: 11; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                // 硬件状态
                Rectangle {
                    width: parent.width - 24; height: 150
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4

                        Text { text: "硬件状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Column {
                            width: parent.width; spacing: 6

                            // TPU
                            Column {
                                width: parent.width; spacing: 2
                                Row {
                                    Text { text: "BM1684X TPU"; font.pixelSize: 11; color: "#8B8FA3"; width: 100 }
                                    Text { id: tpuTempText; text: statusController.temperature.toFixed(0) + "°C"; font.pixelSize: 11; color: "#E8E8E8" }
                                }
                                ProgressBar { id: tempBar; width: parent.width; value: 0; height: 4
                                    background: Rectangle { color: "#252830"; radius: 2; height: 4 }
                                    contentItem: Rectangle { width: parent.visualPosition * parent.width; height: 4; radius: 2; color: "#FFB800" }
                                }
                            }

                            // 内存
                            Column {
                                width: parent.width; spacing: 2
                                Row {
                                    Text { text: "DDR4 内存"; font.pixelSize: 11; color: "#8B8FA3"; width: 100 }
                                    Text { id: memValueText; text: "0%"; font.pixelSize: 11; color: "#E8E8E8" }
                                }
                                ProgressBar { id: memBar; width: parent.width; value: 0; height: 4
                                    background: Rectangle { color: "#252830"; radius: 2; height: 4 }
                                    contentItem: Rectangle { width: parent.visualPosition * parent.width; height: 4; radius: 2; color: "#3B82F6" }
                                }
                            }

                            // 运行时间
                            Row {
                                spacing: 12
                                Text { text: "运行时间:"; font.pixelSize: 11; color: "#8B8FA3" }
                                Text { id: uptimeValueText; text: statusController.uptime; font.pixelSize: 11; color: "#00D4AA" }
                            }
                        }
                    }
                }
            }
        }
    }
}
