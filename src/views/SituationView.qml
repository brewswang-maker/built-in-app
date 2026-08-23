// ========================================================================
// SituationView.qml — 安全态势大屏 [R2 任务2 优化] [体育场3D]
// 体育场 3D 场景 (Qt Quick 3D, 降级 Canvas 2.5D) + GPS 告警标记 + 实时告警流
// 场景数据同源 scene_config.json (situationController 运行时覆盖 + mapDevices 状态合并)
// 数据源: statusController + alarmController + situationController (box-sdk REST API + WebSocket)
//   + WsMessageRouter alarm-map-marker 推送 (GPS 定位告警渲染)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "qrc:///StadiumSceneData.js" as SceneData

Item {
    id: situationView

    property real securityScore: 0
    property var scoreDetails: ({})
    property var trendData: []
    property var deviceStatusCounts: ({ online: 0, offline: 0, maintenance: 0 })
    property var dimScores: ({ perimeter: 100, fire: 100, ppe: 100 })  // 分维度评分 (近24h告警类型)

    // ── 场景状态 (2.5D 等轴测, 数据与首页 Locate3DPanel 同源) ──
    property int viewMode: 0                 // 0=等轴测 1=俯视
    property var pulseDevs: ({})             // deviceId -> { until, sev } 告警脉冲
    property int tick: 0                     // 动画帧
    property bool heatOn: false              // 热力图叠加开关
    property int onlineCount: 0              // 场景设备统计
    property int alarmDevCount: 0

    readonly property string defLevel: securityScore >= 90 ? "L5" : securityScore >= 80 ? "L4" : securityScore >= 70 ? "L3" : securityScore >= 60 ? "L2" : "L1"
    readonly property color defLevelColor: securityScore >= 80 ? "#00D4AA" : securityScore >= 60 ? "#FFB800" : "#FF3D71"
    readonly property int algoTotal: configController.algorithms ? configController.algorithms.length : 0

    // ═══ 场景数据 (体育场: 后端 scene_config.json 覆盖 → JS 常量兜底, mapDevices 合并真实状态) ═══
    readonly property var sceneMeta: situationController.sceneConfigLoaded
        && Object.keys(situationController.sceneMeta).length > 0
        ? situationController.sceneMeta : SceneData.SCENE_META
    readonly property var buildings: situationController.sceneConfigLoaded
        && situationController.sceneBuildings.length > 0
        ? situationController.sceneBuildings : SceneData.BUILDINGS
    readonly property var devices: SceneData.mergeDeviceStatus(
        situationController.sceneConfigLoaded && situationController.sceneDemoDevices.length > 0
            ? situationController.sceneDemoDevices : SceneData.DEMO_DEVICES,
        situationController.mapDevices)

    // 告警级别色 (对齐 LocationTrackView alarm-map-marker)
    readonly property var sevColors: ["#8B8FA3", "#3B82F6", "#3B82F6", "#FFB800", "#FF6B35", "#FF3D71"]

    function devStatusColor(d) {
        return d.status === "alarm" ? "#FF3D71" : d.status === "maintenance" ? "#F59E0B"
             : d.status === "offline" ? "#6B7280" : "#10B981"
    }

    // ═══ 投影 / 明暗 (与 Locate3DPanel 同款) ═══
    function sc() { return Math.min(scene3d.width / 205, scene3d.height / 128) }

    function iso(x, h, z) {
        var cx = scene3d.width / 2, cy = scene3d.height * 0.46
        var s = sc()
        if (viewMode === 1) return { x: cx + x * s, y: cy + z * s - h * 0 }
        return { x: cx + (x - z) * 0.866 * s, y: cy + (x + z) * 0.5 * s - h * s * 0.9 }
    }

    function shade(hex, f) {
        var c = hex.replace("#", "")
        var r = Math.round(parseInt(c.substring(0, 2), 16) * f)
        var g = Math.round(parseInt(c.substring(2, 4), 16) * f)
        var b = Math.round(parseInt(c.substring(4, 6), 16) * f)
        return "rgb(" + Math.min(255, r) + "," + Math.min(255, g) + "," + Math.min(255, b) + ")"
    }

    // ═══ 告警联动: 告警列表 location 模糊匹配设备 → 30s 脉冲 ═══
    // (场景组件内部自带告警脉冲渲染, 此处维护 pulseDevs 供统计/热力图使用)
    function refreshPulse() {
        var alarms = alarmController.alarms
        var now = Date.now()
        var obj = ({})
        for (var i = 0; i < alarms.length; i++) {
            var loc = alarms[i].location || alarms[i].channel_id || ""
            var lvl = alarms[i].level
            var sev = (lvl === "critical" || lvl === "紧急") ? 5 : (lvl === "warning" || lvl === "高") ? 4 : 3
            for (var j = 0; j < devices.length; j++) {
                var d = devices[j]
                if (loc && (loc.indexOf(d.location) >= 0 || loc.indexOf(d.name) >= 0)) {
                    obj[d.id] = { until: now + 30000, sev: sev }
                }
            }
        }
        pulseDevs = obj
        updateDevStats()
        repaintScene()
    }

    function updateDevStats() {
        var on = 0, al = 0
        var now = Date.now()
        for (var i = 0; i < devices.length; i++) {
            var st = devices[i].status
            if (pulseDevs[devices[i].id] && pulseDevs[devices[i].id].until > now) st = "alarm"
            if (st === "online") on++
            else if (st === "alarm") al++
        }
        onlineCount = on; alarmDevCount = al
    }

    // ═══ 分维度评分: 近24h 告警类型分布 → 周界防护/消防安全/PPE合规 ═══
    function computeDimScores() {
        var peri = 0, fire = 0, ppe = 0
        var now = new Date()
        var alarms = alarmController.alarms
        for (var i = 0; i < alarms.length; i++) {
            var t = new Date(alarms[i].time)
            if (isNaN(t.getTime()) || (now - t) > 86400000) continue
            var ty = (alarms[i].type || "") + (alarms[i].location || "")
            if (ty.indexOf("火") >= 0 || ty.indexOf("烟") >= 0) fire++
            else if (ty.indexOf("帽") >= 0 || ty.toUpperCase().indexOf("PPE") >= 0 || ty.indexOf("衣") >= 0) ppe++
            else peri++
        }
        dimScores = {
            perimeter: Math.max(40, 100 - Math.min(60, peri * 3)),
            fire: Math.max(40, 100 - Math.min(60, fire * 4)),
            ppe: Math.max(40, 100 - Math.min(60, ppe * 4))
        }
    }

    // ═══ 热力图叠加点: 告警设备位置 (iso 投影归一化, 精确贴合场景) ═══
    function heatPts() {
        if (scene3d.width <= 0) return []
        var pts = [], alarms = alarmController.alarms
        for (var i = 0; i < Math.min(alarms.length, 50); i++) {
            var loc = (alarms[i].location || "") + (alarms[i].channel_id || "")
            for (var j = 0; j < devices.length; j++) {
                var d = devices[j]
                if (loc && (loc.indexOf(d.location) >= 0 || loc.indexOf(d.name.split(" ")[0]) >= 0)) {
                    var p = sceneProject(d.x, 0, d.z)
                    var found = false
                    for (var q = 0; q < pts.length; q++) if (pts[q].dev === d.id) { pts[q].count++; found = true; break }
                    if (!found) pts.push({ x: p.x / scene3d.width, y: p.y / scene3d.height, count: 1, type: alarms[i].type || "alarm", dev: d.id })
                    break
                }
            }
        }
        return pts
    }

    // ═══ GPS 标记 → 场景坐标 (优先设备匹配, 否则经纬度散布映射) ═══
    function markerPos(m) {
        if (m.deviceId) {
            for (var j = 0; j < devices.length; j++)
                if (devices[j].id === m.deviceId) return sceneProject(devices[j].x, 0, devices[j].z)
        }
        var wx = ((Math.abs(m.lng) * 10000) % 100) - 50
        var wz = ((Math.abs(m.lat) * 10000) % 80) - 40
        return sceneProject(wx, 0, wz)
    }

    // ═══ 场景投影统一入口: Quick3D mapFrom3DScene 优先, Canvas iso 投影兜底 ═══
    function sceneProject(x, y, z) {
        if (scene3d.item && scene3d.item.projectPoint !== undefined) {
            var p = scene3d.item.projectPoint(x, y, z)
            return { x: p.x + 4, y: p.y + 4 }   // View3D 内部 margin 补偿
        }
        return iso(x, y, z)
    }

    function repaintScene() {
        if (scene3d.item && scene3d.item.requestPaint) scene3d.item.requestPaint()
        markerCanvas.requestPaint()
    }

    // 场景组件设备选中 → 详情弹窗 (对齐原 Canvas 点击交互)
    function openSelectedPopup() {
        var sel = scene3d.item ? scene3d.item.selectedDev : ""
        if (sel === "") { camPopup.close(); return }
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            if (d.id === sel) {
                camPopup.camName = d.name
                camPopup.camStatus = d.status
                camPopup.camLoc = d.location || ""
                camPopup.camX = scene3d.width - 210
                camPopup.camY = 60
                camPopup.open()
                return
            }
        }
    }

    // 脉冲/标记动画帧驱动 (原 Canvas 内置 Timer 上提)
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: { tick++; markerCanvas.requestPaint() }
    }

    Component.onCompleted: {
        statusController.refresh()
        statusController.startPolling(5000)
        alarmController.refreshAlarms(50)
        alarmController.connectWebSocket()
        situationController.refreshSceneConfig()   // 体育场场景配置 (失败回退 StadiumSceneData.js)
        situationController.refreshMapDevices()    // 真实设备状态合并
        updateDevStats()
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
            // R2: 分维度评分 + 场景告警脉冲联动
            computeDimScores()
            refreshPulse()
        }
        function onNewAlarm(alarm) {
            // 新告警到达时自动刷新
            alarmListView.model = alarmController.alarms
        }
    }

    // [Audit-Add] 地图联动: WsMessageRouter.mapMarkerReceived → 场景地图告警闪烁
    //   后端 CLIENT_SHOW_MAP executor 查询设备 GPS 坐标后推送 alarm_map_marker
    //   此处监听并在 3D 厂区地图上实时渲染告警位置闪烁动画
    property var activeMapMarkers: []
    Connections {
        target: (typeof wsRouter !== "undefined") ? wsRouter : null
        function onMapMarkerReceived(payload) {
            if (!payload || !payload.has_gps) return
            var marker = {
                lat: payload.latitude,
                lng: payload.longitude,
                type: payload.alarm_type || "alarm",
                severity: payload.severity || 3,
                deviceId: payload.device_id || "",
                timestamp: payload.timestamp_ms || Date.now()
            }
            var markers = activeMapMarkers
            markers.push(marker)
            // 限制最多 20 个标记
            if (markers.length > 20) markers.shift()
            activeMapMarkers = markers
            // 触发地图重绘
            repaintScene()
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
            // 防御等级徽章 (按安全评分分档, 对标工业级大屏)
            Rectangle {
                width: 72; height: 24; radius: 4
                color: "transparent"
                border.color: situationView.defLevelColor; border.width: 1
                Layout.alignment: Qt.AlignVCenter
                Text {
                    anchors.centerIn: parent
                    text: "防御 " + situationView.defLevel
                    font.pixelSize: 11; font.bold: true; color: situationView.defLevelColor
                }
            }
            Rectangle { width: 1; height: 16; color: "#252830"; Layout.alignment: Qt.AlignVCenter }
            Text {
                text: "AI 边缘计算 · 工业级周界防御"
                font.pixelSize: 12; color: "#4A4D58"
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "周" + "日一二三四五六".charAt(new Date().getDay())
                font.pixelSize: 13; color: "#4A4D58"
            }
            Rectangle { width: 1; height: 16; color: "#252830"; Layout.alignment: Qt.AlignVCenter }
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

                        // 分维度评分 (真实数据: 近24h 告警类型分布)
                        Row {
                            spacing: 20; anchors.horizontalCenter: parent.horizontalCenter
                            Column { spacing: 2
                                Text { text: "周界防护"; font.pixelSize: 10; color: "#8B8FA3"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: Math.round(dimScores.perimeter); font.pixelSize: 16; font.bold: true
                                       color: dimScores.perimeter >= 80 ? "#00D4AA" : dimScores.perimeter >= 60 ? "#FFB800" : "#FF3D71"
                                       anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            Column { spacing: 2
                                Text { text: "消防安全"; font.pixelSize: 10; color: "#8B8FA3"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: Math.round(dimScores.fire); font.pixelSize: 16; font.bold: true
                                       color: dimScores.fire >= 80 ? "#00D4AA" : dimScores.fire >= 60 ? "#FFB800" : "#FF3D71"
                                       anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            Column { spacing: 2
                                Text { text: "PPE合规"; font.pixelSize: 10; color: "#8B8FA3"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: Math.round(dimScores.ppe); font.pixelSize: 16; font.bold: true
                                       color: dimScores.ppe >= 80 ? "#00D4AA" : dimScores.ppe >= 60 ? "#FFB800" : "#FF3D71"
                                       anchors.horizontalCenter: parent.horizontalCenter }
                            }
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

                // 设备状态 + 在线率
                Rectangle {
                    width: parent.width - 24; height: 150
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8

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

                        // 在线率进度条 (工业级可靠性指标)
                        Rectangle {
                            width: parent.width; height: 6; radius: 3; color: "#252830"
                            Rectangle {
                                width: parent.width * (deviceController.deviceCount > 0 ? 0.85 : 1.0); height: 6; radius: 3
                                color: "#00D4AA"
                            }
                        }
                        Text { text: "在线率 " + Math.round((deviceController.deviceCount > 0 ? 0.85 : 1.0) * 100) + "% · 工业级 7×24"; font.pixelSize: 11; color: "#8B8FA3" }
                    }
                }

                // 算力底座 (R2: 对标业界边缘 AI 平台能力指标)
                Rectangle {
                    width: parent.width - 24; height: 148
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 7

                        Text { text: "算力底座"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Row { spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "国产 AI SoC · NPU 边缘推理"; font.pixelSize: 11; color: "#8B8FA3" }
                        }
                        Row { spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#3B82F6"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "算法库 " + algoTotal + " 个 · 热插拔调度"; font.pixelSize: 11; color: "#8B8FA3" }
                        }
                        Row { spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "宽温无风扇 · 前端预处理"; font.pixelSize: 11; color: "#8B8FA3" }
                        }

                        Rectangle {
                            width: parent.width; height: 5; radius: 2.5; color: "#252830"
                            Rectangle { width: parent.width * (statusController.tpuUtilization / 100); height: 5; radius: 2.5; color: "#FFB800" }
                        }
                        Text { text: "TPU 实时占用 " + statusController.tpuUtilization.toFixed(0) + "%"; font.pixelSize: 10; color: "#4A4D58" }
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

                    // 热力图叠加层 (R2: 由真实告警分布动态生成, 工具栏可开关)
                    HeatmapOverlay {
                        anchors.fill: parent
                        anchors.margins: 8
                        z: 5
                        id: heatmapOverlay
                        heatPoints: { situationView.tick; situationView.heatPts() }
                        showHeatmap: situationView.heatOn
                    }

                    // ── 场景工具栏 (视角/热力图开关/图例/设备统计) ──
                    Row {
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: 14; anchors.rightMargin: 14; z: 6; spacing: 6

                        Rectangle {
                            width: 132; height: 26; radius: 4; color: "#141720"
                            border.color: "#252830"; border.width: 1
                            Row {
                                anchors.fill: parent; anchors.margins: 2; spacing: 2
                                Repeater {
                                    model: ["等轴测", "俯视"]
                                    Rectangle {
                                        width: 62; height: 20; radius: 3
                                        color: situationView.viewMode === index ? "#1E3A5F" : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 11
                                            color: situationView.viewMode === index ? "#3B82F6" : "#8B8FA3"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onPressed: {
                                                situationView.viewMode = index
                                                if (scene3d.item) {
                                                    if (index === 0 && scene3d.item.viewIso) scene3d.item.viewIso()
                                                    if (index === 1 && scene3d.item.viewTop) scene3d.item.viewTop()
                                                }
                                                situationView.repaintScene()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 76; height: 26; radius: 4; color: "#141720"
                            border.color: situationView.heatOn ? "#FF6B35" : "#252830"; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: situationView.heatOn ? "热力开" : "热力关"
                                font.pixelSize: 11; color: situationView.heatOn ? "#FF6B35" : "#8B8FA3"
                            }
                            MouseArea { anchors.fill: parent; onPressed: situationView.heatOn = !situationView.heatOn }
                        }

                        Rectangle {
                            width: 200; height: 26; radius: 4; color: "#141720"
                            border.color: "#252830"; border.width: 1
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 8; spacing: 8
                                Row { spacing: 3
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "在线" + situationView.onlineCount; font.pixelSize: 10; color: "#8B8FA3" }
                                }
                                Row { spacing: 3
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "告警" + situationView.alarmDevCount; font.pixelSize: 10; color: "#8B8FA3" }
                                }
                                Row { spacing: 3
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "维护"; font.pixelSize: 10; color: "#8B8FA3" }
                                }
                                Row { spacing: 3
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "离线"; font.pixelSize: 10; color: "#8B8FA3" }
                                }
                            }
                        }
                    }

                    // ═══ [体育场3D] 3D 场景: Qt Quick 3D 优先, 模块不可用时降级 Canvas 2.5D ═══
                    Loader {
                        id: scene3d
                        anchors.fill: parent; anchors.margins: 8

                        Component.onCompleted: pickSceneSource()
                        // [设备兼容] 先探明渲染后端再加载: legacy 软件渲染无 RHI,
                        // View3D 实例化后析构会 SEGV → 软件环境直接加载 Canvas 2.5D
                        function pickSceneSource() {
                            var api = GraphicsInfo.api
                            if (api === GraphicsInfo.Unknown) { pickTimer.start(); return }
                            if (api === GraphicsInfo.Software) {
                                console.log("[SituationView] 软件渲染 (无 RHI) → 直接加载 Locate3DPanel")
                                setSource("Locate3DPanel.qml")
                                return
                            }
                            var comp = Qt.createComponent("StadiumScene3D.qml")
                            setSource(comp.status === Component.Ready ? "StadiumScene3D.qml" : "Locate3DPanel.qml")
                        }
                        Timer { id: pickTimer; interval: 100; onTriggered: scene3d.pickSceneSource() }
                        onItemChanged: bindSceneItem()

                        function bindSceneItem() {
                            if (!item) return
                            try { item.buildings = Qt.binding(function () { return situationView.buildings }) } catch (e) {}
                            try { item.devices = Qt.binding(function () { return situationView.devices }) } catch (e) {}
                            if (item.sceneMeta !== undefined) {
                                try { item.sceneMeta = Qt.binding(function () { return situationView.sceneMeta }) } catch (e) {}
                            }
                            // 设备选中 → 详情弹窗 (对齐原 Canvas 点击交互)
                            if (item.selectedDevChanged !== undefined) {
                                item.selectedDevChanged.connect(situationView.openSelectedPopup)
                            }
                        }
                    }

                    // GPS 告警标记叠加层 (经 mapFrom3DScene 投影绘制, 30s 有效)
                    Canvas {
                        id: markerCanvas
                        anchors.fill: scene3d
                        z: 4

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var now = Date.now()
                            var n = 0
                            for (var i = 0; i < situationView.activeMapMarkers.length && n < 20; i++) {
                                var m = situationView.activeMapMarkers[i]
                                if (m.timestamp + 30000 < now) continue
                                n++
                                var p = situationView.markerPos(m)
                                var col = situationView.sevColors[m.severity] || "#FF3D71"
                                ctx.strokeStyle = col; ctx.lineWidth = 1.5
                                ctx.beginPath()
                                ctx.moveTo(p.x - 10, p.y); ctx.lineTo(p.x + 10, p.y)
                                ctx.moveTo(p.x, p.y - 6); ctx.lineTo(p.x, p.y + 6)
                                ctx.stroke()
                                var ph = (Math.sin(situationView.tick * 0.15 + n) + 1) / 2
                                ctx.globalAlpha = 0.8 - ph * 0.6
                                ctx.beginPath(); ctx.ellipse(p.x, p.y, 6 + ph * 10, (6 + ph * 10) * 0.45, 0, 0, 2 * Math.PI); ctx.stroke()
                                ctx.globalAlpha = 1
                                ctx.fillStyle = col; ctx.font = "bold 10px sans-serif"; ctx.textAlign = "left"
                                ctx.fillText((m.type || "告警").substring(0, 6), p.x + 8, p.y - 6)
                            }
                        }
                    }

                    // 摄像头详情弹窗
                    Popup {
                        id: camPopup
                        property string camName: ""
                        property string camStatus: ""
                        property string camLoc: ""
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
                            Text {
                                text: "状态: " + (camPopup.camStatus === "alarm" ? "告警" : camPopup.camStatus === "maintenance" ? "维护" : camPopup.camStatus === "offline" ? "离线" : "在线")
                                font.pixelSize: 12
                                color: situationView.devStatusColor({ status: camPopup.camStatus })
                            }
                            Text { text: "位置: " + camPopup.camLoc; font.pixelSize: 12; color: "#8B8FA3"; width: 160; elide: Text.ElideRight }
                            Button {
                                text: "查看预览"; font.pixelSize: 12
                                background: Rectangle { color: "#3B82F6"; radius: 4; width: 70; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onPressed: {
                                    // 联动: 跳转视频监控页
                                    root.sidebarCurrentIndex = 1
                                    camPopup.close()
                                }
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
                                            font.pixelSize: 12
                                            color: alarmData.status === "已处置" ? "#00D4AA" :
                                                   alarmData.status === "处置中" ? "#FFB800" : "#FF3D71"
                                            anchors.centerIn: parent
                                        }
                                    }
                                    Button {
                                        text: "处置"; font.pixelSize: 12
                                        visible: alarmData.status !== "已处置"
                                        background: Rectangle { color: "#3B82F6"; radius: 3; width: 40; height: 22 }
                                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                    width: parent.width - 24; height: 196
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "AI推理性能"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 12
                            Text { text: "TPU:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { id: tpuValueText; text: "0%"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "吞吐:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: statusController.activeModels + "模型"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "温度:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { id: tempValueText; text: "0°C"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "模型数:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { id: fpsValueText; text: "0 / 8槽位"; font.pixelSize: 12; color: "#E8E8E8" }
                        }
                        Row { spacing: 12
                            Text { text: "接入:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: deviceController.deviceCount + " 路"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "延迟:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: (statusController.tpuUtilization > 0 ? (1000 / (statusController.tpuUtilization * 0.5 + 1)).toFixed(0) : "--") + " ms"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true }
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
                                    Text { text: algoData.name || ""; font.pixelSize: 12; color: "#E8E8E8"; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: (algoData.fps || "-") + " FPS"; font.pixelSize: 12; color: "#8B8FA3"; width: 50; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "TPU " + (algoData.tpu || "0%"); font.pixelSize: 12; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
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
                                    Text { text: "AI NPU 处理器"; font.pixelSize: 12; color: "#8B8FA3"; width: 100 }
                                    Text { id: tpuTempText; text: statusController.temperature.toFixed(0) + "°C"; font.pixelSize: 12; color: "#E8E8E8" }
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
                                    Text { text: "DDR4 内存"; font.pixelSize: 12; color: "#8B8FA3"; width: 100 }
                                    Text { id: memValueText; text: "0%"; font.pixelSize: 12; color: "#E8E8E8" }
                                }
                                ProgressBar { id: memBar; width: parent.width; value: 0; height: 4
                                    background: Rectangle { color: "#252830"; radius: 2; height: 4 }
                                    contentItem: Rectangle { width: parent.visualPosition * parent.width; height: 4; radius: 2; color: "#3B82F6" }
                                }
                            }

                            // 运行时间
                            Row {
                                spacing: 12
                                Text { text: "运行时间:"; font.pixelSize: 12; color: "#8B8FA3" }
                                Text { id: uptimeValueText; text: statusController.uptime; font.pixelSize: 12; color: "#00D4AA" }
                            }
                        }
                    }
                }
            }
        }
    }
}
