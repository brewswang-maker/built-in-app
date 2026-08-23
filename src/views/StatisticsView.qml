// ========================================================================
// StatisticsView.qml — 数据统计分析 (v7.7 1:1 对齐 Web StatisticsView 截图)
//
// 布局 (自上而下, 对齐 Web statistics-page):
//   ① 页头: 标题 + 导出CSV + 时间范围 (近7天/近30天/近90天)
//   ② 行1: 安全评分卡(圆环+趋势) 1/4 | 安全维度分布(进度条) 3/4
//   ③ 行2: 告警趋势(4级折线) 2/3 | 告警分布(环形) 1/3
//   ④ 行3: 设备在线率趋势 1/2 | 平均资源使用 1/2
//   ⑤ 行4: AI Agent 活跃度(+5指标卡) 1/2 | 各项告警累计(柱状) 1/2
//
// 数据源 (实事求是原则):
//   - 安全评分: GET /api/v1/stats/security-score (box-sdk 真实端点)
//   - 告警趋势/分布/项目累计: alarmController.alarms 按时间窗口聚合
//   - 设备在线率趋势/平均资源使用: box-sdk 无历史趋势端点 → 如实空态
//   - AI Agent 活跃度: 先探测 /api/v1/stats/agent-activity, 无则空态
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: statsPage

    // ── 状态 ──
    property string timeRange: "7d"          // 7d / 30d / 90d
    property bool loading: true

    // 安全评分 (来自 /api/v1/stats/security-score)
    property var securityScore: null          // { overall, trend, dimensions }
    property bool scoreLoaded: false

    // 告警聚合
    property var trendBuckets: []             // [{label, critical, high, medium, low}]
    property var levelCounts: ({ critical: 0, high: 0, medium: 0, low: 0 })
    property int levelTotal: 0
    property var projectStats: []             // [{name, total, handled}]

    // Agent 活跃度
    property bool agentProbed: false
    property var agentActivity: null

    // ── 颜色 (对齐 Web ECharts 系列色) ──
    readonly property color cCritical: "#f5222d"
    readonly property color cHigh:     "#fa8c16"
    readonly property color cMedium:   "#1890ff"
    readonly property color cLow:      "#52c41a"

    Component.onCompleted: {
        loadSecurityScore()
        probeAgentActivity()
        alarmController.refreshAlarms(500)
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() { rebuildAlarmAggregates() }
    }

    // ── 时间解析: time / created_at / timestamp (ms|s) / "HH:MM:SS" (视为今天) ──
    function parseAlarmTime(a) {
        var raw = a.timestamp !== undefined && a.timestamp !== null ? a.timestamp
                : (a.created_at !== undefined && a.created_at !== null ? a.created_at : a.time)
        if (raw === undefined || raw === null) return NaN
        if (typeof raw === "number") return raw > 1e12 ? raw : raw * 1000
        var s = String(raw)
        if (/^\d+$/.test(s)) { var n = parseInt(s); return n > 1e12 ? n : n * 1000 }
        if (/^\d{1,2}:\d{2}/.test(s)) {
            var today = new Date(); today.setHours(0, 0, 0, 0)
            var parts = s.split(":")
            return today.getTime() + (parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60) * 1000
        }
        return new Date(s.replace(" ", "T")).getTime()
    }

    function levelBucket(lv) {
        if (lv === "critical") return "critical"
        if (lv === "high" || lv === "warning") return "high"
        if (lv === "medium") return "medium"
        return "low"   // low / info / 未知 → 低
    }

    function rangeDays() { return timeRange === "7d" ? 7 : timeRange === "30d" ? 30 : 90 }

    // ── 重建告警聚合 (趋势分桶 + 级别分布 + 项目累计) ──
    function rebuildAlarmAggregates() {
        var alarms = alarmController.alarms || []
        var days = rangeDays()
        var start = new Date(); start.setHours(0, 0, 0, 0)
        var startMs = start.getTime() - (days - 1) * 86400000

        // 日期桶
        var buckets = []
        for (var d = 0; d < days; d++) {
            var dt = new Date(startMs + d * 86400000)
            buckets.push({ label: Qt.formatDateTime(dt, "MM-dd"), critical: 0, high: 0, medium: 0, low: 0 })
        }
        var lc = { critical: 0, high: 0, medium: 0, low: 0 }
        var proj = {}
        var order = []

        for (var i = 0; i < alarms.length; i++) {
            var a = alarms[i]
            var b = levelBucket(a.level || a.severity || "")
            var t = parseAlarmTime(a)
            if (!isNaN(t) && t >= startMs) {
                var idx = Math.floor((t - startMs) / 86400000)
                if (idx >= 0 && idx < days) buckets[idx][b]++
                lc[b]++
            }
            // 项目累计: 使用全量告警 (对齐 Web distribution 累计语义)
            var pname = a.project || a.project_name || a.group || a.group_name || "默认项目"
            if (!proj[pname]) { proj[pname] = { name: pname, total: 0, handled: 0 }; order.push(pname) }
            proj[pname].total++
            var st = a.status || "unhandled"
            if (st !== "unhandled" && st !== "pending" && st !== "new") proj[pname].handled++
        }

        trendBuckets = buckets
        levelCounts = lc
        levelTotal = lc.critical + lc.high + lc.medium + lc.low
        var ps = []
        for (var p = 0; p < order.length; p++) ps.push(proj[order[p]])
        projectStats = ps
        loading = false

        trendCanvas.requestPaint()
        donutCanvas.requestPaint()
        projectCanvas.requestPaint()
    }

    // ── 安全评分 ──
    function loadSecurityScore() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://localhost:8080/api/v1/stats/security-score", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        securityScore = resp.data || resp
                    } catch (e) { securityScore = null }
                } else { securityScore = null }
                scoreLoaded = true
                scoreCanvas.requestPaint()
            }
        }
        xhr.send()
    }

    // ── Agent 端点探测 (box-sdk 通常无此端点 → 如实空态) ──
    function probeAgentActivity() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://localhost:8080/api/v1/stats/agent-activity", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        agentActivity = resp.data || resp
                    } catch (e) { agentActivity = null }
                } else { agentActivity = null }
                agentProbed = true
                agentCanvas.requestPaint()
            }
        }
        xhr.send()
    }

    function fmtNum(v) {
        if (v === undefined || v === null) return "-"
        return Number(v).toLocaleString(Qt.locale("C"))
    }

    // ═══════════════ 页面布局 ═══════════════
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    Flickable {
        anchors.fill: parent
        contentWidth: width; contentHeight: pageCol.height + 24
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: pageCol
            width: statsPage.width - 24
            x: 12; y: 12
            spacing: 12

            // ── 页头: 标题 + 导出 + 时间范围 ──
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "数据统计分析"; font.pixelSize: 20; font.bold: true; color: "#303133" }
                Item { Layout.fillWidth: true }
                Button {
                    height: 30
                    contentItem: Row { spacing: 4; leftPadding: 10; rightPadding: 10
                        Text { text: "⬇"; font.pixelSize: 11; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "导出CSV"; font.pixelSize: 12; color: "#606266"; anchors.verticalCenter: parent.verticalCenter } }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    onClicked: configController.exportConfig("statistics", "csv")
                }
                Row {
                    spacing: 0
                    Repeater {
                        model: [ { l: "近7天", v: "7d" }, { l: "近30天", v: "30d" }, { l: "近90天", v: "90d" } ]
                        delegate: Rectangle {
                            width: 72; height: 30
                            color: statsPage.timeRange === modelData.v ? "#409EFF" : "#FFFFFF"
                            border.color: statsPage.timeRange === modelData.v ? "#409EFF" : "#DCDFE6"
                            radius: index === 0 ? 4 : (index === 2 ? 4 : 0)
                            Text { anchors.centerIn: parent; text: modelData.l; font.pixelSize: 12
                                color: statsPage.timeRange === modelData.v ? "#FFFFFF" : "#606266" }
                            MouseArea { anchors.fill: parent; onClicked: {
                                if (statsPage.timeRange !== modelData.v) {
                                    statsPage.timeRange = modelData.v
                                    statsPage.rebuildAlarmAggregates()
                                } } }
                        }
                    }
                }
            }

            // ══ 行1: 安全评分 + 安全维度分布 ══
            RowLayout {
                Layout.fillWidth: true; spacing: 12

                // 评分卡
                Rectangle {
                    Layout.preferredWidth: (statsPage.width - 24 - 12) * 0.25
                    Layout.preferredHeight: 190; color: "#FFFFFF"; radius: 4
                    border.color: "#EBEEF5"
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Canvas {
                            id: scoreCanvas
                            width: 100; height: 100; anchors.horizontalCenter: parent.horizontalCenter
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cx = 50, cy = 50, r = 42
                                var s = statsPage.securityScore
                                var pct = (s && s.overall !== undefined) ? Math.max(0, Math.min(100, s.overall)) : 0
                                // 外环: 得分绿色 / 余量 #f0f0f0 (对齐 Web score-circle conic)
                                ctx.lineWidth = 11
                                ctx.strokeStyle = "#f0f0f0"
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                if (pct > 0) {
                                    ctx.strokeStyle = "#52c41a"; ctx.lineCap = "round"
                                    ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + pct / 100 * 2 * Math.PI); ctx.stroke()
                                }
                                ctx.fillStyle = "#1f2937"; ctx.font = "bold 28px sans-serif"; ctx.textAlign = "center"
                                ctx.fillText((s && s.overall !== undefined) ? String(s.overall) : "--", cx, cy + 10)
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.pixelSize: 14; font.bold: true
                            color: (statsPage.securityScore && (statsPage.securityScore.trend || 0) < 0) ? "#f5222d" : "#52c41a"
                            text: {
                                var tr = (statsPage.securityScore && statsPage.securityScore.trend !== undefined)
                                         ? statsPage.securityScore.trend : 0
                                return (tr >= 0 ? "↑ " : "↓ ") + Math.abs(tr) + "%"
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "全局安全态势评分"; font.pixelSize: 14; color: "#6b7280" }
                    }
                }

                // 安全维度分布
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 190
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "安全维度分布"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                            Repeater {
                                model: (statsPage.securityScore && statsPage.securityScore.dimensions)
                                       ? statsPage.securityScore.dimensions : []
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 12
                                    Text { text: modelData.label || ""; width: 70; font.pixelSize: 13; color: "#6b7280"
                                        horizontalAlignment: Text.AlignRight }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 10; radius: 5; color: "#f0f0f0"
                                        Rectangle { width: parent.width * Math.max(0, Math.min(100, modelData.value || 0)) / 100
                                            height: 10; radius: 5; color: modelData.color || "#52c41a" }
                                    }
                                    Text { text: String(modelData.value !== undefined ? modelData.value : 0)
                                        width: 40; font.pixelSize: 13; font.bold: true; color: "#303133" }
                                }
                            }
                            // 加载/错误态
                            Text {
                                visible: !statsPage.scoreLoaded
                                text: "加载中..."; font.pixelSize: 13; color: "#909399"
                            }
                            Text {
                                visible: statsPage.scoreLoaded && (!statsPage.securityScore || !statsPage.securityScore.dimensions)
                                text: "暂无安全评分数据"; font.pixelSize: 13; color: "#909399"
                            }
                        }
                    }
                }
            }

            // ══ 行2: 告警趋势 + 告警分布 ══
            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Rectangle {
                    Layout.preferredWidth: (statsPage.width - 24 - 12) * 2 / 3
                    Layout.preferredHeight: 360; color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Text { text: "告警趋势"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                            Item { Layout.fillWidth: true }
                            Row { spacing: 12
                                Repeater {
                                    model: [ { l: "严重", c: statsPage.cCritical }, { l: "高危", c: statsPage.cHigh },
                                             { l: "中危", c: statsPage.cMedium }, { l: "低危", c: statsPage.cLow } ]
                                    delegate: Row { spacing: 4
                                        Rectangle { width: 9; height: 9; radius: 4.5; color: modelData.c; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.l; font.pixelSize: 12; color: "#606266" } }
                                }
                            }
                        }
                        Canvas {
                            id: trendCanvas
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onPaint: statsPage.paintTrend(this)
                            Component.onCompleted: requestPaint()
                        }
                        Text { visible: statsPage.levelTotal === 0 && !statsPage.loading
                            text: "当前时间范围内暂无告警数据"; font.pixelSize: 13; color: "#909399" }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 360
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "告警分布"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        Canvas {
                            id: donutCanvas
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onPaint: statsPage.paintDonut(this)
                            Component.onCompleted: requestPaint()
                        }
                        Text { visible: statsPage.levelTotal === 0 && !statsPage.loading
                            text: "暂无告警分布数据"; font.pixelSize: 13; color: "#909399" }
                    }
                }
            }

            // ══ 行3: 设备在线率趋势 + 平均资源使用 ══
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 300
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "设备在线率趋势"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        EmptyChartHint {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            message: "暂无历史趋势数据"
                            subMessage: "设备在线率历史记录服务未接入"
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 300
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "平均资源使用"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        EmptyChartHint {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            message: "暂无历史趋势数据"
                            subMessage: "CPU/内存历史采样服务未接入"
                        }
                    }
                }
            }

            // ══ 行4: AI Agent 活跃度 + 各项告警累计 ══
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 340
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "🟣 AI Agent 活跃度"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        // 图表区 (端点可用时绘制趋势, 否则空态)
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Canvas {
                                id: agentCanvas
                                anchors.fill: parent
                                visible: statsPage.agentProbed && statsPage.agentActivity
                                         && statsPage.agentActivity.trendData
                                onPaint: statsPage.paintAgent(this)
                            }
                            EmptyChartHint {
                                anchors.fill: parent
                                visible: !agentCanvas.visible
                                message: statsPage.agentProbed ? "暂无 Agent 活跃度数据" : "加载中..."
                                subMessage: statsPage.agentProbed ? "Agent 活跃度服务未接入" : ""
                            }
                        }
                        // 5 指标卡
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Repeater {
                                model: [
                                    { l: "感知Agent", v: statsPage.agentActivity ? fmtNum(statsPage.agentActivity.perceptionCalls) : "-" },
                                    { l: "研判Agent", v: statsPage.agentActivity ? fmtNum(statsPage.agentActivity.analysisCalls) : "-" },
                                    { l: "决策Agent", v: statsPage.agentActivity ? fmtNum(statsPage.agentActivity.decisionCalls) : "-" },
                                    { l: "专家诊断",  v: statsPage.agentActivity && statsPage.agentActivity.expertInvokes !== undefined
                                                       ? String(statsPage.agentActivity.expertInvokes) : "-" },
                                    { l: "平均置信度", v: statsPage.agentActivity && statsPage.agentActivity.avgConfidence
                                                        ? (statsPage.agentActivity.avgConfidence * 100).toFixed(1) + "%" : "-" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true; height: 56; radius: 8; color: "#f5f3ff"
                                    Column { anchors.centerIn: parent; spacing: 2
                                        Text { text: modelData.l; font.pixelSize: 12; color: "#7c3aed" }
                                        Text { text: modelData.v; font.pixelSize: 16; font.bold: true; color: "#4c1d95" } }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 340
                    color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Text { text: "各项告警累计"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                            Item { Layout.fillWidth: true }
                            Row { spacing: 12
                                Row { spacing: 4
                                    Rectangle { width: 9; height: 9; radius: 2; color: statsPage.cCritical; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "告警总数"; font.pixelSize: 12; color: "#606266" } }
                                Row { spacing: 4
                                    Rectangle { width: 9; height: 9; radius: 2; color: statsPage.cLow; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "已处理"; font.pixelSize: 12; color: "#606266" } }
                            }
                        }
                        Canvas {
                            id: projectCanvas
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onPaint: statsPage.paintProjects(this)
                            Component.onCompleted: requestPaint()
                        }
                        Text { visible: statsPage.projectStats.length === 0 && !statsPage.loading
                            text: "暂无告警数据"; font.pixelSize: 13; color: "#909399" }
                    }
                }
            }
        }
    }

    // ═══ 空态组件 (图表区域无数据时如实呈现) ═══
    component EmptyChartHint: Item {
        property string message: "暂无数据"
        property string subMessage: ""
        Column {
            anchors.centerIn: parent; spacing: 6
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📊"; font.pixelSize: 28; color: "#C0C4CC" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: message; font.pixelSize: 13; color: "#909399" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: subMessage; visible: subMessage !== ""; font.pixelSize: 12; color: "#C0C4CC" }
        }
    }

    // ═══ 告警趋势折线 (4 级系列, 对齐 Web ECharts) ═══
    function paintTrend(canvas) {
        var ctx = canvas.getContext("2d")
        var w = canvas.width, h = canvas.height
        ctx.clearRect(0, 0, w, h)
        var buckets = trendBuckets
        if (!buckets || buckets.length === 0) return

        var keys = ["critical", "high", "medium", "low"]
        var colors = [cCritical, cHigh, cMedium, cLow]
        var maxVal = 0
        for (var i = 0; i < buckets.length; i++)
            for (var k = 0; k < 4; k++) maxVal = Math.max(maxVal, buckets[i][keys[k]])
        if (maxVal === 0) maxVal = 10

        var padL = 44, padR = 12, padT = 10, padB = 26
        var cw = w - padL - padR, ch = h - padT - padB
        if (cw <= 0 || ch <= 0) return

        // 网格 + Y 轴 (对齐 ECharts 4 等分)
        ctx.strokeStyle = "#EBEEF5"; ctx.lineWidth = 1
        ctx.fillStyle = "#909399"; ctx.font = "11px sans-serif"; ctx.textAlign = "right"
        for (var g = 0; g <= 4; g++) {
            var gy = padT + (g / 4) * ch
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke()
            ctx.fillText(String(Math.round(maxVal * (1 - g / 4))), padL - 8, gy + 4)
        }
        // X 轴标签 (最多 7 个, 对齐 Web 日期 MM-dd)
        ctx.textAlign = "center"
        var step = Math.max(1, Math.ceil(buckets.length / 7))
        for (var x = 0; x < buckets.length; x += step) {
            var px = padL + (buckets.length === 1 ? cw / 2 : (x / (buckets.length - 1)) * cw)
            ctx.fillText(buckets[x].label, px, h - 8)
        }
        // 系列折线 + 淡填充
        for (var s = 0; s < 4; s++) {
            var key = keys[s]
            ctx.strokeStyle = colors[s]; ctx.lineWidth = 2; ctx.beginPath()
            for (var p = 0; p < buckets.length; p++) {
                var xx = padL + (buckets.length === 1 ? cw / 2 : (p / (buckets.length - 1)) * cw)
                var yy = padT + (1 - buckets[p][key] / maxVal) * ch
                if (p === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy)
            }
            ctx.stroke()
            // 面积填充 (opacity 0.1, 对齐 Web areaStyle)
            if (buckets.length > 1) {
                ctx.save(); ctx.globalAlpha = 0.08; ctx.fillStyle = colors[s]
                ctx.lineTo(padL + cw, padT + ch); ctx.lineTo(padL, padT + ch); ctx.closePath(); ctx.fill()
                ctx.restore()
            }
        }
    }

    // ═══ 告警分布环形 (center 40%, 右侧垂直图例, 对齐 Web pie) ═══
    function paintDonut(canvas) {
        var ctx = canvas.getContext("2d")
        var w = canvas.width, h = canvas.height
        ctx.clearRect(0, 0, w, h)
        if (levelTotal === 0) return

        var cx = w * 0.40, cy = h * 0.5
        var rOuter = Math.min(cx - 10, cy - 10, 110)
        if (rOuter <= 0) return
        var rInner = rOuter * 0.6   // radius ['45%','75%'] 近似

        var segs = [
            { name: "严重", v: levelCounts.critical, c: cCritical },
            { name: "高危", v: levelCounts.high,     c: cHigh },
            { name: "中危", v: levelCounts.medium,   c: cMedium },
            { name: "低危", v: levelCounts.low,      c: cLow }
        ]
        var start = -Math.PI / 2
        for (var i = 0; i < segs.length; i++) {
            if (segs[i].v <= 0) continue
            var angle = segs[i].v / levelTotal * 2 * Math.PI
            ctx.beginPath()
            ctx.arc(cx, cy, rOuter, start, start + angle)
            ctx.arc(cx, cy, rInner, start + angle, start, true)
            ctx.closePath()
            ctx.fillStyle = segs[i].c; ctx.fill()
            start += angle
        }
        // 右侧垂直图例 (对齐 Web legend vertical right)
        var lx = cx + rOuter + 24
        var ly = cy - segs.length * 13
        for (var j = 0; j < segs.length; j++) {
            ctx.fillStyle = segs[j].c
            ctx.fillRect(lx, ly + j * 26, 12, 12)
            ctx.fillStyle = "#606266"; ctx.font = "12px sans-serif"; ctx.textAlign = "left"
            ctx.fillText(segs[j].name + "  " + segs[j].v, lx + 18, ly + j * 26 + 11)
        }
    }

    // ═══ Agent 活跃度折线 (感知/研判/决策 3 系列) ═══
    function paintAgent(canvas) {
        var ctx = canvas.getContext("2d")
        var w = canvas.width, h = canvas.height
        ctx.clearRect(0, 0, w, h)
        if (!agentActivity || !agentActivity.trendData || agentActivity.trendData.length === 0) return
        var data = agentActivity.trendData

        var series = [
            { key: "perception", c: "#1890ff", name: "感知" },
            { key: "analysis",   c: "#722ed1", name: "研判" },
            { key: "decision",   c: "#fa8c16", name: "决策" }
        ]
        var maxVal = 0
        for (var i = 0; i < data.length; i++) {
            if (data[i].perception !== undefined) maxVal = Math.max(maxVal, data[i].perception)
            if (data[i].analysis !== undefined) maxVal = Math.max(maxVal, data[i].analysis)
            if (data[i].decision !== undefined) maxVal = Math.max(maxVal, data[i].decision)
            if (data[i].calls !== undefined) maxVal = Math.max(maxVal, data[i].calls)
        }
        if (maxVal === 0) maxVal = 10

        var padL = 40, padR = 10, padT = 8, padB = 24
        var cw = w - padL - padR, ch = h - padT - padB
        ctx.strokeStyle = "#EBEEF5"; ctx.lineWidth = 1
        ctx.fillStyle = "#909399"; ctx.font = "11px sans-serif"; ctx.textAlign = "right"
        for (var g = 0; g <= 4; g++) {
            var gy = padT + (g / 4) * ch
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke()
            ctx.fillText(String(Math.round(maxVal * (1 - g / 4))), padL - 6, gy + 4)
        }
        ctx.textAlign = "center"
        var step = Math.max(1, Math.ceil(data.length / 7))
        for (var x = 0; x < data.length; x += step) {
            var lbl = data[x].date ? String(data[x].date).slice(5) : ""
            ctx.fillText(lbl, padL + (x / Math.max(data.length - 1, 1)) * cw, h - 6)
        }
        for (var s = 0; s < series.length; s++) {
            ctx.strokeStyle = series[s].c; ctx.lineWidth = 2; ctx.beginPath()
            for (var p = 0; p < data.length; p++) {
                var v = data[p][series[s].key]
                if (v === undefined) v = data[p].calls || 0
                var px = padL + (p / Math.max(data.length - 1, 1)) * cw
                var py = padT + (1 - v / maxVal) * ch
                if (p === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
            }
            ctx.stroke()
        }
    }

    // ═══ 各项告警累计 (分组柱状: 总数红 / 已处理绿) ═══
    function paintProjects(canvas) {
        var ctx = canvas.getContext("2d")
        var w = canvas.width, h = canvas.height
        ctx.clearRect(0, 0, w, h)
        var ps = projectStats
        if (!ps || ps.length === 0) return

        var maxVal = 0
        for (var i = 0; i < ps.length; i++) maxVal = Math.max(maxVal, ps[i].total)
        if (maxVal === 0) maxVal = 10

        var padL = 44, padR = 10, padT = 8, padB = 30
        var cw = w - padL - padR, ch = h - padT - padB
        ctx.strokeStyle = "#EBEEF5"; ctx.lineWidth = 1
        ctx.fillStyle = "#909399"; ctx.font = "11px sans-serif"; ctx.textAlign = "right"
        for (var g = 0; g <= 4; g++) {
            var gy = padT + (g / 4) * ch
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke()
            ctx.fillText(String(Math.round(maxVal * (1 - g / 4))), padL - 8, gy + 4)
        }
        var groupW = cw / ps.length
        var barW = Math.min(36, groupW * 0.3)
        for (var p = 0; p < ps.length; p++) {
            var cx0 = padL + groupW * p + groupW / 2
            var hTotal = ps[p].total / maxVal * ch
            var hHandled = ps[p].handled / maxVal * ch
            ctx.fillStyle = cCritical
            ctx.fillRect(cx0 - barW - 2, padT + ch - hTotal, barW, hTotal)
            ctx.fillStyle = cLow
            ctx.fillRect(cx0 + 2, padT + ch - hHandled, barW, hHandled)
            // 分类标签
            ctx.fillStyle = "#606266"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
            ctx.fillText(ps[p].name, cx0, h - 8)
        }
    }
}
