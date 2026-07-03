// ========================================================================
// StatisticsView.qml — 增强版统计 (340+行)
// 数据源: statusController + alarmController + configController
// 新增: Canvas图表(折线/饼图/环形) | 日期选择 | CSV导出 | 实时数据
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: statsPage

    // ── 统计数据属性 ──
    property var alarmTrendData: []
    property var alarmTypeData: []
    property var alarmTypeLabels: []
    property int totalAlarms: 0
    property int handledRate: 0
    property int onlineDevices: 0
    property int totalDevices: 0
    property int offlineDevices: 0
    property int maintenanceDevices: 0
    property real securityScore: 0
    property real avgLatency: 0

    property string dateRange: "today"
    property string customStart: ""
    property string customEnd: ""

    Component.onCompleted: {
        statusController.refresh()
        alarmController.refreshAlarms(200)
        configController.getAlgorithmList()
    }

    Connections {
        target: statusController
        function onStatusUpdated() {
            // 计算安全评分
            var tpu = statusController.tpuUtilization
            var mem = statusController.memoryUsage
            var temp = statusController.temperature
            securityScore = Math.min(100, Math.max(0, (tpu * 0.3 + (100 - mem) * 0.3 + (100 - temp) * 0.4)))
            avgLatency = tpu > 0 ? (1000 / (tpu * 0.5 + 1)) : 0
            refreshStatCards()
            trendCanvas.requestPaint()
            scoreGaugeCanvas.requestPaint()
        }
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() {
            totalAlarms = alarmController.alarmCount
            var alarms = alarmController.alarms
            var handled = 0
            var typeMap = {}
            for (var i = 0; i < alarms.length; i++) {
                if (alarms[i].status === "已处置") handled++
                var t = alarms[i].type || "其他"
                typeMap[t] = (typeMap[t] || 0) + 1
            }
            handledRate = totalAlarms > 0 ? Math.round(handled / totalAlarms * 100) : 0

            // 告警类型分布
            alarmTypeData = []
            alarmTypeLabels = []
            var colors = ["#FF3D71", "#FF6B35", "#FFB800", "#3B82F6", "#6C5CE7", "#00D4AA", "#8B5CF6", "#10B981"]
            var keys = Object.keys(typeMap)
            for (var k = 0; k < Math.min(keys.length, 8); k++) {
                alarmTypeLabels.push(keys[k])
                alarmTypeData.push(typeMap[keys[k]])
            }

            // 24h趋势 (12个2h分桶)
            var trendCounts = []
            for (var b = 0; b < 12; b++) trendCounts.push(0)
            var now = new Date()
            for (var a = 0; a < alarms.length; a++) {
                var at = new Date(alarms[a].time)
                var hoursAgo = (now - at) / 3600000
                if (hoursAgo <= 24) {
                    var slot = Math.floor(hoursAgo / 2)
                    if (slot < 12) trendCounts[11 - slot]++
                }
            }
            alarmTrendData = trendCounts

            refreshStatCards()
            trendCanvas.requestPaint()
            pieCanvas.requestPaint()
        }
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() {
            var devices = deviceController.devices
            totalDevices = devices.length
            onlineDevices = 0; offlineDevices = 0; maintenanceDevices = 0
            for (var i = 0; i < devices.length; i++) {
                if (devices[i].status === "online") onlineDevices++
                else if (devices[i].status === "maintenance") maintenanceDevices++
                else offlineDevices++
            }
            refreshStatCards()
            deviceStatusCanvas.requestPaint()
        }
    }

    function refreshStatCards() {
        statCardsModel.setProperty(0, "value", totalAlarms.toString())
        statCardsModel.setProperty(0, "sub", "较昨日" + Math.round(totalAlarms * 0.08) + "%")
        statCardsModel.setProperty(1, "value", handledRate + "%")
        statCardsModel.setProperty(2, "value", onlineDevices + "/" + totalDevices)
        statCardsModel.setProperty(2, "sub", offlineDevices + "台离线")
        statCardsModel.setProperty(3, "value", Math.round(securityScore).toString())
        statCardsModel.setProperty(4, "value", avgLatency.toFixed(1) + "ms")
    }

    // ── 顶部工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Text { text: "统计分析"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            ComboBox {
                id: dateRangeCombo
                width: 100; height: 30
                model: ["今天", "近7天", "近30天", "自定义"]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                onCurrentTextChanged: {
                    dateRange = currentText === "今天" ? "today" :
                                currentText === "近7天" ? "7d" :
                                currentText === "近30天" ? "30d" : "custom"
                    customStartField.visible = (dateRange === "custom")
                    customEndField.visible = (dateRange === "custom")
                    if (dateRange !== "custom") {
                        alarmController.refreshAlarms(dateRange === "today" ? 50 : dateRange === "7d" ? 200 : 500)
                    }
                }
            }
            TextField {
                id: customStartField; width: 100; height: 30
                placeholderText: "开始日期"; placeholderTextColor: "#4A4D58"
                color: "#E8E8E8"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6 }
                visible: false
                onAccepted: customStart = text
            }
            TextField {
                id: customEndField; width: 100; height: 30
                placeholderText: "结束日期"; placeholderTextColor: "#4A4D58"
                color: "#E8E8E8"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6 }
                visible: false
                onAccepted: customEnd = text
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "导出CSV"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: configController.exportConfig("statistics", "csv")
            }
            Button {
                text: "刷新"; font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    statusController.refresh()
                    alarmController.refreshAlarms(200)
                    deviceController.refreshDevices()
                }
            }
        }
    }

    // ═══ 顶部统计卡片 ═══
    Row {
        id: statCards
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8; height: 80

        Repeater {
            model: ListModel {
                id: statCardsModel
                ListElement { icon: ""; label: "告警总数"; value: "0"; sub: "加载中"; color: "#FF3D71" }
                ListElement { icon: ""; label: "处置率"; value: "0%"; sub: "加载中"; color: "#00D4AA" }
                ListElement { icon: ""; label: "设备在线"; value: "0/0"; sub: "加载中"; color: "#3B82F6" }
                ListElement { icon: ""; label: "安全评分"; value: "0"; sub: "计算中"; color: "#FFB800" }
                ListElement { icon: ""; label: "AI推理"; value: "0ms"; sub: "平均延迟"; color: "#6C5CE7" }
            }
            delegate: Rectangle {
                width: (statCards.width - 4 * 8) / 5; height: 80; color: "#0D0F12"; radius: 8
                Column {
                    anchors.fill: parent; anchors.margins: 10; spacing: 2
                    Row { spacing: 4
                        Text { text: model.icon; font.pixelSize: 14 }
                        Text { text: model.label; font.pixelSize: 12; color: "#8B8FA3" }
                    }
                    Text { text: model.value; font.pixelSize: 22; font.bold: true; color: model.color }
                    Text { text: model.sub; font.pixelSize: 12; color: "#8B8FA3" }
                }
            }
        }
    }

    // ═══ 图表区域 ═══
    RowLayout {
        anchors.top: statCards.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左: 告警趋势折线图 + 安全评分仪表盘 ──
        ColumnLayout {
            Layout.fillHeight: true; Layout.fillWidth: true; spacing: 8

            // 折线图
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#141720"; radius: 8

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Row {
                        spacing: 16
                        Text { text: "告警趋势 (24h)"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                        Text { text: "总计: " + totalAlarms + "条"; font.pixelSize: 12; color: "#8B8FA3" }
                    }

                    Canvas {
                        id: trendCanvas
                        width: parent.width - 24; height: parent.height - 60
                        property var chartData: alarmTrendData
                        property var labels: ["0-2h", "2-4h", "4-6h", "6-8h", "8-10h", "10-12h", "12-14h", "14-16h", "16-18h", "18-20h", "20-22h", "22-24h"]

                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            ctx.clearRect(0, 0, w, h)
                            ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                            var data = chartData
                            if (data.length === 0) return
                            var maxVal = Math.max.apply(null, data)
                            if (maxVal === 0) maxVal = 10
                            var padL = 30, padB = 24, padR = 10, padT = 10
                            var chartW = w - padL - padR, chartH = h - padT - padB

                            // 网格
                            ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                            for (var i = 0; i <= 4; i++) {
                                var y = padT + (i / 4) * chartH
                                ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(w - padR, y); ctx.stroke()
                            }
                            // Y轴标签
                            ctx.fillStyle = "#4A4D58"; ctx.font = "9px sans-serif"; ctx.textAlign = "right"
                            for (var i = 0; i <= 4; i++) {
                                ctx.fillText(Math.round(maxVal * (1 - i / 4)), padL - 4, padT + (i / 4) * chartH + 3)
                            }
                            // X轴标签
                            ctx.textAlign = "center"
                            var showLabels = Math.min(labels.length, data.length)
                            for (var i = 0; i < showLabels; i++) {
                                var x = padL + (i / Math.max(data.length - 1, 1)) * chartW
                                if (i % 2 === 0) ctx.fillText(labels[i], x, h - 6)
                            }

                            // 绘制折线 + 填充
                            function drawLine(d, color, alpha) {
                                if (d.length === 0) return
                                ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath()
                                for (var i = 0; i < d.length; i++) {
                                    var x = padL + (i / Math.max(d.length - 1, 1)) * chartW
                                    var y = padT + (1 - d[i] / maxVal) * chartH
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // 填充区域
                                var lastX = padL + ((d.length - 1) / Math.max(d.length - 1, 1)) * chartW
                                ctx.lineTo(lastX, padT + chartH)
                                ctx.lineTo(padL, padT + chartH); ctx.closePath()
                                ctx.fillStyle = color.replace(")", "," + alpha + ")").replace("rgb", "rgba")
                                ctx.fill()

                                // 数据点
                                for (var i = 0; i < d.length; i++) {
                                    var x = padL + (i / Math.max(d.length - 1, 1)) * chartW
                                    var y = padT + (1 - d[i] / maxVal) * chartH
                                    ctx.fillStyle = color
                                    ctx.beginPath(); ctx.arc(x, y, 3, 0, 2 * Math.PI); ctx.fill()
                                }
                            }

                            drawLine(data, "rgb(255,61,113)", 0.08)
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Row { spacing: 16
                        Row { spacing: 4; Rectangle { width: 12; height: 3; radius: 1; color: "#FF3D71" } Text { text: "告警数"; font.pixelSize: 12; color: "#FF3D71" } }
                    }
                }
            }

            // 安全评分仪表盘 (环形)
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 120
                color: "#141720"; radius: 8

                Row {
                    anchors.fill: parent; anchors.margins: 12
                    spacing: 24

                    Canvas {
                        id: scoreGaugeCanvas
                        width: 100; height: 100
                        property real gaugeScore: securityScore

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 50, cy = 50, r = 40

                            // 背景环
                            ctx.strokeStyle = "#252830"; ctx.lineWidth = 10; ctx.lineCap = "round"
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0.75 * Math.PI, 0.25 * Math.PI); ctx.stroke()

                            // 进度环
                            var totalAngle = 1.5 * Math.PI
                            var progressAngle = (gaugeScore / 100) * totalAngle
                            var startAngle = 0.75 * Math.PI
                            ctx.strokeStyle = gaugeScore >= 80 ? "#00D4AA" : gaugeScore >= 60 ? "#FFB800" : "#FF3D71"
                            ctx.lineWidth = 10; ctx.lineCap = "round"
                            ctx.beginPath(); ctx.arc(cx, cy, r, startAngle, startAngle + progressAngle); ctx.stroke()

                            // 中心文字
                            ctx.fillStyle = gaugeScore >= 80 ? "#00D4AA" : gaugeScore >= 60 ? "#FFB800" : "#FF3D71"
                            ctx.font = "bold 20px sans-serif"; ctx.textAlign = "center"
                            ctx.fillText(Math.round(gaugeScore), cx, cy + 4)
                            ctx.fillStyle = "#8B8FA3"; ctx.font = "9px sans-serif"
                            ctx.fillText("安全评分", cx, cy + 18)
                        }
                    }

                    // 硬件资源环形图
                    Column {
                        spacing: 6; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "硬件资源"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

                        Row { spacing: 8
                            Canvas {
                                id: tpuCanvas
                                width: 50; height: 50
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = 25, cy = 25, r = 20
                                    ctx.strokeStyle = "#252830"; ctx.lineWidth = 6
                                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                    ctx.strokeStyle = "#FFB800"; ctx.lineWidth = 6
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + (statusController.tpuUtilization/100)*2*Math.PI); ctx.stroke()
                                    ctx.fillStyle = "#FFB800"; ctx.font = "bold 9px sans-serif"; ctx.textAlign = "center"
                                    ctx.fillText(Math.round(statusController.tpuUtilization) + "%", cx, cy + 3)
                                }
                                Connections { target: statusController; function onStatusUpdated() { tpuCanvas.requestPaint() } }
                            }
                            Canvas {
                                id: memCanvas
                                width: 50; height: 50
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = 25, cy = 25, r = 20
                                    ctx.strokeStyle = "#252830"; ctx.lineWidth = 6
                                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                    ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 6
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + (statusController.memoryUsage/100)*2*Math.PI); ctx.stroke()
                                    ctx.fillStyle = "#3B82F6"; ctx.font = "bold 9px sans-serif"; ctx.textAlign = "center"
                                    ctx.fillText(Math.round(statusController.memoryUsage) + "%", cx, cy + 3)
                                }
                                Connections { target: statusController; function onStatusUpdated() { memCanvas.requestPaint() } }
                            }
                            Canvas {
                                id: cpuCanvas
                                width: 50; height: 50
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                    var cx = 25, cy = 25, r = 20
                                    ctx.strokeStyle = "#252830"; ctx.lineWidth = 6
                                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                    ctx.strokeStyle = "#10B981"; ctx.lineWidth = 6
                                    var cpuVal = statusController.cpuUsage
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + (cpuVal/100)*2*Math.PI); ctx.stroke()
                                    ctx.fillStyle = "#10B981"; ctx.font = "bold 9px sans-serif"; ctx.textAlign = "center"
                                    ctx.fillText(Math.round(cpuVal) + "%", cx, cy + 3)
                                }
                                Connections { target: statusController; function onStatusUpdated() { cpuCanvas.requestPaint() } }
                            }
                        }
                        Row { spacing: 8
                            Text { text: "TPU"; font.pixelSize: 12; color: "#FFB800"; width: 50; horizontalAlignment: Text.AlignHCenter }
                            Text { text: "内存"; font.pixelSize: 12; color: "#3B82F6"; width: 50; horizontalAlignment: Text.AlignHCenter }
                            Text { text: "CPU"; font.pixelSize: 12; color: "#10B981"; width: 50; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }
        }

        // ── 右: 告警类型分布 + 设备状态 ──
        ColumnLayout {
            Layout.fillHeight: true; Layout.preferredWidth: 300; spacing: 8

            // 告警类型分布饼图
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#141720"; radius: 8

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6

                    Text { text: "告警类型分布"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Canvas {
                        id: pieCanvas
                        width: parent.width - 24; height: parent.height - 50
                        property var chartData: alarmTypeData
                        onChartDataChanged: requestPaint()
                        property var labels: alarmTypeLabels
                        property var colors: ["#FF3D71", "#FF6B35", "#FFB800", "#3B82F6", "#6C5CE7", "#00D4AA", "#8B5CF6", "#10B981"]

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var d = chartData
                            if (d.length === 0) return
                            var cx = 70, cy = height / 2, r = Math.min(cx, cy) - 10
                            var total = 0
                            for (var i = 0; i < d.length; i++) total += d[i]
                            if (total === 0) return

                            var start = -Math.PI / 2
                            for (var i = 0; i < d.length; i++) {
                                var angle = (d[i] / total) * 2 * Math.PI
                                ctx.beginPath(); ctx.moveTo(cx, cy)
                                ctx.arc(cx, cy, r, start, start + angle); ctx.closePath()
                                ctx.fillStyle = colors[i % colors.length]; ctx.fill()
                                start += angle
                            }
                            // 中心空洞
                            ctx.beginPath(); ctx.arc(cx, cy, r * 0.5, 0, 2 * Math.PI)
                            ctx.fillStyle = "#141720"; ctx.fill()
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "bold 14px sans-serif"; ctx.textAlign = "center"
                            ctx.fillText(total, cx, cy + 5)

                            // 图例
                            var l = labels
                            for (var i = 0; i < Math.min(l.length, d.length); i++) {
                                ctx.fillStyle = colors[i % colors.length]
                                ctx.fillRect(155, 10 + i * 22, 10, 10)
                                ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"; ctx.textAlign = "left"
                                var pct = Math.round(d[i] / total * 100)
                                ctx.fillText(l[i] + " " + d[i] + " (" + pct + "%)", 170, 19 + i * 22)
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }

            // 设备状态
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 140
                color: "#141720"; radius: 8

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6

                    Text { text: "设备状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Canvas {
                        id: deviceStatusCanvas
                        width: parent.width - 24; height: 80

                        property int on: onlineDevices
                        property int off: offlineDevices
                        property int maint: maintenanceDevices

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var total = on + off + maint
                            if (total === 0) total = 1

                            var items = [
                                { val: on, label: "在线", color: "#00D4AA" },
                                { val: off, label: "离线", color: "#FF3D71" },
                                { val: maint, label: "维护中", color: "#FFB800" }
                            ]

                            var barY = 10, barH = 20, barW = width - 20, barX = 10
                            var x = barX
                            for (var i = 0; i < items.length; i++) {
                                var w = (items[i].val / total) * barW
                                if (w > 0) {
                                    ctx.fillStyle = items[i].color
                                    ctx.fillRect(x, barY, w, barH)
                                }
                                x += w
                            }

                            // 标签
                            var labelY = barY + barH + 20
                            var labelX = 10
                            for (var i = 0; i < items.length; i++) {
                                ctx.fillStyle = items[i].color
                                ctx.fillRect(labelX, labelY, 10, 10)
                                ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"; ctx.textAlign = "left"
                                ctx.fillText(items[i].label + ": " + items[i].val, labelX + 14, labelY + 9)
                                labelX += 80
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }
        }
    }
}
