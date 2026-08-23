// ========================================================================
// Locate3DPanel.qml — 3D 室内定位场景 [R2 任务4] [体育场3D 降级实现]
// 参照 Web 端 Scene3D.vue (three.js) + LocationTrackView.vue (定位/告警标记):
//   Canvas 2.5D 等轴测投影 · 告警脉冲联动 · 点击联动
// [体育场3D] Qt Quick 3D 不可用时的降级渲染, 场景数据改引 StadiumSceneData.js
// (与 scene_config.json 同源, 保证与 StadiumScene3D/Web 端命名/坐标 1:1 一致)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "qrc:///StadiumSceneData.js" as SceneData

Item {
    id: panel

    // ── 对外信号: 与态势/视频页联动 ──
    signal gotoSituation()          // 查看态势感知页
    signal gotoVideoGrid()          // 查看实时预览

    // ── 状态 ──
    property int viewMode: 0                 // 0=等轴测 1=俯视
    property string selectedDev: ""          // 选中设备 id
    property var pulseDevs: ({})             // deviceId -> 脉冲截止时刻(ms)
    property var tick: 0                     // 动画帧

    // ── 视角交互状态 (拖拽旋转 + 滚轮缩放) ──
    property real yaw: 0                     // 水平旋转增量 (弧度, 叠加在基础 45° 上)
    property real pitch: 30                  // 俯仰角 (度, 15~75)
    property real zoom: 1.0                  // 缩放系数 (0.4~4.0)

    function resetView() {
        yaw = 0; pitch = 30; zoom = 1.0
        scene.requestPaint()
    }

    // ═══ 场景数据 (体育场, 与 scene_config.json 同源; 可被外部绑定覆盖) ═══
    property var buildings: SceneData.BUILDINGS
    
    property var devices: {
        // 拷贝一份, 避免告警联动 status 修改污染共享常量
        var out = []
        for (var i = 0; i < SceneData.DEMO_DEVICES.length; i++) {
            var src = SceneData.DEMO_DEVICES[i], c = {}
            for (var k in src) c[k] = src[k]
            out.push(c)
        }
        return out
    }

    // 告警级别色 (对齐 LocationTrackView alarm-map-marker)
    readonly property var sevColors: ["#8B8FA3", "#3B82F6", "#3B82F6", "#FFB800", "#FF6B35", "#FF3D71"]

    function devStatusColor(d) {
        return d.status === "alarm" ? "#FF3D71" : d.status === "maintenance" ? "#F59E0B"
             : d.status === "offline" ? "#6B7280" : "#10B981"
    }

    // ═══ 告警联动: 告警列表 location 模糊匹配设备 → 30s 脉冲 ═══
    function refreshPulse() {
        var alarms = alarmController.alarms
        var now = Date.now()
        for (var i = 0; i < alarms.length; i++) {
            var loc = alarms[i].location || alarms[i].channel_id || ""
            var lvl = alarms[i].level
            for (var j = 0; j < devices.length; j++) {
                var d = devices[j]
                if (loc && (loc.indexOf(d.location) >= 0 || loc.indexOf(d.name) >= 0)) {
                    var obj = pulseDevs
                    obj[d.id] = { until: now + 30000, sev: lvl === "critical" ? 5 : lvl === "warning" ? 4 : 3 }
                    pulseDevs = obj
                    d.status = "alarm"
                }
            }
        }
        scene.requestPaint()
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() { panel.refreshPulse() }
    }

    // WebSocket 实时定位推送 (alarm-map-marker)
    Connections {
        target: (typeof wsRouter !== "undefined") ? wsRouter : null
        function onMapMarkerReceived(payload) {
            if (!payload) return
            var now = Date.now()
            var obj = pulseDevs
            var sev = payload.severity || 3
            if (payload.device_id && obj[payload.device_id] !== undefined) {
                obj[payload.device_id] = { until: now + 30000, sev: sev }
            } else {
                // 未匹配设备: 挂到北看台 cam5 作为场景级告警指示
                // [v1.9.5] 原 demo-cam4(配套楼顶) 属场外点位已删, 改挂馆内北看台
                obj["demo-cam5"] = { until: now + 30000, sev: sev }
            }
            pulseDevs = obj
            scene.requestPaint()
        }
    }

    // ═══ 投影: 等轴测 / 俯视 (支持 yaw 旋转 + pitch 俯仰 + zoom 缩放) ═══
    // 世界坐标先绕垂直轴旋转 (π/4 + yaw), 再按 pitch 做轴测压缩;
    // yaw=0 & pitch=30 时与原固定等轴测公式完全一致.
    function rotU(x, z) {
        var ang = Math.PI / 4 + panel.yaw
        return (x * Math.cos(ang) - z * Math.sin(ang)) * 1.41421356
    }
    function rotV(x, z) {
        var ang = Math.PI / 4 + panel.yaw
        return (x * Math.sin(ang) + z * Math.cos(ang)) * 1.41421356
    }

    function iso(x, h, z) {
        var cx = scene.width / 2, cy = scene.height * 0.46
        var s = scene.scaleFactor * panel.zoom
        var u = rotU(x, z), v = rotV(x, z)
        if (viewMode === 1) return { x: cx + u * s, y: cy + v * s }
        var p = panel.pitch * Math.PI / 180
        return { x: cx + u * Math.cos(p) * s, y: cy + v * Math.sin(p) * s - h * s * 0.9 }
    }

    function shade(hex, f) {
        var c = hex.replace("#", "")
        var r = Math.round(parseInt(c.substring(0, 2), 16) * f)
        var g = Math.round(parseInt(c.substring(2, 4), 16) * f)
        var b = Math.round(parseInt(c.substring(4, 6), 16) * f)
        return "rgb(" + Math.min(255, r) + "," + Math.min(255, g) + "," + Math.min(255, b) + ")"
    }

    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: "#0D0F12"; radius: 8
        border.color: "#252830"; border.width: 1

        Canvas {
            id: scene
            anchors.fill: parent
            anchors.margins: 4

            // 等轴测 x 跨度 ≈ (60+50)*0.866*2 ≈ 190 世界单位
            readonly property real scaleFactor: Math.min(width / 205, height / 128)

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                // ── 地面 ──
                var gTop = iso(-60, 0, -50), gBot = iso(60, 0, 50)
                var grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, "#0E1B2E"); grad.addColorStop(1, "#0B1220")
                ctx.fillStyle = grad
                ctx.fillRect(0, 0, width, height)

                // 网格 (间隔10, 对齐 Scene3D GridHelper 120x100)
                ctx.strokeStyle = "rgba(59,130,246,0.12)"; ctx.lineWidth = 1
                for (var gx = -60; gx <= 60; gx += 10) {
                    var a = iso(gx, 0, -50), b = iso(gx, 0, 50)
                    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke()
                }
                for (var gz = -50; gz <= 50; gz += 10) {
                    var c = iso(-60, 0, gz), d = iso(60, 0, gz)
                    ctx.beginPath(); ctx.moveTo(c.x, c.y); ctx.lineTo(d.x, d.y); ctx.stroke()
                }

                // 围墙 (±55 / ±48, 高3, 对齐 Scene3D createWall)
                ctx.strokeStyle = "rgba(26,32,64,0.9)"; ctx.lineWidth = 2
                var walls = [ [-55, -48, -55, 48], [55, -48, 55, 48], [-55, -48, 55, -48], [-55, 48, 55, 48] ]
                for (var w = 0; w < walls.length; w++) {
                    var wt = iso(walls[w][0], 3, walls[w][1]), wb = iso(walls[w][2], 3, walls[w][3])
                    var wtb = iso(walls[w][0], 0, walls[w][1]), wbb = iso(walls[w][2], 0, walls[w][3])
                    ctx.beginPath()
                    ctx.moveTo(wtb.x, wtb.y); ctx.lineTo(wt.x, wt.y); ctx.lineTo(wb.x, wb.y); ctx.lineTo(wbb.x, wbb.y)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(26,32,64,0.35)"; ctx.fill(); ctx.stroke()
                }

                // ── 实体统一按深度排序 (远→近) ──
                var entities = []
                for (var i = 0; i < panel.buildings.length; i++) {
                    var b = panel.buildings[i]
                    if (!b || b.shape === "anchor") continue   // anchor 不可见
                    entities.push({ kind: "b", obj: b, depth: panel.rotU(b.x, b.z) + panel.rotV(b.x, b.z) })
                }
                var now = Date.now()
                var pulseCount = 0
                for (var k = 0; k < panel.devices.length; k++) {
                    var dv = panel.devices[k]
                    entities.push({ kind: "d", obj: dv, depth: panel.rotU(dv.x, dv.z) + panel.rotV(dv.x, dv.z) })
                    if (panel.pulseDevs[dv.id] && panel.pulseDevs[dv.id].until > now) pulseCount++
                }
                entities.sort(function (p, q) { return p.depth - q.depth })

                for (var e = 0; e < entities.length; e++) {
                    var ent = entities[e]
                    if (ent.kind === "b") drawBuilding(ctx, ent.obj)
                    else drawDevice(ctx, ent.obj, now)
                }

                // ── 图内角标: 视角/图例在工具栏, 此处画指北针 ──
                ctx.fillStyle = "#3B82F6"; ctx.font = "bold 13px sans-serif"; ctx.textAlign = "center"
                var np = iso(0, 0, -62)
                ctx.fillText("N", np.x, np.y)
                ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 1.5
                ctx.beginPath(); ctx.moveTo(np.x, np.y + 4); ctx.lineTo(np.x, np.y + 16); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(np.x - 4, np.y + 12); ctx.lineTo(np.x, np.y + 18); ctx.lineTo(np.x + 4, np.y + 12); ctx.stroke()
            }

            function drawBuilding(ctx, b) {
                // 体育场形状字段兼容: w/d 缺失时用 rx/rz 椭圆半径折算
                var bw = b.w !== undefined ? b.w : ((b.rx !== undefined ? b.rx * 2 : 8))
                var bd = b.d !== undefined ? b.d : ((b.rz !== undefined ? b.rz * 2 : 8))
                var x0 = b.x - bw / 2, x1 = b.x + bw / 2
                var z0 = b.z - bd / 2, z1 = b.z + bd / 2
                var h = b.h !== undefined ? b.h : 4
                // 俯视: 四顶点多边形 (旋转后 u/v 非单调, 不能用 rect)
                if (panel.viewMode === 1) {
                    var p00 = iso(x0, 0, z0), p10 = iso(x1, 0, z0), p11 = iso(x1, 0, z1), p01 = iso(x0, 0, z1)
                    ctx.fillStyle = panel.shade(b.color, 0.35); ctx.strokeStyle = b.color; ctx.lineWidth = 1.5
                    ctx.beginPath(); ctx.moveTo(p00.x, p00.y); ctx.lineTo(p10.x, p10.y); ctx.lineTo(p11.x, p11.y); ctx.lineTo(p01.x, p01.y); ctx.closePath(); ctx.fill(); ctx.stroke()
                    ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                    ctx.fillText(b.name, (p00.x + p11.x) / 2, (p00.y + p11.y) / 2 + 4)
                    return
                }
                // 等轴测: 顶面 + 4 个侧面 (按相机朝向只画可见的那几个)
                var tA = iso(x0, h, z0), tB = iso(x1, h, z0), tC = iso(x1, h, z1), tD = iso(x0, h, z1)
                var bA = iso(x0, 0, z0), bB = iso(x1, 0, z0), bC = iso(x1, 0, z1), bD = iso(x0, 0, z1)
                // 计算相机方向的水平投影角: 以 yaw 为 0 时 +x 方向为正面)
                // rotU(1,0) = cos(a), rotV(1,0) = sin(a), a = π/4 + yaw
                // 朝相机那一面的法线点积 > 0 才画 (visible)
                var a = Math.PI / 4 + panel.yaw
                // 每个面的世界水平法线
                // [FIX v7.3] 调整 shade 让背面也有合理亮度, 避免 yaw=π 时 2 面太黑看起来像空的
                //   原 shade (right=0.30, front=0.22, left=0.16, back=0.12) 在背视时仅 left+back 可见 (0.16/0.12)
                //   对 #1A73E8/0.12 → rgb(3,14,28) 几乎纯黑, 用户报告"2 面为空"
                //   新值: 提升 left/back 底亮度, 维持右前亮、后偏暗的视觉层次
                var faces = [
                    // +x (右): 法线 (cos a, sin a); visible = cos a*nx + sin a*nz > 0
                    { name: "right", nx: Math.cos(a),     nz: Math.sin(a),     shade: 0.35,
                      corners: [tB, tC, bC, bB] },
                    // -x (左): 法线 (-cos a, -sin a)
                    { name: "left",  nx: -Math.cos(a),    nz: -Math.sin(a),    shade: 0.28,
                      corners: [tD, tA, bA, bD] },
                    // +z (前): 法线 (-sin a, cos a)
                    { name: "front", nx: -Math.sin(a),    nz: Math.cos(a),     shade: 0.30,
                      corners: [tC, tD, bD, bC] },
                    // -z (后): 法线 (sin a, -cos a)
                    { name: "back",  nx: Math.sin(a),     nz: -Math.cos(a),    shade: 0.22,
                      corners: [tA, tB, bB, bA] }
                ]
                for (var fi = 0; fi < faces.length; fi++) {
                    var f = faces[fi]
                    // [FIX v7.5] 放宽可见性判断: 原 dot > 0 太严格
                    //   yaw=0 时 right=1, front=0, back=0, left=-1 → 只有 right 被画 (1 面),
                    //   旋转 45° 时类似, 导致"旋转到对面有 2 面的面板显示为空"
                    //   Web 端 Scene3D.vue 使用 THREE.DoubleSide (全画 4 个面) + MeshBasicMaterial 自动管理深度
                    //   Canvas2D 没有 z-buffer, 采用"画所有偏正/偏侧的面"策略: dot >= -0.5
                    //     - dot > 0 → 正面偏亮 (shade 0.28~0.35)
                    //     - -0.5 ≤ dot ≤ 0 → 侧面偏暗 (shade 0.22) 保留视觉层次
                    //     - dot < -0.5 → 完全不可见 (省绘制)
                    //   任意 yaw 下都能看到 2~3 个面, 与 Web 端 DoubleSide 表现一致
                    var dot = f.nx * Math.cos(a) + f.nz * Math.sin(a)
                    if (dot < -0.5) continue
                    var cs = f.corners
                    ctx.beginPath()
                    ctx.moveTo(cs[0].x, cs[0].y)
                    ctx.lineTo(cs[1].x, cs[1].y)
                    ctx.lineTo(cs[2].x, cs[2].y)
                    ctx.lineTo(cs[3].x, cs[3].y)
                    ctx.closePath()
                    // dot > 0 用原 shade, dot ≤ 0 强制用 back 的暗色 (0.22)
                    var s = dot > 0 ? f.shade : 0.22
                    ctx.fillStyle = panel.shade(b.color, s)
                    ctx.fill()
                    ctx.strokeStyle = panel.shade(b.color, dot > 0 ? 0.55 : 0.30)
                    ctx.lineWidth = 0.8
                    ctx.stroke()
                }
                // 顶面
                ctx.beginPath(); ctx.moveTo(tA.x, tA.y); ctx.lineTo(tB.x, tB.y); ctx.lineTo(tC.x, tC.y); ctx.lineTo(tD.x, tD.y); ctx.closePath()
                ctx.fillStyle = panel.shade(b.color, 0.62); ctx.fill()
                ctx.strokeStyle = panel.shade(b.color, 0.95); ctx.lineWidth = 1; ctx.stroke()
                // 名称
                ctx.fillStyle = "#C9D4E5"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                var mid = iso(b.x, h, b.z)
                ctx.fillText(b.name, mid.x, mid.y - 4)
                // 底座环 (对齐 Scene3D RingGeometry, 椭圆扁率随 pitch 变化)
                ctx.strokeStyle = "rgba(59,130,246,0.35)"; ctx.lineWidth = 1
                var ringRx = bw * scene.scaleFactor * panel.zoom * 0.72
                ctx.beginPath(); ctx.ellipse(mid.x, iso(b.x, 0, b.z).y, ringRx, ringRx * Math.sin(panel.pitch * Math.PI / 180) / Math.cos(panel.pitch * Math.PI / 180), 0, 0, 2 * Math.PI)
                ctx.stroke()
            }

            function drawDevice(ctx, d, now) {
                var p = iso(d.x, 0, d.z)
                var top = iso(d.x, d.y || 4, d.z)
                var col = panel.devStatusColor(d)
                var pulse = panel.pulseDevs[d.id]
                var pulsing = pulse && pulse.until > now
                var selected = panel.selectedDev === d.id

                // 告警扩散环
                if (pulsing) {
                    var ph = (Math.sin(panel.tick * 0.18) + 1) / 2
                    var rr = 8 + ph * 16
                    ctx.strokeStyle = panel.sevColors[pulse.sev] || "#FF3D71"
                    ctx.globalAlpha = 0.9 - ph * 0.7
                    ctx.lineWidth = 2
                    ctx.beginPath(); ctx.ellipse(p.x, p.y, rr, rr * 0.45, 0, 0, 2 * Math.PI); ctx.stroke()
                    ctx.globalAlpha = 1
                }

                // 定位圈
                ctx.fillStyle = col; ctx.globalAlpha = 0.22
                ctx.beginPath(); ctx.ellipse(p.x, p.y, 9, 4.5, 0, 0, 2 * Math.PI); ctx.fill()
                ctx.globalAlpha = 1
                ctx.strokeStyle = col; ctx.lineWidth = 1.4
                ctx.beginPath(); ctx.ellipse(p.x, p.y, 9, 4.5, 0, 0, 2 * Math.PI); ctx.stroke()

                // 选中高亮
                if (selected) {
                    ctx.strokeStyle = "#FFFFFF"; ctx.lineWidth = 1.5
                    ctx.setLineDash([4, 3])
                    ctx.beginPath(); ctx.ellipse(p.x, p.y, 14, 7, 0, 0, 2 * Math.PI); ctx.stroke()
                    ctx.setLineDash([])
                }

                // 立杆 + 顶点
                if (panel.viewMode === 0) {
                    ctx.strokeStyle = panel.shade("#8B8FA3", 0.8); ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(top.x, top.y); ctx.stroke()
                }
                ctx.fillStyle = col
                ctx.beginPath(); ctx.arc(top.x, top.y, 3.2, 0, 2 * Math.PI); ctx.fill()
                if (pulsing) {
                    ctx.fillStyle = panel.sevColors[pulse.sev] || "#FF3D71"
                    ctx.beginPath(); ctx.arc(top.x, top.y, 1.8 + (Math.sin(panel.tick * 0.25) + 1) * 1.2, 0, 2 * Math.PI); ctx.fill()
                }

                // 标签 (选中或告警时加亮)
                ctx.fillStyle = selected ? "#FFFFFF" : (pulsing ? "#FF6B35" : "#8B8FA3")
                ctx.font = selected ? "bold 11px sans-serif" : "10px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(d.name, top.x, top.y - 8)
            }
        }

        // ── 交互: 拖拽旋转视角 / 滚轮缩放 / 点击选中设备 ──
        MouseArea {
            id: sceneMa
            anchors.fill: scene
            acceptedButtons: Qt.LeftButton
            property real lastX: 0
            property real lastY: 0
            property bool moved: false

            onPressed: function (mouse) {
                lastX = mouse.x; lastY = mouse.y; moved = false
            }
            onPositionChanged: function (mouse) {
                if (!sceneMa.pressed) return
                var dx = mouse.x - lastX, dy = mouse.y - lastY
                if (Math.abs(dx) + Math.abs(dy) > 3) moved = true
                panel.yaw += dx * 0.008
                panel.pitch = Math.max(15, Math.min(75, panel.pitch - dy * 0.25))
                lastX = mouse.x; lastY = mouse.y
                scene.requestPaint()
            }
            onWheel: function (wheel) {
                var f = wheel.angleDelta.y > 0 ? 1.12 : (1 / 1.12)
                panel.zoom = Math.max(0.4, Math.min(4.0, panel.zoom * f))
                scene.requestPaint()
            }
            onClicked: function (mouse) {
                if (moved) return   // 拖拽结束不触发选中
                var best = "", bestDist = 20
                for (var i = 0; i < panel.devices.length; i++) {
                    var d = panel.devices[i]
                    var p = panel.iso(d.x, d.y || 4, d.z)
                    var dist = Math.sqrt(Math.pow(mouse.x - p.x, 2) + Math.pow(mouse.y - p.y, 2))
                    if (dist < bestDist) { bestDist = dist; best = d.id }
                }
                panel.selectedDev = best
                scene.requestPaint()
            }
        }

        // ═══ 工具栏 (左上悬浮) ═══
        Rectangle {
            z: 5
            anchors.top: parent.top; anchors.left: parent.left
            anchors.margins: 10
            width: toolRow.width + 20; height: 34
            color: "#141720"; radius: 6; border.color: "#252830"; border.width: 1

            Row {
                id: toolRow
                anchors.centerIn: parent; spacing: 12

                Button { text: "等轴测"; width: 52; height: 24
                    background: Rectangle { color: panel.viewMode === 0 ? "#3B82F6" : "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: panel.viewMode === 0 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { panel.viewMode = 0; scene.requestPaint() }
                }
                Button { text: "俯视"; width: 44; height: 24
                    background: Rectangle { color: panel.viewMode === 1 ? "#3B82F6" : "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: panel.viewMode === 1 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { panel.viewMode = 1; scene.requestPaint() }
                }
                Button { text: "复位"; width: 44; height: 24
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: panel.resetView()
                }

                Rectangle { width: 1; height: 18; color: "#252830"; anchors.verticalCenter: parent.verticalCenter }

                // 图例 (对齐 Scene3D 图例栏)
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "在线"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "告警"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "维保"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "离线"; font.pixelSize: 10; color: "#8B8FA3" }
                }

                Text { text: "设备 " + panel.devices.length; font.pixelSize: 10; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "拖拽旋转 · 滚轮缩放"; font.pixelSize: 10; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ═══ 设备信息卡 (右上悬浮) ═══
        Rectangle {
            id: devInfo
            z: 5
            visible: panel.selectedDev !== ""
            anchors.top: parent.top; anchors.right: parent.right
            anchors.margins: 10
            width: 230; height: infoCol.height + 24
            color: "#141720"; radius: 8; border.color: "#3B82F6"; border.width: 1

            property var dev: {
                for (var i = 0; i < panel.devices.length; i++)
                    if (panel.devices[i].id === panel.selectedDev) return panel.devices[i]
                return null
            }

            Column {
                id: infoCol
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 12; spacing: 6

                Row { width: parent.width; spacing: 6
                    Rectangle { width: 8; height: 8; radius: 4; color: devInfo.dev ? panel.devStatusColor(devInfo.dev) : "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: devInfo.dev ? devInfo.dev.name : ""; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Item { width: 4 }
                    Text { text: devInfo.dev ? (devInfo.dev.status === "online" ? "在线" : devInfo.dev.status === "alarm" ? "告警中" : devInfo.dev.status === "maintenance" ? "维保中" : "离线") : ""
                        font.pixelSize: 11; color: devInfo.dev ? panel.devStatusColor(devInfo.dev) : "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    Item { Layout.fillWidth: true }
                    Button { text: "X"; width: 22; height: 22
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.selectedDev = ""
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#252830" }

                Grid { columns: 2; columnSpacing: 10; rowSpacing: 4; width: parent.width
                    Text { text: "设备ID:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? devInfo.dev.id : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "安装位置:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? devInfo.dev.location : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "坐标:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? ("(" + devInfo.dev.x + ", " + devInfo.dev.z + ")") : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "当前告警:"; font.pixelSize: 11; color: "#8B8FA3"; visible: devInfo.dev && devInfo.dev.status === "alarm" }
                    Text { text: devInfo.dev && devInfo.dev.alarmType ? devInfo.dev.alarmType : ""; font.pixelSize: 11; color: "#FF6B35"; visible: devInfo.dev && devInfo.dev.status === "alarm" }
                }

                Row { spacing: 8; layoutDirection: Qt.RightToLeft; width: parent.width
                    Button { text: "查看态势"; width: 74; height: 26
                        background: Rectangle { color: "#3B82F6"; radius: 4 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.gotoSituation()
                    }
                    Button { text: "实时预览"; width: 74; height: 26
                        background: Rectangle { color: "#252830"; radius: 4; border.color: "#3B82F6"; border.width: 1 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.gotoVideoGrid()
                    }
                }
            }
        }
    }

    // ── 脉冲动画驱动 (面板可见且有脉冲时) ──
    Timer {
        interval: 100; repeat: true; running: panel.visible
        onTriggered: {
            panel.tick++
            var now = Date.now(), any = false
            for (var k in panel.pulseDevs) { if (panel.pulseDevs[k].until > now) { any = true; break } }
            if (any || panel.selectedDev !== "") scene.requestPaint()
        }
    }

    Component.onCompleted: refreshPulse()
}
