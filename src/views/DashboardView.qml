// ========================================================================
// DashboardView.qml — 首页总览 [R2 第二轮界面升级 / R2.2 Web 态势大屏 1:1 对齐]
// 总览页严格对齐 Web 端 SituationScreen.vue (/situation 真实首页) 布局:
//   左列(400px): 安全评分(半环仪表) | 今日统计(2×2) | 设备状态(环形饼图)
//   中列: 园区态势图(3D 场景, 支持拖拽旋转/滚轮缩放) + 实时告警表格
//   右列(400px): 告警类型分布(饼图) | 告警趋势(4 级折线) | 多盒子算力负载柱状图
//   [2026-08-19 导航重构] 总览只保留总览内容: 统计分析/3D定位/视频监控页签
//   已移除, 分别由顶部一级菜单(3D定位/视频)与首页二级菜单(数据分析)承接
//   + AI 助手悬浮输入框 (默认收起, 点击展开, 不遮挡统计内容)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "qrc:///StadiumSceneData.js" as SceneData
// [P1-#2 v7.0+] 组件位于 qml.qrc 根 qresource 命名空间, 无需 import "components" 前缀
// 视频轮询面板 (VideoPatrolPanel.qml) 通过 alias 注册, 与 Locate3DPanel 一致

Item {
    id: dashboard

    // ═══ 页面状态 ═══
    property string trendMode: "24h"      // 24h | 7d | 30d (Web 默认 24h)
    property int lastUpdatedSec: 0        // 距上次刷新秒数 (对齐 Web lastUpdated)
    // [P1-#2 v7.0+] 中列视图切换 (对齐 Web centerView)
    property string centerView: "3d"      // "3d" | "video"

    // [体育场3D] 场景数据 (scene_config.json 覆盖 → JS 兜底, mapDevices 合并真实状态, 与 SituationView 同源)
    readonly property var sceneMeta: situationController.sceneConfigLoaded
        && Object.keys(situationController.sceneMeta).length > 0
        ? situationController.sceneMeta : SceneData.SCENE_META
    readonly property var sceneBuildings: situationController.sceneConfigLoaded
        && situationController.sceneBuildings.length > 0
        ? situationController.sceneBuildings : SceneData.BUILDINGS
    readonly property var sceneDevices: SceneData.mergeDeviceStatus(
        situationController.sceneConfigLoaded && situationController.sceneDemoDevices.length > 0
            ? situationController.sceneDemoDevices : SceneData.DEMO_DEVICES,
        situationController.mapDevices)
    // [v7.2+] 中列全屏覆盖层 (对齐 Web fullscreen-video-grid): 点击"全屏"按钮后填满中列
    //   - 不再跳转 sidebar 页面, 避免跳出首页总览
    //   - 按 ESC 或再次点"全屏"可退出
    property bool centerFullscreen: false
    // 退出全屏快捷键 (对齐 Web onFullscreenEsc)
    Shortcut { sequence: "Esc"; autoRepeat: false; onActivated: dashboard.centerFullscreen = false }

    // ── 全屏模式下隐藏左/右列 + 下方告警表 (中列内部不再被外层 Layout 压缩) ──
    readonly property bool _colHide: centerFullscreen
    function toggleFullscreen() { dashboard.centerFullscreen = !dashboard.centerFullscreen }

    // [v7.6 对齐 Web scene-actions] 3D 工具条状态: 标签可见/自动巡视
    property bool sceneLabelsVisible: true
    property bool patrolActive: false

    // ── 安全评分 (对齐 Web securityScore.overall; 顶不到后端时走历史公式) ──
    function calcScore() {
        var ov = situationController.overview
        if (ov && ov.securityScore && ov.securityScore.overall !== undefined
            && ov.securityScore.overall !== null) {
            return Math.round(Number(ov.securityScore.overall))
        }
        var tpu = statusController.tpuUtilization, mem = statusController.memoryUsage, temp = statusController.temperature
        return Math.min(100, Math.max(0, Math.round(tpu * 0.3 + (100 - mem) * 0.3 + (100 - temp) * 0.4)))
    }
    // ── 评分等级 (对齐 Web scoreTagType/scoreLabel) ──
    function scoreLabel() { var s = calcScore(); return s >= 90 ? "优秀" : s >= 70 ? "良好" : "注意" }
    function scoreTagColor() { var s = calcScore(); return s >= 90 ? "#10B981" : s >= 70 ? "#F59E0B" : "#EF4444" }

    // ── 处置率 (对齐 Web overview.handleRate: 后端真实 0~100, 顶不到时降级到本地统计)
    //   Web 端 formatRate(v) = Number(v.toFixed(1)) — 保留 1 位小数
    //   之前 Qt 用 Math.round() 取整, 在 0~1 小数场景下与 Web 不一致 (0.85 → Qt:1, Web:0.9)
    //   改为 .toFixed(1) 保证 1:1 对齐
    function handledRate() {
        var ov = situationController.overview
        if (ov && ov.handleRate !== undefined && ov.handleRate !== null) {
            var v = Number(ov.handleRate)
            return Number(v.toFixed(1))
        }
        var alarms = alarmController.alarms
        if (!alarms.length) return 0
        var done = 0
        for (var i = 0; i < alarms.length; i++)
            if (alarms[i].status === "confirmed" || alarms[i].status === "false_alarm") done++
        return Number((done * 100 / alarms.length).toFixed(1))
    }
    // ── 时间戳解析 ──
    function parseTs(s) {
        if (!s) return null
        if (typeof s === "number") { var dn = new Date(s); return isNaN(dn.getTime()) ? null : dn }
        var d = new Date(String(s).replace(" ", "T"))
        if (isNaN(d.getTime())) {
            var num = Number(s)
            if (num > 1e11) { var d2 = new Date(num); if (!isNaN(d2.getTime())) return d2 }
            return null
        }
        return d
    }
    // ── 时间列格式化 (兼容数字毫秒/字符串 timestamp) ──
    function fmtHm(s) {
        var d = parseTs(s)
        return d ? Qt.formatDateTime(d, "HH:mm") : "-"
    }
    // ── 时分秒 (对齐 Web 实时告警表 HH:mm:ss) ──
    function fmtHms(s) {
        var d = parseTs(s)
        return d ? Qt.formatDateTime(d, "HH:mm:ss") : "-"
    }
    // ── 级别徽章背景色 (对齐 Web alarm-row level badge) ──
    function levelBadgeColor(l) {
        return l === "critical" ? "#D51F3D" : l === "high" ? "#E85720" : l === "medium" ? "#B88D12" : "#1676D2"
    }
    // ── 今日告警数 (对齐 Web overview.alarmStats.todayTotal: 后端权威) ──
    function countDay(offset) {
        if (offset === 0) {
            var ov = situationController.overview
            if (ov && ov.alarmStats && ov.alarmStats.todayTotal !== undefined
                && ov.alarmStats.todayTotal !== null) {
                return Number(ov.alarmStats.todayTotal)
            }
        }
        var alarms = alarmController.alarms, today = new Date(), cnt = 0
        today.setHours(0, 0, 0, 0)
        for (var i = 0; i < alarms.length; i++) {
            var d = parseTs(alarms[i].timestamp)
            if (!d) continue
            var diff = Math.floor((today.getTime() - d.getTime()) / 86400000)
            if (diff === offset) cnt++
        }
        return cnt
    }
    // ── 今日告警趋势 % (Web: alarmTrend = 今日 vs 昨日) ──
    function alarmDayTrend() {
        var t0 = countDay(0), y0 = countDay(1)
        if (y0 <= 0) return { pct: 0, up: t0 > 0 }
        return { pct: Math.round((t0 - y0) * 100 / y0), up: t0 >= y0 }
    }
    // ── 设备在线率 % (对齐 Web deviceOnline trendDesc) ──
    function onlineRate() {
        var total = deviceController.deviceCount
        return total > 0 ? (deviceController.onlineCount * 100 / total).toFixed(1) : "--"
    }
    // ── Agent 活跃度近似值 (设备端无 agent-activity API, 用告警量推算) ──
    function agentCalls() {
        var n = alarmController.alarmCount || alarmController.alarms.length
        return { perception: n * 12 + 186, analysis: n * 5 + 74, decision: n * 2 + 31, expert: Math.max(0, Math.round(n / 6)) }
    }
    // ── 平均置信度 (对齐 Web avgConfidence 0~1) ──
    function avgConfidence() {
        var alarms = alarmController.alarms, sum = 0, cnt = 0
        for (var i = 0; i < alarms.length; i++) {
            var c = alarms[i].confidence
            if (c !== undefined && c !== null) { sum += Number(c); cnt++ }
        }
        if (cnt === 0) return 0.92
        var v = sum / cnt
        return v > 1 ? Math.min(1, v / 100) : v
    }
    // ── 联邦聚合准确率 % (currentRound map, 兼容多字段名) ──
    function fedAccuracy() {
        var cr = federationController.currentRound || ({})
        var a = cr.accuracy !== undefined ? cr.accuracy : (cr.aggregation_accuracy !== undefined ? cr.aggregation_accuracy : undefined)
        if (a === undefined) return "--"
        a = Number(a)
        return (a > 1 ? a : a * 100).toFixed(1)
    }
    // ── 联邦学习当前轮次号 (currentRound 为 map, 兼容多字段名) ──
    function fedRoundNo() {
        var cr = federationController.currentRound || ({})
        if (cr.round_id !== undefined) return cr.round_id
        if (cr.id !== undefined) return cr.id
        if (cr.round !== undefined) return cr.round
        return federationController.rounds.length
    }
    // ── 告警趋势分桶 (对齐 Web: 24h → /situation/hourly-stats; 7d/30d → /stats/alarm-trend) ──
    function buildTrend(mode) {
        mode = mode || dashboard.trendMode
        var res = { labels: [], data: [] }

        if (mode === "24h") {
            // hourly-stats 返回 [{hour, alarmCount, onlineDevices}], hour 是 0-23
            // [FIX v7.3] X 轴 label 节点对齐 Web (interval=3 → 每 4 个点一个 label):
            //   原始 (hh%6===5) 只有 hh=5,11,17,23 有 label, 显示过于稀流
            //   Web 端展示 6 个 label (00, 04, 08, 12, 16, 20) 在指数 0/4/8/12/16/20 上
            var hs = situationController.hourlyStats
            if (hs && hs.length > 0) {
                var idx = {}, maxHour = 0
                for (var i = 0; i < hs.length; i++) {
                    var h = Number(hs[i].hour)
                    if (!isNaN(h)) { idx[h] = Number(hs[i].alarmCount || hs[i].alarms || 0); if (h > maxHour) maxHour = h }
                }
                for (var hh = 0; hh <= maxHour; hh++) {
                    res.data.push(idx[hh] || 0)
                    // 每 4 小时 (0/4/8/12/16/20) 打一个 "HH:00" label, 与 Web echarts axisLabel.interval=3 一致
                    res.labels.push((hh % 4 === 0) ? (String(hh).padStart(2, "0") + ":00") : "")
                }
                return res
            }
        } else {
            // 7d / 30d → alarm-trend 返回 [{hour (MM-DD 星期 或 HH:MM), count}]
            var tr = situationController.alarmTrend
            if (tr && tr.length > 0) {
                var wd = ["日", "一", "二", "三", "四", "五", "六"]
                for (var j = 0; j < tr.length; j++) {
                    var p = tr[j]
                    res.data.push(Number(p.count || 0))
                    var lab = p.hour || p.label || ""
                    if (mode === "7d") {
                        // 优先使用日期定位星期几; 退后用 label 文本
                        var d = parseTs(lab)
                        var wl = d ? wd[d.getDay()] : (lab || "")
                        res.labels.push(wl)
                    } else {
                        // [FIX v7.6] 30d label 文本 1:1 对齐 Web 端 (后端 hour 字段 "MM-DD 周X")
                        //   之前生成 "-Xd" (如 "-0d", "-5d") 与 Web "08-20 周四" 视觉不一致
                        //   现在直接用后端 hour 字段, 保持 X 轴密度控制 (每 5 天打点)
                        res.labels.push(j % 5 === 0 ? (lab || ("-" + (tr.length - 1 - j) + "d")) : "")
                    }
                }
                return res
            }
        }

        // 后端未返回时, 使用历史本地聚合 (顶到降级路径, 仅作为避免空图)
        var alarms = alarmController.alarms, now = new Date()
        var n = mode === "24h" ? 24 : (mode === "7d" ? 7 : 30)
        for (var k = 0; k < n; k++) res.data.push(0)
        for (var a = 0; a < alarms.length; a++) {
            var d2 = parseTs(alarms[a].timestamp)
            if (!d2) continue
            if (mode === "24h") {
                var hrs = Math.floor((now - d2) / 3600000)
                if (hrs >= 0 && hrs < n) res.data[n - 1 - hrs]++
            } else {
                var days = Math.floor((now - d2) / 86400000)
                if (days >= 0 && days < n) res.data[n - 1 - days]++
            }
        }
        for (var l = 0; l < n; l++) {
            if (mode === "24h") res.labels.push(l % 4 === 0 ? (String(l).padStart(2, "0") + ":00") : "")
            else if (mode === "7d") { var wd2 = ["日", "一", "二", "三", "四", "五", "六"]; res.labels.push(wd2[(now.getDay() - (n - 1 - l) + 14) % 7]) }
            // 30d 降级路径也使用"-Xd"作为 fallback (后端未返回时)
            else res.labels.push(l % 5 === 0 ? ("-" + (n - 1 - l) + "d") : "")
        }
        return res
    }
    // ── 环比: 后半 vs 前半 ──
    function trendDelta(mode) {
        var data = buildTrend(mode).data
        var half = Math.floor(data.length / 2)
        if (half === 0) return { up: false, pct: 0 }
        var f = 0, s = 0
        for (var i = 0; i < half; i++) f += data[i]
        for (var j = half; j < data.length; j++) s += data[j]
        if (f === 0) return { up: s > 0, pct: s === 0 ? 0 : 100 }
        var pct = Math.round(Math.abs(s - f) * 100 / f)
        return { up: s > f, pct: pct }
    }
    // ── 分区在线热力 (对齐 Web 项目热力图: name/rate, 按分区聚合在线率) ──
    function devGroups() {
        var devs = deviceController.devices, map = {}, order = []
        for (var i = 0; i < devs.length; i++) {
            var key = devs[i].location || devs[i].zone || "默认分区"
            if (map[key] === undefined) { map[key] = { total: 0, on: 0 }; order.push(key) }
            map[key].total++
            if (devs[i].status === "online" || devs[i].status === "active") map[key].on++
        }
        var res = []
        for (var k = 0; k < order.length; k++)
            res.push({ name: order[k], rate: Math.round(map[order[k]].on * 100 / map[order[k]].total) })
        return res
    }

    // ── 视图切换 (对齐 Web setCenterView + slideDirection) ──
    function setCenterView(v) {
        if (v !== "3d" && v !== "video") return
        if (dashboard.centerView === v) return
        dashboard.centerView = v
    }

    // ── 刷新全部数据 (对齐 Web fetchSituationData: 1:1 调用 SituationController) ──
    function refreshAll() {
        statusController.refresh()
        deviceController.refreshDevices()
        // 态势总览/告警趋势: 后端聚合权威, 不再本地计算 (1:1 对齐 Web)
        situationController.refreshOverview()
        situationController.refreshRealtimeAlarms(20)
        situationController.refreshHourlyStats()
        situationController.refreshAgents()
        situationController.refreshAlarmTrend()
        situationController.refreshMapDevices()
        lastUpdatedSec = 0
    }

    // ── 故障/维修设备数 (对齐 Web overview.deviceStats.maintenance) ──
    function faultCount() {
        var ov = situationController.overview
        if (ov && ov.deviceStats && ov.deviceStats.maintenance !== undefined
            && ov.deviceStats.maintenance !== null) {
            return Number(ov.deviceStats.maintenance)
        }
        var devs = deviceController.devices, n = 0
        for (var i = 0; i < devs.length; i++)
            if (devs[i].status === "error" || devs[i].status === "fault"
                || devs[i].status === "maintenance") n++
        return n
    }
    // ── 告警等级分布 (对齐 Web overview.alarmStats: 后端 authoritative 0~N 计数) ──
    function levelDist() {
        var ov = situationController.overview
        if (ov && ov.alarmStats && ov.alarmStats.critical !== undefined) {
            return {
                critical: Number(ov.alarmStats.critical || 0),
                high:     Number(ov.alarmStats.high || 0),
                medium:   Number(ov.alarmStats.medium || 0),
                low:      Number(ov.alarmStats.low || 0)
            }
        }
        var alarms = alarmController.alarms
        var m = { critical: 0, high: 0, medium: 0, low: 0 }
        for (var i = 0; i < alarms.length; i++) {
            var lv = alarms[i].level || "low"
            if (lv === "critical") m.critical++
            else if (lv === "high") m.high++
            else if (lv === "medium" || lv === "warning") m.medium++
            else m.low++
        }
        return m
    }
    // ── 误报率 % (对齐 Web overview.falsePositiveRate: 后端计算 0~100)
    //   [FIX v7.3] Web formatRate(v) = Number(v.toFixed(1)) — 保留 1 位小数
    function falseAlarmRate() {
        var ov = situationController.overview
        if (ov && ov.falsePositiveRate !== undefined && ov.falsePositiveRate !== null) {
            var v = Number(ov.falsePositiveRate)
            return Number(v.toFixed(1))
        }
        var alarms = alarmController.alarms
        if (!alarms.length) return 0
        var n = 0
        for (var i = 0; i < alarms.length; i++)
            if (alarms[i].status === "false_alarm") n++
        return Number((n * 100 / alarms.length).toFixed(1))
    }
    // ── 处置状态文本 (对齐 Web: 已处置/未处理) ──
    function statusText(s) {
        if (s === "confirmed" || s === "handled") return "已处置"
        if (s === "false_alarm") return "误报"
        return "未处理"
    }
    // ── 级别文本/颜色 (对齐 Web: 严重红/高橙/中黄/低蓝) ──
    function levelText(l) { return l === "critical" ? "严重" : l === "high" ? "高" : l === "medium" ? "中" : "低" }
    function levelColor(l) { return l === "critical" ? "#EF4444" : l === "high" ? "#FF6B35" : l === "medium" ? "#F59E0B" : "#3B82F6" }
    // ── 边缘算力调用近似值 ──
    function edgeCalls() {
        return Math.max(statusController.activeModels, Math.round((alarmController.alarmCount || 0) / 20))
    }
    // ── 多盒子算力负载 % (对齐 Web agents[]: 后端下发的各 agent load 0~100) ──
    function agentLoads() {
        var agents = situationController.agents
        if (agents && agents.length > 0) {
            // Web 后端 agents 返回顺序: perception / analysis / decision / expert
            var map = { perception: 0, analysis: 0, decision: 0, expert: 0 }
            for (var i = 0; i < agents.length; i++) {
                var a = agents[i]
                var t = (a.type || a.name || "").toLowerCase()
                var ld = Number(a.load || 0)
                if (t.indexOf("perception") >= 0 || t.indexOf("percept") >= 0) map.perception = ld
                else if (t.indexOf("analysis") >= 0 || t.indexOf("analys") >= 0) map.analysis = ld
                else if (t.indexOf("decision") >= 0 || t.indexOf("decis") >= 0) map.decision = ld
                else if (t.indexOf("expert") >= 0) map.expert = ld
            }
            return [
                Math.min(100, map.perception),
                Math.min(100, map.analysis),
                Math.min(100, map.decision),
                Math.min(100, map.expert)
            ]
        }
        var t = Math.min(100, Math.round(statusController.tpuUtilization))
        var n = alarmController.alarmCount || 0
        return [
            Math.min(100, t > 0 ? t : Math.min(100, n * 2)),
            Math.min(100, Math.round(t * 0.6) + (n > 0 ? 5 : 0)),
            Math.min(100, Math.round(t * 0.4)),
            Math.min(100, Math.round(t * 0.2))
        ]
    }

    // ═══ 主区: 仅总览内容 (1:1 对齐 Web /situation 态势大屏) ═══
    ColumnLayout {
        anchors.top: parent.top; anchors.topMargin: 8
        anchors.bottom: statusBar.top; anchors.left: parent.left; anchors.right: parent.right
        spacing: 0

            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 6

                // ════ 左列 (400px): 安全评分 | 今日统计 | 设备状态 ════
                ColumnLayout {
                    id: leftColumn
                    // [v7.2+] 全屏时宽度 0 + 隐藏 (中列填满中线布局)
                    visible: !dashboard._colHide
                    Layout.minimumWidth: dashboard._colHide ? 0 : 400
                    Layout.preferredWidth: dashboard._colHide ? 0 : 400
                    Layout.maximumWidth: dashboard._colHide ? 0 : 400
                    Layout.fillHeight: true; spacing: 6

                    // ── 面板: 安全评分 (对齐 Web score-gauge 半环仪表) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    AppIcon { name: "shield"; size: 16; iconColor: "#00B4FF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "安全评分"; color: "#00B4FF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            Canvas {
                                id: scoreGauge
                                Layout.fillWidth: true; Layout.fillHeight: true
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var score = dashboard.calcScore()
                                    var cx = width / 2, cy = height * 0.52
                                    var r = Math.min(width * 0.32, height * 0.46)
                                    // 半环渐变弧 (红→黄→绿, 对齐 Web axisLine gradient)
                                    var grad = ctx.createLinearGradient(cx - r, 0, cx + r, 0)
                                    grad.addColorStop(0, "#FC4F55"); grad.addColorStop(0.52, "#FFC569"); grad.addColorStop(1, "#42B112")
                                    ctx.lineWidth = 12; ctx.strokeStyle = grad; ctx.lineCap = "round"
                                    ctx.beginPath(); ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI); ctx.stroke()
                                    ctx.lineCap = "butt"
                                    // 内圆盘 + 内环 (对齐 Web #071A4B / #0754A8)
                                    ctx.fillStyle = "#071A4B"
                                    ctx.beginPath(); ctx.arc(cx, cy, r * 0.62, 0, 2 * Math.PI); ctx.fill()
                                    ctx.lineWidth = 2; ctx.strokeStyle = "#0754A8"
                                    ctx.beginPath(); ctx.arc(cx, cy, r * 0.62, 0, 2 * Math.PI); ctx.stroke()
                                    // 指针 (max=120 角度映射, 对齐 Web gauge)
                                    var ang = Math.PI * (1 - Math.min(score, 120) / 120)
                                    var pl = r * 0.78
                                    ctx.strokeStyle = "#00E4FF"; ctx.lineWidth = 3
                                    ctx.shadowColor = "#00DFFF"; ctx.shadowBlur = 6
                                    ctx.beginPath(); ctx.moveTo(cx, cy)
                                    ctx.lineTo(cx + pl * Math.cos(ang), cy - pl * Math.sin(ang)); ctx.stroke()
                                    ctx.shadowBlur = 0
                                    ctx.fillStyle = "#00E4FF"
                                    ctx.beginPath(); ctx.arc(cx, cy, 4, 0, 2 * Math.PI); ctx.fill()
                                    // 中心分数 (对齐 Web detail #00DFFF)
                                    ctx.fillStyle = "#00DFFF"; ctx.textAlign = "center"
                                    ctx.font = "bold 30px sans-serif"
                                    ctx.fillText(score + "分", cx, cy + r * 0.42)
                                    // 低/高 标注 (对齐 Web graphic)
                                    ctx.fillStyle = "#42B112"; ctx.font = "600 14px sans-serif"
                                    ctx.fillText("低", cx - r - 2, cy + 18)
                                    ctx.fillText("高", cx + r + 2, cy + 18)
                                    // 扣分明细 (对齐 Web graphic text)
                                    ctx.fillStyle = "#00B4FF"; ctx.font = "500 13px sans-serif"
                                    ctx.fillText("扣分明细", cx, cy + r * 0.42 + 24)
                                    ctx.font = "500 11px sans-serif"
                                    ctx.fillText("(离线设备、未闭环告警、算法异常)", cx, cy + r * 0.42 + 40)
                                }
                                Component.onCompleted: requestPaint()
                                Connections {
                                    target: situationController
                                    function onOverviewUpdated() { scoreGauge.requestPaint() }
                                }
                                Connections {
                                    target: statusController
                                    function onStatusUpdated() { scoreGauge.requestPaint() }
                                }
                            }
                        }
                    }

                    // ── 面板: 今日统计 (对齐 Web stats-grid 2×2) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    AppIcon { name: "statistics"; size: 16; iconColor: "#00B4FF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "今日统计"; color: "#00B4FF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            GridLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                columns: 2; rows: 2; columnSpacing: 8; rowSpacing: 8
                                anchors.leftMargin: 6; anchors.rightMargin: 6; anchors.bottomMargin: 8
                                Repeater {
                                    // [FIX v7.6] 1:1 对齐 Web todayStats:
                                    //   - 算法启用总数 → overview.totalAgents (后端权威)
                                    //   - 今日告警总数 → overview.alarmStats.todayTotal (后端权威)
                                    //   - 告警处置率 → overview.handleRate (后端权威, 1 位小数 + %, 与 Web formatRate 一致)
                                    //   - 边缘算力调用 → overview.activeAgents (后端权威, 当 totalAgents>0)
                                    //   缺失时降级到 statusController/本地计算, 避免空值
                                    model: {
                                        var ov = situationController.overview
                                        var totalAgents = (ov && ov.totalAgents !== undefined) ? Number(ov.totalAgents) : null
                                        var activeAgents = (ov && ov.activeAgents !== undefined) ? Number(ov.activeAgents) : null
                                        if (totalAgents === null) totalAgents = statusController.activeModels
                                        // [FIX v7.6] 处置率保留 1 位小数 (与 Web formatRate 一致): 避免 "0%" vs "0.0%" 差异
                                        var hr = dashboard.handledRate()
                                        var hrDisp = (hr === 0 || hr === "--" || hr === null) ? "0.0" : Number(hr).toFixed(1)
                                        return [
                                            { label: "算法启用总数", value: String(totalAgents), icon: "ai",     c: "#01B9E7" },
                                            { label: "今日告警总数", value: String(dashboard.countDay(0)), icon: "alarm",  c: "#D13838" },
                                            { label: "告警处置率",   value: hrDisp + "%", icon: "check",  c: "#3EB011" },
                                            { label: "边缘算力调用", value: (activeAgents !== null && totalAgents > 0) ? String(activeAgents) : "--", icon: "device", c: "#7938D1" }
                                        ]
                                    }
                                    delegate: Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        color: "#071A4B"; radius: 4; border.color: "#0A2C6E"; border.width: 1
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                                            AppIcon { name: modelData.icon; size: 26; iconColor: modelData.c }
                                            ColumnLayout {
                                                spacing: 2; Layout.fillWidth: true
                                                Text { text: modelData.value; font.pixelSize: 24; font.bold: true; color: "#00DFFF" }
                                                Text { text: modelData.label; font.pixelSize: 12; color: "#AADDFF" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 面板: 设备状态 (对齐 Web device-status 环形饼图) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    AppIcon { name: "device"; size: 16; iconColor: "#00B4FF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "设备状态"; color: "#00B4FF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                                Canvas {
                                    id: devicePie
                                    Layout.preferredWidth: 108; Layout.preferredHeight: 108
                                    Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 12
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = 54, cy = 54
                                        var total = deviceController.deviceCount
                                        var on = deviceController.onlineCount
                                        var fault = dashboard.faultCount()
                                        var off = Math.max(0, total - on - fault)
                                        var segs = [ { v: on, c: "#2FC414" }, { v: off, c: "#FC4F55" }, { v: fault, c: "#7D817B" } ]
                                        ctx.lineWidth = 14
                                        if (total <= 0) {
                                            ctx.strokeStyle = "#12305E"
                                            ctx.beginPath(); ctx.arc(cx, cy, 42, 0, 2 * Math.PI); ctx.stroke()
                                        } else {
                                            var a = -Math.PI / 2
                                            for (var i = 0; i < segs.length; i++) {
                                                if (segs[i].v <= 0) continue
                                                var a2 = a + 2 * Math.PI * segs[i].v / total
                                                ctx.strokeStyle = segs[i].c
                                                ctx.beginPath(); ctx.arc(cx, cy, 42, a, a2); ctx.stroke()
                                                a = a2
                                            }
                                        }
                                        var rate = total > 0 ? Math.round(on * 100 / total) : 0
                                        ctx.fillStyle = "#00F333"; ctx.textAlign = "center"
                                        ctx.font = "bold 22px sans-serif"
                                        ctx.fillText(rate + "%", cx, cy + 8)
                                    }
                                    Component.onCompleted: requestPaint()
                                    Connections {
                                    target: situationController
                                    function onOverviewUpdated() { devicePie.requestPaint() }
                                }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 10; Layout.alignment: Qt.AlignVCenter
                                    RowLayout {
                                        spacing: 12
                                        Rectangle {
                                            width: 32; height: 32; radius: 4
                                            color: "transparent"; border.color: "#00B4FF"; border.width: 1
                                            AppIcon { name: "camera"; size: 18; iconColor: "#00B4FF"; anchors.centerIn: parent }
                                        }
                                        Text { text: "视频设备（" + deviceController.deviceCount + "）"; color: "#00B4FF"; font.pixelSize: 18 }
                                    }
                                    RowLayout {
                                        spacing: 12
                                        RowLayout { spacing: 6
                                            Rectangle { width: 8; height: 8; color: "#17D71E" }
                                            Text { text: "在线: " + deviceController.onlineCount; color: "#17D71E"; font.pixelSize: 15 }
                                        }
                                        RowLayout { spacing: 6
                                            Rectangle { width: 8; height: 8; color: "#FC4F55" }
                                            Text { text: "离线: " + Math.max(0, deviceController.deviceCount - deviceController.onlineCount - dashboard.faultCount()); color: "#FC4F55"; font.pixelSize: 15 }
                                        }
                                        RowLayout { spacing: 6
                                            Rectangle { width: 8; height: 8; color: "#7D817B" }
                                            Text { text: "故障: " + dashboard.faultCount(); color: "#7D817B"; font.pixelSize: 15 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ════ 中列: 园区态势图(3D) + 实时告警 ════
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6

                    // ── 面板: 园区态势图 (对齐 Web map-panel; 视频监控切换已移除) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0

                            // 标题栏: 园区态势图 / 视频轮询 + 视图操作 (对齐 Web scene-actions + view-switch-btn)
                            Rectangle {
                                Layout.fillWidth: true; height: 36
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                    Text {
                                        text: dashboard.centerView === "3d" ? "园区态势图" : "视频轮询"
                                        font.pixelSize: 14; font.bold: true; color: "#00B4FF"
                                    }

                                    // ── 3D 视图专属: 复位 / 隐藏标签 / 自动巡视 (对齐 Web scene-actions) ──
                                    //   编辑布局/预案演练/小地图: 内置端无对应能力 (Web demo 场景同样不显示), 如实不呈现
                                    Repeater {
                                        model: dashboard.centerView === "3d" ? [
                                            { l: "复位", k: "reset" },
                                            { l: dashboard.sceneLabelsVisible ? "隐藏标签" : "显示标签", k: "labels" },
                                            { l: dashboard.patrolActive ? "停止巡视" : "自动巡视", k: "patrol" }
                                        ] : []
                                        delegate: Button {
                                            height: 24
                                            property var dataObj: modelData
                                            background: Rectangle {
                                                radius: 3
                                                color: (dataObj.k === "patrol" && dashboard.patrolActive)
                                                       ? Qt.rgba(0, 0.706, 1, 0.25) : Qt.rgba(0, 0.706, 1, 0.1)
                                                border.color: Qt.rgba(0, 0.706, 1, 0.3); border.width: 1
                                            }
                                            contentItem: Text {
                                                text: dataObj.l; font.pixelSize: 12; color: "#00B4FF"
                                                leftPadding: 10; rightPadding: 10
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                // [FIX v7.3] centerViewLoader.item = threeDScene 外层 stadiumLoader,
                                                //   已封装 resetView/setShowLabels/patrolStep 转发
                                                var ldr = centerViewLoader.item
                                                if (dashboard.centerView !== "3d" || !ldr) return
                                                if (dataObj.k === "reset") {
                                                    if (ldr.resetView) ldr.resetView()
                                                } else if (dataObj.k === "labels") {
                                                    dashboard.sceneLabelsVisible = !dashboard.sceneLabelsVisible
                                                    if (ldr.setShowLabels) ldr.setShowLabels(dashboard.sceneLabelsVisible)
                                                } else if (dataObj.k === "patrol") {
                                                    dashboard.patrolActive = !dashboard.patrolActive
                                                }
                                            }
                                        }
                                    }

                                    // [v7.6] 自动巡视驱动 (对齐 Web togglePatrol: 相机绕场景缓速环视)
                                    Timer {
                                        interval: 50; repeat: true
                                        running: dashboard.patrolActive && dashboard.centerView === "3d" && !dashboard.centerFullscreen
                                        onTriggered: {
                                            var ldr = centerViewLoader.item
                                            if (ldr && ldr.patrolStep) ldr.patrolStep()
                                        }
                                    }

                                    // ── 视频轮巡专属: 1/4分屏 + 开始/停止轮巡 (对齐 Web scene-actions) ──
                                    Repeater {
                                        model: dashboard.centerView === "video"
                                               ? [
                                                    { kind: "layout", v: 1,    l: "1分屏" },
                                                    { kind: "layout", v: 4,    l: "4分屏" },
                                                    { kind: "patrol", l: videoPatrolLoader.item
                                                         ? (videoPatrolLoader.item.pollingActive ? "停止轮巡" : "开始轮巡")
                                                         : "开始轮巡" }
                                                 ]
                                               : []
                                        delegate: Button {
                                            height: 24
                                            property var dataObj: modelData
                                            background: Rectangle {
                                                radius: 3
                                                color: dataObj.kind === "layout"
                                                    ? (videoPatrolLoader.item && videoPatrolLoader.item.layout === dataObj.v
                                                        ? "#00B4FF" : Qt.rgba(0, 0.706, 1, 0.1))
                                                    : (videoPatrolLoader.item && videoPatrolLoader.item.pollingActive
                                                        ? "#00B4FF" : Qt.rgba(0, 0.706, 1, 0.1))
                                                border.color: Qt.rgba(0, 0.706, 1, 0.3); border.width: 1
                                            }
                                            contentItem: Text {
                                                text: dataObj.l; font.pixelSize: 12
                                                color: (dataObj.kind === "layout"
                                                       ? (videoPatrolLoader.item && videoPatrolLoader.item.layout === dataObj.v)
                                                       : (videoPatrolLoader.item && videoPatrolLoader.item.pollingActive))
                                                       ? "#040C2B" : "#00B4FF"
                                                leftPadding: 10; rightPadding: 10
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (dataObj.kind === "layout" && videoPatrolLoader.item) {
                                                    videoPatrolLoader.item.setLayout(dataObj.v)
                                                } else if (dataObj.kind === "patrol" && videoPatrolLoader.item) {
                                                    videoPatrolLoader.item.togglePolling()
                                                }
                                            }
                                        }
                                    }

                                    // ── 通道数 (对齐 Web videoDeviceList.length) ──
                                    Text {
                                        visible: dashboard.centerView === "video"
                                        text: situationController.channels.length + "个通道"
                                        font.pixelSize: 11; color: "#236DB7"
                                    }

                                    Item { Layout.fillWidth: true }

                                    // ── 视图切换按钮 (对齐 Web view-switch-btn: 园区态势图 / 视频监控) ──
                                    Row {
                                        spacing: 0
                                        Rectangle {
                                            width: 80; height: 26
                                            color: dashboard.centerView === "3d" ? "#00B4FF" : "transparent"
                                            border.color: "#00B4FF"; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "态势图"
                                                color: dashboard.centerView === "3d" ? "#040C2B" : "#00B4FF"
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: dashboard.setCenterView("3d")
                                            }
                                        }
                                        Rectangle {
                                            width: 80; height: 26
                                            color: dashboard.centerView === "video" ? "#00B4FF" : "transparent"
                                            border.color: "#00B4FF"; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "视频轮询"
                                                color: dashboard.centerView === "video" ? "#040C2B" : "#00B4FF"
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: dashboard.setCenterView("video")
                                            }
                                        }
                                    }

                                    Button {
                                        width: 56; height: 24
                                        background: Rectangle {
                                            radius: 3; color: dashboard.centerFullscreen ? Qt.rgba(0, 0.706, 1, 0.25) : Qt.rgba(0, 0.706, 1, 0.1)
                                            border.color: Qt.rgba(0, 0.706, 1, 0.3); border.width: 1
                                        }
                                        contentItem: Text {
                                            text: dashboard.centerFullscreen ? "退出全屏" : "全屏"; font.pixelSize: 12; color: "#00B4FF"
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                        }
                                        // [v7.2+] 切换中列内部全屏覆盖: 隐藏左右列 + 下方告警表
                                        //   按 ESC 或再次点击可退出; 不再跳转到 sidebar 页面
                                        onClicked: dashboard.toggleFullscreen()
                                    }
                                }
                            }

                            // 内容区: 3D 态势图 / 视频轮巡 (对齐 Web swipe-container, 使用 Loader 避免与 Locate3DPanel 互住)
                            Loader {
                                id: centerViewLoader
                                Layout.fillWidth: true; Layout.fillHeight: true
                                sourceComponent: dashboard.centerView === "3d" ? threeDScene : videoPatrolScene
                            }

                            Component {
                                id: threeDScene
                                // [体育场3D] 运行时探测 Quick3D 可用性:
                                //   可用 → StadiumScene3D (Qt Quick 3D 真 3D); 否则回退 Locate3DPanel (Canvas 2.5D)
                                Loader {
                                    id: stadiumLoader
                                    Layout.fillWidth: true; Layout.fillHeight: true

                                    Component.onCompleted: {
                                        situationController.refreshSceneConfig()
                                        situationController.refreshMapDevices()
                                        pickSceneSource()
                                    }
                                    // [设备兼容] 先探明渲染后端再加载: legacy 软件渲染无 RHI,
                                    // View3D 实例化后析构会 SEGV → 软件环境直接加载 Canvas 2.5D, 不碰 StadiumScene3D
                                    function pickSceneSource() {
                                        var api = GraphicsInfo.api
                                        if (api === GraphicsInfo.Unknown) { pickTimer.start(); return }
                                        if (api === GraphicsInfo.Software) {
                                            console.log("[DashboardView] 软件渲染 (无 RHI) → 直接加载 Locate3DPanel")
                                            setSource("Locate3DPanel.qml")
                                            return
                                        }
                                        var comp = Qt.createComponent("StadiumScene3D.qml")
                                        console.log("[DashboardView] StadiumScene3D.qml status=" + comp.status
                                            + (comp.status !== Component.Ready ? " err=" + comp.errorString() : ""))
                                        setSource(comp.status === Component.Ready ? "StadiumScene3D.qml" : "Locate3DPanel.qml")
                                    }
                                    Timer { id: pickTimer; interval: 100; onTriggered: stadiumLoader.pickSceneSource() }
                                    onStatusChanged: console.log("[DashboardView] stadiumLoader status=" + status
                                        + (status === Loader.Error ? " (" + source + ")" : ""))
                                    onItemChanged: bindSceneItem()

                                    function bindSceneItem() {
                                        if (!item) return
                                        try { item.buildings = Qt.binding(function () { return dashboard.sceneBuildings }) } catch (e) {}
                                        try { item.devices = Qt.binding(function () { return dashboard.sceneDevices }) } catch (e) {}
                                        if (item.sceneMeta !== undefined) {
                                            try { item.sceneMeta = Qt.binding(function () { return dashboard.sceneMeta }) } catch (e) {}
                                        }
                                    }
                                    // 视角预设按钮调用入口 (原 Locate3DPanel.resetView 转发)
                                    function resetView() { if (item && item.resetView) item.resetView() }
                                    // [v7.6] 标签显隐转发 (StadiumScene3D.showLabels)
                                    function setShowLabels(v) { if (item && item.showLabels !== undefined) item.showLabels = v }
                                    // [v7.6] 自动巡视单步: StadiumScene3D 走 targetYaw 阻尼,
                                    //   Locate3DPanel(Canvas) 走 yaw + 手动重绘
                                    function patrolStep() {
                                        if (!item) return
                                        if (item.targetYaw !== undefined) { item.targetYaw += 0.01; return }
                                        if (item.yaw !== undefined) {
                                            item.yaw += 0.01
                                            if (item.scene && item.scene.requestPaint) item.scene.requestPaint()
                                        }
                                    }
                                    // [v7.2+] 取消路由转发: 设备信息卡 "查看态势/实时预览" 仅作为提示
                                }
                            }

                            Component {
                                id: videoPatrolScene
                                VideoPatrolPanel {
                                    id: videoPatrolLoader
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                }
                            }
                        }
                    }

                    // ── 面板: 实时告警 (对齐 Web realtimeAlarm 表格) ──
                    Rectangle {
                        id: alarmPanel
                        // [v7.2+] 全屏时隐藏, 中列填满
                        visible: !dashboard._colHide
                        Layout.fillWidth: true; Layout.preferredHeight: Math.max(230, Math.round(dashboard.height * 0.30))
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0

                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 6
                                    AppIcon { name: "alarm"; size: 16; iconColor: "#00B4FF" }
                                    Text { text: "实时告警"; color: "#00B4FF"; font.pixelSize: 14 }
                                    Item { Layout.fillWidth: true }
                                    // "进入告警中心" (对齐 Web alarm-more >>)
                                    Button {
                                        width: 28; height: 28
                                        background: Rectangle { color: "transparent" }
                                        contentItem: Text { text: ">>"; font.pixelSize: 15; color: "#00B4FF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: root.sidebarCurrentIndex = 2
                                    }
                                }
                            }

                            ListView {
                                id: alarmTable
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true
                                // [P1-#2 v7.0+] 1:1 对齐 Web situation/realtime-alarms 接口 (后端聚合)
                                //   偏好 situationController.realtimeAlarms, 降级到本地 alarms
                                model: situationController.realtimeAlarms.length > 0
                                       ? situationController.realtimeAlarms
                                       : alarmController.alarms
                                boundsBehavior: Flickable.StopAtBounds

                                header: Row {
                                    width: alarmTable.width; height: 31
                                    Rectangle { width: 54; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "级别"; color: "#AADDFF"; font.pixelSize: 14 } }
                                    Rectangle { width: 100; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "抓拍缩略图"; color: "#AADDFF"; font.pixelSize: 13 } }
                                    Rectangle { width: Math.max(40, alarmTable.width - 54 - 100 - 150 - 88 - 70 - 240); height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "所属分组"; color: "#AADDFF"; font.pixelSize: 14 } }
                                    Rectangle { width: 240; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "告警类型"; color: "#AADDFF"; font.pixelSize: 14 } }
                                    Rectangle { width: 150; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "告警时间"; color: "#AADDFF"; font.pixelSize: 14 } }
                                    Rectangle { width: 88; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "处理状态"; color: "#AADDFF"; font.pixelSize: 14 } }
                                    Rectangle { width: 70; height: 31; color: Qt.rgba(0, 0.141, 0.376, 0.6); border.color: "#00245A"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "操作"; color: "#AADDFF"; font.pixelSize: 14 } }
                                }

                                delegate: Rectangle {
                                    width: alarmTable.width; height: 44
                                    // [P1-#2 v7.0+] 对齐 Web alarm-stream 字段集:
                                    //   - 位置: description > location > channel_id > channelId > deviceName
                                    //   - 类型: type > alarm_type
                                    //   - 快照: snapshotUrl > snapshot_url > snapshot
                                    //   - 时间: time (HH:MM:SS) > timestamp
                                    readonly property string _location: modelData.description || modelData.location || modelData.channel_id || modelData.channelId || modelData.deviceName || "-"
                                    readonly property string _type: modelData.type || modelData.alarm_type || "-"
                                    readonly property string _snapshot: modelData.snapshotUrl || modelData.snapshot_url || modelData.snapshot || ""
                                    readonly property string _time: modelData.time || (modelData.timestamp ? dashboard.fmtHms(modelData.timestamp) : "-")
                                    property bool unhandled: dashboard.statusText(modelData.status) === "未处理"
                                    color: unhandled ? Qt.rgba(0.071, 0.125, 0.275, 0.55) : (index % 2 ? Qt.rgba(0.016, 0.094, 0.251, 0.3) : Qt.rgba(0.012, 0.055, 0.196, 0.3))
                                    border.color: "#00245A"; border.width: 1

                                    Row {
                                        anchors.fill: parent; spacing: 0
                                        Item { width: 54; height: 44
                                            Rectangle {
                                                anchors.centerIn: parent; width: 34; height: 20; radius: 2
                                                color: dashboard.levelBadgeColor(modelData.level)
                                                Text { anchors.centerIn: parent; text: dashboard.levelText(modelData.level); color: "#EAF8FF"; font.pixelSize: 13 }
                                            }
                                        }
                                        Item { width: 100; height: 44
                                            Rectangle {
                                                anchors.centerIn: parent; width: 56; height: 36; color: "#071A4B"; clip: true
                                                // [FIX v7.4] 报拍缩略图 URL 拼接 + 流协议识别:
                                                //   - 后端返回 /snapshots/... 相对路径 → 拼接 apiClient.baseUrl
                                                //   - data: / http(s): / file: 直接透传
                                                //   - [v7.5] 识别 continuous:// / rtmp:// / rtsp:// 等 ZLMediaKit 流协议前缀:
                                                //     loitering(徘徊) 类告警没有静态抓拍, 后端把 snapshot_url 存为
                                                //     continuous://rtp/gb_xxx 实时流 URL, 不能作为 Image src 加载.
                                                //     遇到流协议前缀直接返回空 → 占位 AppIcon 自动可见, 不报错不 404.
                                                property string fullSnapshotUrl: {
                                                    var s = parent.parent.parent._snapshot
                                                    if (!s) return ""
                                                    var ss = String(s)
                                                    if (ss.indexOf("data:") === 0 || ss.indexOf("http://") === 0 || ss.indexOf("https://") === 0 || ss.indexOf("file:") === 0) return ss
                                                    // ZLMediaKit 流协议前缀: continuous:// (gb28181 rtp) / rtmp / rtsp
                                                    // 不可作为 Image 的 src (QQuickImage 不识别), 返回空走占位图标
                                                    if (ss.indexOf("continuous://") === 0 || ss.indexOf("rtmp://") === 0 || ss.indexOf("rtmp:") === 0 || ss.indexOf("rtsp://") === 0 || ss.indexOf("rtsps://") === 0) return ""
                                                    var base = String(apiClient.baseUrl || "")
                                                    if (base.length === 0) return ss
                                                    if (base.charAt(base.length - 1) === "/") base = base.substring(0, base.length - 1)
                                                    var prefix = ss.charAt(0) === "/" ? "" : "/"
                                                    return base + prefix + ss
                                                }
                                                Image {
                                                    anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                                                    source: parent.fullSnapshotUrl
                                                    // 加载失败隐藏, 避免 X 占位符影响表格
                                                    onStatusChanged: if (status === Image.Error) visible = false
                                                }
                                                AppIcon { visible: !parent.fullSnapshotUrl; name: "camera"; size: 16; iconColor: "#12305E"; anchors.centerIn: parent }
                                            }
                                        }
                                        Item { width: Math.max(40, alarmTable.width - 54 - 100 - 150 - 88 - 70 - 240); height: 44
                                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 4
                                                text: parent.parent.parent._location; elide: Text.ElideRight
                                                color: parent.parent.parent.unhandled ? "#FF4747" : "#0079AB"; font.pixelSize: 14 }
                                        }
                                        Item { width: 240; height: 44
                                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 4
                                                text: parent.parent.parent._type; elide: Text.ElideRight
                                                color: parent.parent.parent.unhandled ? "#FF4747" : "#0079AB"; font.pixelSize: 14 }
                                        }
                                        Item { width: 150; height: 44
                                            Text { anchors.centerIn: parent; text: parent.parent.parent._time
                                                color: parent.parent.parent.unhandled ? "#FF4747" : "#0079AB"; font.pixelSize: 14 }
                                        }
                                        Item { width: 88; height: 44
                                            Text { anchors.centerIn: parent; text: dashboard.statusText(modelData.status)
                                                color: parent.parent.parent.unhandled ? "#FF4747" : "#0079AB"; font.pixelSize: 14 }
                                        }
                                        Item { width: 70; height: 44
                                            Text { anchors.centerIn: parent; text: parent.parent.parent.unhandled ? "去处警" : "查看"; color: "#00B4FF"; font.pixelSize: 14
                                                MouseArea { anchors.fill: parent; onClicked: root.sidebarCurrentIndex = 2 }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    parent: alarmTable.contentItem
                                    visible: alarmTable.count === 0
                                    anchors.horizontalCenter: alarmTable.contentItem.horizontalCenter; y: 24
                                    text: "暂无最新告警"; color: "#12305E"; font.pixelSize: 14
                                }
                            }
                        }
                    }
                }

                // ════ 右列 (400px): 告警类型分布 | 告警趋势 | 算力负载 ════
                ColumnLayout {
                    id: rightColumn
                    // [v7.2+] 全屏时隐藏 + 宽度 0
                    visible: !dashboard._colHide
                    Layout.minimumWidth: dashboard._colHide ? 0 : 400
                    Layout.preferredWidth: dashboard._colHide ? 0 : 400
                    Layout.maximumWidth: dashboard._colHide ? 0 : 400
                    Layout.fillHeight: true; spacing: 6

                    // ── 面板: 告警类型分布 (对齐 Web alarmType 饼图) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    AppIcon { name: "statistics"; size: 16; iconColor: "#00B4FF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "告警类型分布"; color: "#00B4FF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
                                ColumnLayout {
                                    Layout.preferredWidth: 128; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 12; spacing: 12
                                    Repeater {
                                        model: {
                                            var m = dashboard.levelDist()
                                            var tot = m.critical + m.high + m.medium + m.low
                                            return [
                                                { name: "严重告警", pct: tot ? Math.round(m.critical * 100 / tot) : 0, c: "#FC1526" },
                                                { name: "高级告警", pct: tot ? Math.round(m.high * 100 / tot) : 0,     c: "#F97141" },
                                                { name: "中级告警", pct: tot ? Math.round(m.medium * 100 / tot) : 0,   c: "#FBB040" },
                                                { name: "低级告警", pct: tot ? Math.round(m.low * 100 / tot) : 0,      c: "#00B4FF" }
                                            ]
                                        }
                                        delegate: ColumnLayout {
                                            spacing: 2
                                            Text { text: modelData.name; color: "#AADDFF"; font.pixelSize: 12 }
                                            Text { text: modelData.pct + "%"; color: modelData.c; font.pixelSize: 16; font.bold: true }
                                        }
                                    }
                                }
                                Canvas {
                                    id: typePie
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width / 2, cy = height * 0.46
                                        var r = Math.min(width, height) * 0.34
                                        var m = dashboard.levelDist()
                                        var total = m.critical + m.high + m.medium + m.low
                                        var segs = [ { v: m.critical, c: "#FC1526" }, { v: m.high, c: "#F97141" }, { v: m.medium, c: "#FBB040" }, { v: m.low, c: "#00B4FF" } ]
                                        if (total <= 0) {
                                            ctx.strokeStyle = "#12305E"; ctx.lineWidth = 10
                                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                        } else {
                                            var a = Math.PI / 2
                                            for (var i = 0; i < segs.length; i++) {
                                                if (segs[i].v <= 0) continue
                                                var a2 = a + 2 * Math.PI * segs[i].v / total
                                                ctx.fillStyle = segs[i].c
                                                ctx.beginPath(); ctx.moveTo(cx, cy)
                                                ctx.arc(cx, cy, r, a, a2); ctx.closePath(); ctx.fill()
                                                a = a2
                                            }
                                            // 内孔成环状
                                            ctx.fillStyle = "#040C2B"
                                            ctx.beginPath(); ctx.arc(cx, cy, r * 0.52, 0, 2 * Math.PI); ctx.fill()
                                        }
                                        // 误报率 (对齐 Web graphic falsePositiveRate)
                                        ctx.fillStyle = "#AADDFF"; ctx.textAlign = "center"; ctx.font = "13px sans-serif"
                                        ctx.fillText("误报率：" + dashboard.falseAlarmRate() + "%", cx, height - 14)
                                    }
                                    Component.onCompleted: requestPaint()
                                    Connections {
                                        target: situationController
                                        function onOverviewUpdated() { typePie.requestPaint() }
                                        function onAlarmTrendUpdated() { typePie.requestPaint() }
                                    }
                                }
                            }
                        }
                    }

                    // ── 面板: 告警趋势 (对齐 Web alarmTrend: 今日/7天/30天 + 4 级折线) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 8
                                    AppIcon { name: "statistics"; size: 16; iconColor: "#00B4FF" }
                                    Text { text: "告警趋势"; color: "#00B4FF"; font.pixelSize: 14 }
                                    Item { Layout.fillWidth: true }
                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: [ { v: "24h", l: "今日" }, { v: "7d", l: "7天" }, { v: "30d", l: "30天" } ]
                                            delegate: Button {
                                                width: 48; height: 22
                                                background: Rectangle {
                                                    radius: 3
                                                    color: dashboard.trendMode === modelData.v ? "#00B4FF" : Qt.rgba(0, 0.706, 1, 0.1)
                                                    border.color: Qt.rgba(0, 0.706, 1, 0.3); border.width: 1
                                                }
                                                contentItem: Text {
                                                    text: modelData.l; font.pixelSize: 12
                                                    color: dashboard.trendMode === modelData.v ? "#040C2B" : "#00B4FF"
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: { dashboard.trendMode = modelData.v; trendChart2.requestPaint() }
                                            }
                                        }
                                    }
                                }
                            }
                            Canvas {
                                id: trendChart2
                                Layout.fillWidth: true; Layout.fillHeight: true
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var tr = dashboard.buildTrend(dashboard.trendMode)
                                    var data = tr.data, labels = tr.labels, n = data.length
                                    var m = dashboard.levelDist()
                                    var tot = m.critical + m.high + m.medium + m.low
                                    var ws = tot ? [m.critical / tot, m.high / tot, m.medium / tot, m.low / tot] : [0.15, 0.25, 0.25, 0.35]
                                    var series = [
                                        { name: "严重", c: "#FC1526", w: ws[0] },
                                        { name: "高",   c: "#F97141", w: ws[1] },
                                        { name: "中",   c: "#FBB040", w: ws[2] },
                                        { name: "低",   c: "#00B4FF", w: ws[3] }
                                    ]
                                    var maxV = Math.max.apply(null, data.concat([1]))
                                    var padL = 36, padR = 12, padT = 26, padB = 24
                                    var w = width - padL - padR, h = height - padT - padB
                                    // 图例 (对齐 Web legend 右上)
                                    var lx = width - padR
                                    ctx.font = "12px sans-serif"; ctx.textAlign = "right"
                                    for (var s = series.length - 1; s >= 0; s--) {
                                        ctx.fillStyle = "#0079AB"
                                        ctx.fillText(series[s].name, lx, 12)
                                        lx -= ctx.measureText(series[s].name).width + 10
                                        ctx.fillStyle = series[s].c
                                        ctx.beginPath(); ctx.arc(lx - 4, 8, 5, 0, 2 * Math.PI); ctx.fill()
                                        lx -= 20
                                    }
                                    // 网格 (对齐 Web splitLine #0079AB 0.35)
                                    ctx.strokeStyle = "rgba(0,121,171,0.35)"; ctx.lineWidth = 1
                                    ctx.fillStyle = "#0079AB"; ctx.font = "12px sans-serif"; ctx.textAlign = "right"
                                    for (var g = 0; g <= 4; g++) {
                                        var gy = padT + h - h * g / 4
                                        ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(padL + w, gy); ctx.stroke()
                                        ctx.fillText(Math.round(maxV * g / 4), padL - 6, gy + 4)
                                    }
                                    // x 轴 (对齐 Web axisLine #0079AB)
                                    ctx.strokeStyle = "#0079AB"
                                    ctx.beginPath(); ctx.moveTo(padL, padT + h); ctx.lineTo(padL + w, padT + h); ctx.stroke()
                                    // 4 条折线 (总量按等级权重拆分, 对齐 Web levelSeries)
                                    for (var s2 = 0; s2 < series.length; s2++) {
                                        ctx.strokeStyle = series[s2].c; ctx.lineWidth = 2
                                        ctx.beginPath()
                                        for (var i = 0; i < n; i++) {
                                            var px = padL + (n === 1 ? w / 2 : w * i / (n - 1))
                                            var py = padT + h - (Math.round(data[i] * series[s2].w) / maxV) * h
                                            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                                        }
                                        ctx.stroke()
                                    }
                                    // x 轴标签 (FIX v7.3 对齐 Web: 只画非空 label, 不重复 filter)
                                    ctx.fillStyle = "#0079AB"; ctx.textAlign = "center"; ctx.font = "12px sans-serif"
                                    // 24h: labels 已在 buildTrend 中按每 4 小时生成 (0/4/8/12/16/20)
                                    //   7d: 每一天都生成 label (wd)
                                    //   30d: labels 按 5 天间隔 (对齐 Web axisLabel.interval=4 → 0/5/10/15/20/25)
                                    var step = dashboard.trendMode === "30d" ? 5 : dashboard.trendMode === "7d" ? 1 : 4
                                    for (var l = 0; l < n; l++) {
                                        if (labels[l] === "") continue
                                        // 24h / 7d: 直接画所有非空 (因为 labels 已控控密度)
                                        // 30d: 间隔 5 个点画一个 (index 0/5/10/15/20/25), 与 Web 一致
                                        if (dashboard.trendMode === "30d" && (l % step !== 0)) continue
                                        ctx.fillText(labels[l], padL + (n === 1 ? w / 2 : w * l / (n - 1)), padT + h + 16)
                                    }
                                }
                                Component.onCompleted: requestPaint()
                                Connections {
                                    target: situationController
                                    function onHourlyStatsUpdated() { trendChart2.requestPaint() }
                                    function onAlarmTrendUpdated() { trendChart2.requestPaint() }
                                    function onOverviewUpdated() { trendChart2.requestPaint() }
                                }
                            }
                        }
                    }

                    // ── 面板: 多盒子算力负载活跃度柱状图 (对齐 Web agentBar) ──
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "#040C2B"; border.color: "#05357C"; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0
                            Rectangle {
                                Layout.fillWidth: true; height: 32
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#003076" }
                                    GradientStop { position: 1.0; color: "#00003076" } }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    AppIcon { name: "device"; size: 16; iconColor: "#00B4FF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "多盒子算力负载活跃度柱状图"; color: "#00B4FF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            Canvas {
                                id: agentBarChart
                                Layout.fillWidth: true; Layout.fillHeight: true
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var loads = dashboard.agentLoads()
                                    var names = ["感知", "研判", "决策", "专家"]
                                    var padL = 46, padR = 16, padT = 26, padB = 30
                                    var w = width - padL - padR, h = height - padT - padB
                                    // y 轴 0-100% 每 20% 一格 (对齐 Web yAxis)
                                    ctx.fillStyle = "#0079AB"; ctx.font = "12px sans-serif"; ctx.textAlign = "right"
                                    for (var g = 0; g <= 5; g++) {
                                        var gy = padT + h - h * g / 5
                                        ctx.fillText(g === 0 ? "0" : (g * 20) + "%", padL - 8, gy + 4)
                                    }
                                    ctx.strokeStyle = "#0079AB"; ctx.lineWidth = 1
                                    ctx.beginPath(); ctx.moveTo(padL, padT); ctx.lineTo(padL, padT + h); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(padL, padT + h); ctx.lineTo(padL + w, padT + h); ctx.stroke()
                                    // 柱 (渐变 #00B4FF→#033F6C, 宽 12px, 对齐 Web bar)
                                    var bw = 12
                                    for (var i = 0; i < 4; i++) {
                                        var bx = padL + w * (i + 0.5) / 4 - bw / 2
                                        var bh = h * loads[i] / 100
                                        if (bh > 0) {
                                            var grad = ctx.createLinearGradient(0, padT + h - bh, 0, padT + h)
                                            grad.addColorStop(0, "#00B4FF"); grad.addColorStop(1, "#033F6C")
                                            ctx.fillStyle = grad
                                            ctx.fillRect(bx, padT + h - bh, bw, bh)
                                        }
                                        // 顶部标签 {c}%
                                        ctx.fillStyle = "#00B4FF"; ctx.textAlign = "center"; ctx.font = "12px sans-serif"
                                        ctx.fillText(loads[i] + "%", bx + bw / 2, padT + h - bh - 6)
                                        // x 轴类目
                                        ctx.fillStyle = "#00B4FF"; ctx.font = "13px sans-serif"
                                        ctx.fillText(names[i], padL + w * (i + 0.5) / 4, padT + h + 18)
                                    }
                                }
                                Component.onCompleted: requestPaint()
                                Connections {
                                    target: situationController
                                    function onAgentsUpdated() { agentBarChart.requestPaint() }
                                    function onOverviewUpdated() { agentBarChart.requestPaint() }
                                }
                            }
                        }
                    }
                }
            }
    }

    // ═══ 底部状态栏 (保留 + 补充算法数) ═══
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 32; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 24

            Text { text: "CPU: " + statusController.cpuUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.cpuUsage > 80 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "GPU: " + statusController.gpuUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.gpuUsage > 80 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "TPU: " + statusController.tpuUtilization.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.tpuUtilization > 90 ? "#FF3D71" : "#00D4AA" }
            Text { text: "内存: " + statusController.memoryUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.memoryUsage > 85 ? "#FF6B35" : "#8B8FA3" }
            Text { text: "温度: " + statusController.temperature.toFixed(0) + "°C"; font.pixelSize: 12; color: statusController.temperature > 70 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "DDR: " + statusController.tpuMemoryUsed.toFixed(0) + "MB"; font.pixelSize: 12; color: "#8B8FA3" }
            Text { text: "算法: " + statusController.activeModels; font.pixelSize: 12; color: "#8B8FA3" }
            Item { Layout.fillWidth: true }
            Text { text: "模型: " + statusController.activeModels + " | 运行: " + statusController.uptime; font.pixelSize: 12; color: "#4A4D58" }

            // 30秒自动刷新
            Text { id: refreshCountdown; text: "30s"; font.pixelSize: 12; color: "#4A4D58" }
        }
    }

    // ── 每秒计时: lastUpdatedSec 递增 + 30秒自动刷新 ──
    Timer { interval: 1000; running: true; repeat: true
        property int countdown: 30
        onTriggered: {
            dashboard.lastUpdatedSec++
            countdown--
            refreshCountdown.text = countdown + "s"
            if (countdown <= 0) {
                countdown = 30
                dashboard.refreshAll()
            }
        }
    }

    // ── 周期刷新告警趋势 (对齐 Web: 模式变化时才重拉, 30秒轮询复用主 timer) ──
    onTrendModeChanged: {
        situationController.setAlarmTrendMode(dashboard.trendMode)
    }
    // ── 周期刷新实时告警 (独立于主 timer, 5s间隔, 对齐 WS 推送场景) ──
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: situationController.refreshRealtimeAlarms(20)
    }

    Component.onCompleted: {
        deviceController.refreshDevices()
        // [P1-#2 v7.0+] 一次性拉取所有态势面板数据 (1:1 对齐 Web fetchSituationData)
        situationController.refreshAll()
    }

    // ═══════════════════════════════════════════════════════════════
    //  AI 助手悬浮输入框 [R2 任务1]
    //  默认收起(右下角圆钮) → 点击展开输入卡 → 发送 aiController.sendMessage
    //  不遮挡首页主要统计内容 (收起时仅 52px 圆钮贴角)
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: aiAssistant
        z: 100
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.bottom: statusBar.top; anchors.bottomMargin: 12
        width: expanded ? 440 : 52
        height: expanded ? 176 : 52
        property bool expanded: false
        property string toast: ""

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // ── 展开态: 输入卡片 ──
        Rectangle {
            visible: aiAssistant.expanded && aiAssistant.width > 430
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: 436; height: 172
            color: "#141720"; radius: 10
            border.color: "#00D4AA"; border.width: 1

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                RowLayout {
                    spacing: 6; Layout.fillWidth: true
                    AppIcon { name: "ai"; size: 16; iconColor: "#00D4AA" }
                    Text { text: "AI 助手"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Text { text: "自然语言查询 · 全局可用"; font.pixelSize: 10; color: "#4A4D58" }
                    Item { Layout.fillWidth: true }
                    Button { text: "收起"; width: 48; height: 22
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: aiAssistant.expanded = false
                    }
                }

                // 预设问题
                Row {
                    spacing: 6; Layout.fillWidth: true
                    Repeater {
                        model: ["今日告警统计", "设备在线状态", "安全评估建议"]
                        delegate: Button {
                            height: 24
                            background: Rectangle { color: "#0D0F12"; radius: 12; border.color: "#3A3F4C"; border.width: 1 }
                            contentItem: Text { text: modelData; font.pixelSize: 11; color: "#8B8FA3"; leftPadding: 10; rightPadding: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: {
                                aiController.sendMessage(modelData)
                                aiAssistant.toast = "已发送: " + modelData
                                toastTimer.restart()
                            }
                        }
                    }
                }

                // 输入行
                RowLayout {
                    spacing: 8; Layout.fillWidth: true
                    TextField {
                        id: aiInput
                        Layout.fillWidth: true; height: 34
                        placeholderText: "输入问题, 例如: 最近一周哪类告警最多?"
                        placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                        background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830"; border.width: 1 }
                        onAccepted: {
                            if (text.trim()) {
                                aiController.sendMessage(text.trim())
                                aiAssistant.toast = "已发送: " + text.trim()
                                toastTimer.restart()
                                text = ""
                            }
                        }
                    }
                    Button { text: "发送"; width: 56; height: 34
                        background: Rectangle { color: aiInput.text.trim() ? "#00D4AA" : "#252830"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: aiInput.text.trim() ? "#0D0F12" : "#4A4D58"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (aiInput.text.trim()) {
                                aiController.sendMessage(aiInput.text.trim())
                                aiAssistant.toast = "已发送: " + aiInput.text.trim()
                                toastTimer.restart()
                                aiInput.text = ""
                            }
                        }
                    }
                }

                // 发送提示 + 跳转
                RowLayout {
                    spacing: 8; Layout.fillWidth: true; visible: aiAssistant.toast !== ""
                    Text { text: aiAssistant.toast; font.pixelSize: 11; color: "#00D4AA"; elide: Text.ElideRight; Layout.fillWidth: true }
                    Button { text: "前往 AI 助手 →"; height: 20
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#3B82F6"; verticalAlignment: Text.AlignVCenter }
                        onClicked: root.sidebarCurrentIndex = 9
                    }
                }
            }
        }

        Timer { id: toastTimer; interval: 4000; onTriggered: aiAssistant.toast = "" }

        // ── 收起态: 悬浮圆钮 ──
        Rectangle {
            visible: !aiAssistant.expanded
            width: 52; height: 52; radius: 26
            anchors.right: parent.right; anchors.bottom: parent.bottom
            color: "#141720"; border.color: "#00D4AA"; border.width: 1.5

            // 呼吸光圈
            Rectangle {
                anchors.centerIn: parent
                width: 52; height: 52; radius: 26
                color: "transparent"; border.color: "#00D4AA"; border.width: 1
                SequentialAnimation on opacity { loops: Animation.Infinite
                    NumberAnimation { from: 0.7; to: 0; duration: 1600 }
                }
                SequentialAnimation on scale { loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 1.6; duration: 1600 }
                }
            }

            AppIcon { name: "ai"; size: 24; iconColor: "#00D4AA"; anchors.centerIn: parent }

            MouseArea {
                anchors.fill: parent
                onClicked: { aiAssistant.expanded = true; aiInput.forceActiveFocus() }
            }
        }
    }
}
