// ========================================================================
// AppIcon.qml — 专业矢量图标组件 (对标海康HikCentral线性图标规范)
// 使用 QtQuick.Canvas 绘制，无 emoji 依赖，三平台渲染一致
// 支持三档尺寸(16/20/24px) + 三种状态色(默认/选中/告警)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Canvas {
    id: icon
    width: size
    height: size

    // ── 属性 ──
    property string name: "dashboard"       // 图标名称
    property int size: 20                    // 像素尺寸 16/20/24
    property color iconColor: "#8B8FA3"      // 默认色
    property color activeColor: "#00D4AA"    // 选中色
    property color alarmColor: "#FF3D71"     // 告警色
    property bool active: false              // 是否选中
    property real strokeWidth: size >= 24 ? 2.0 : (size >= 20 ? 1.6 : 1.3)

    // 当前颜色
    readonly property color currentColor: active ? activeColor : iconColor

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = currentColor
        ctx.fillStyle = currentColor
        ctx.lineWidth = strokeWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        var s = size
        var p = s * 0.15  // padding

        // ── 按名称绘制对应图标 ──
        switch (name) {
            case "dashboard":       drawDashboard(ctx, s, p); break
            case "camera":          drawCamera(ctx, s, p); break
            case "alarm":           drawAlarm(ctx, s, p); break
            case "algorithm":       drawAlgorithm(ctx, s, p); break
            case "pipeline":        drawPipeline(ctx, s, p); break
            case "gb28181":         drawGb28181(ctx, s, p); break
            case "onvif":           drawOnvif(ctx, s, p); break
            case "record":          drawRecord(ctx, s, p); break
            case "situation":       drawSituation(ctx, s, p); break
            case "ai":              drawAI(ctx, s, p); break
            case "statistics":      drawStatistics(ctx, s, p); break
            case "device":          drawDevice(ctx, s, p); break
            case "channel":         drawChannel(ctx, s, p); break
            case "stream":          drawStream(ctx, s, p); break
            case "model":           drawModel(ctx, s, p); break
            case "federation":      drawFederation(ctx, s, p); break
            case "linkage":         drawLinkage(ctx, s, p); break
            case "settings":        drawSettings(ctx, s, p); break
            case "search":          drawSearch(ctx, s, p); break
            case "refresh":         drawRefresh(ctx, s, p); break
            case "export":          drawExport(ctx, s, p); break
            case "expand":          drawExpand(ctx, s, p); break
            case "collapse":        drawCollapse(ctx, s, p); break
            case "shield":          drawShield(ctx, s, p); break
            case "close":           drawClose(ctx, s, p); break
            case "play":            drawPlay(ctx, s, p); break
            case "stop":            drawStop(ctx, s, p); break
            case "snapshot":        drawSnapshot(ctx, s, p); break
            case "delete":          drawDelete(ctx, s, p); break
            case "edit":            drawEdit(ctx, s, p); break
            case "add":             drawAdd(ctx, s, p); break
            case "check":           drawCheck(ctx, s, p); break
            case "warning":         drawWarning(ctx, s, p); break
            case "info":            drawInfo(ctx, s, p); break
            case "user":            drawUser(ctx, s, p); break
            case "lock":            drawLock(ctx, s, p); break
            case "map":             drawMap(ctx, s, p); break
            case "heatmap":         drawHeatmap(ctx, s, p); break
            case "trajectory":      drawTrajectory(ctx, s, p); break
            case "image":           drawImage(ctx, s, p); break
            case "folder":          drawFolder(ctx, s, p); break
            case "download":        drawDownload(ctx, s, p); break
            case "upload":          drawUpload(ctx, s, p); break
            case "clock":           drawClock(ctx, s, p); break
            case "calendar":        drawCalendar(ctx, s, p); break
            case "filter":          drawFilter(ctx, s, p); break
            case "sort":            drawSort(ctx, s, p); break
            case "more":            drawMore(ctx, s, p); break
            case "chevronLeft":     drawChevronLeft(ctx, s, p); break
            case "chevronRight":    drawChevronRight(ctx, s, p); break
            case "chevronDown":     drawChevronDown(ctx, s, p); break
            case "menu":            drawMenu(ctx, s, p); break
            case "bell":            drawBell(ctx, s, p); break
            case "eye":             drawEye(ctx, s, p); break
            case "brain":           drawBrain(ctx, s, p); break
            case "tool":            drawTool(ctx, s, p); break
            case "send":            drawSend(ctx, s, p); break
            case "audit":           drawAudit(ctx, s, p); break
            default:                drawDashboard(ctx, s, p); break
        }
    }

    onActiveChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onNameChanged: requestPaint()

    // ═══════════════════════════════════════════════════════════════
    //  图标绘制函数库
    // ═══════════════════════════════════════════════════════════════

    // 仪表盘 — 四象限方格
    function drawDashboard(ctx, s, p) {
        var cw = (s - 2*p) / 2 - 1
        var ch = (s - 2*p) / 2 - 1
        ctx.strokeRect(p, p, cw, ch)
        ctx.strokeRect(p + cw + 2, p, cw, ch)
        ctx.strokeRect(p, p + ch + 2, cw, ch)
        ctx.strokeRect(p + cw + 2, p + ch + 2, cw, ch)
    }

    // 摄像机 — 经典监控摄像头造型
    function drawCamera(ctx, s, p) {
        var w = s - 2*p, h = s * 0.5
        var x = p, y = (s - h) / 2
        // 机身
        ctx.strokeRect(x, y, w, h)
        // 镜头
        ctx.beginPath()
        ctx.arc(x + w * 0.3, y + h/2, h * 0.18, 0, 2*Math.PI)
        ctx.stroke()
        // 指示灯
        ctx.beginPath()
        ctx.arc(x + w * 0.75, y + h * 0.3, 1.5, 0, 2*Math.PI)
        ctx.fill()
        // 支架
        ctx.beginPath()
        ctx.moveTo(s/2, y + h)
        ctx.lineTo(s/2, y + h + p)
        ctx.stroke()
    }

    // 告警 — 三角形感叹号
    function drawAlarm(ctx, s, p) {
        var w = s - 2*p
        // 三角形
        ctx.beginPath()
        ctx.moveTo(s/2, p)
        ctx.lineTo(s - p, s - p)
        ctx.lineTo(p, s - p)
        ctx.closePath()
        ctx.stroke()
        // 感叹号线
        ctx.beginPath()
        ctx.moveTo(s/2, s * 0.4)
        ctx.lineTo(s/2, s * 0.6)
        ctx.stroke()
        // 感叹号点
        ctx.beginPath()
        ctx.arc(s/2, s * 0.72, 1, 0, 2*Math.PI)
        ctx.fill()
    }

    // 算法 — 拼图块
    function drawAlgorithm(ctx, s, p) {
        var w = s - 2*p - 4
        // 主体方块
        ctx.strokeRect(p + 2, p + 2, w, w)
        // 凹凸拼图齿
        ctx.beginPath()
        ctx.arc(s/2, p + 2, 2.5, 0, Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(s/2, s - p - 2, 2.5, Math.PI, 2*Math.PI)
        ctx.stroke()
    }

    // 流水线 — 节点连线
    function drawPipeline(ctx, s, p) {
        // 左节点
        ctx.beginPath()
        ctx.arc(p + 3, s/2, 3, 0, 2*Math.PI)
        ctx.stroke()
        // 右节点
        ctx.beginPath()
        ctx.arc(s - p - 3, s/2, 3, 0, 2*Math.PI)
        ctx.stroke()
        // 中节点
        ctx.beginPath()
        ctx.arc(s/2, s/2, 3, 0, 2*Math.PI)
        ctx.stroke()
        // 连线
        ctx.beginPath()
        ctx.moveTo(p + 6, s/2)
        ctx.lineTo(s/2 - 3, s/2)
        ctx.moveTo(s/2 + 3, s/2)
        ctx.lineTo(s - p - 6, s/2)
        ctx.stroke()
    }

    // GB28181 — 信号塔
    function drawGb28181(ctx, s, p) {
        var cx = s/2
        // 塔
        ctx.beginPath()
        ctx.moveTo(cx - 2, s - p)
        ctx.lineTo(cx, p + 2)
        ctx.lineTo(cx + 2, s - p)
        ctx.stroke()
        // 信号弧
        ctx.beginPath()
        ctx.arc(cx, p + 2, s * 0.2, -Math.PI * 0.6, -Math.PI * 0.4)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(cx, p + 2, s * 0.35, -Math.PI * 0.6, -Math.PI * 0.4)
        ctx.stroke()
    }

    // ONVIF — 网络/插头
    function drawOnvif(ctx, s, p) {
        var w = s - 2*p, h = s * 0.4
        var x = p, y = (s - h) / 2
        // 插头主体
        ctx.strokeRect(x, y, w, h)
        // 引脚
        ctx.beginPath()
        ctx.moveTo(x + w * 0.25, y + h)
        ctx.lineTo(x + w * 0.25, s - p)
        ctx.moveTo(x + w * 0.5, y + h)
        ctx.lineTo(x + w * 0.5, s - p)
        ctx.moveTo(x + w * 0.75, y + h)
        ctx.lineTo(x + w * 0.75, s - p)
        ctx.stroke()
    }

    // 录像 — 圆点+胶片
    function drawRecord(ctx, s, p) {
        var w = s - 2*p, h = s * 0.4
        var y = (s - h) / 2
        // 胶片框
        ctx.strokeRect(p, y, w, h)
        // 齿孔
        for (var i = 0; i < 3; i++) {
            ctx.beginPath()
            ctx.arc(p + w * (0.25 + i * 0.25), y, 1, 0, 2*Math.PI)
            ctx.fill()
            ctx.beginPath()
            ctx.arc(p + w * (0.25 + i * 0.25), y + h, 1, 0, 2*Math.PI)
            ctx.fill()
        }
    }

    // 态势 — 盾牌+雷达
    function drawSituation(ctx, s, p) {
        var cx = s/2, r = s * 0.3
        // 外圆
        ctx.beginPath()
        ctx.arc(cx, cx, r, 0, 2*Math.PI)
        ctx.stroke()
        // 十字线
        ctx.beginPath()
        ctx.moveTo(cx - r, cx); ctx.lineTo(cx + r, cx)
        ctx.moveTo(cx, cx - r); ctx.lineTo(cx, cx + r)
        ctx.stroke()
        // 扫描扇形
        ctx.beginPath()
        ctx.moveTo(cx, cx)
        ctx.arc(cx, cx, r * 0.6, -Math.PI/2, 0)
        ctx.lineTo(cx, cx)
        ctx.fill()
    }

    // AI — 大脑/芯片
    function drawAI(ctx, s, p) {
        var w = s - 2*p - 4
        // 芯片主体
        ctx.strokeRect(p + 2, p + 2, w, w)
        // 内部连线
        ctx.beginPath()
        ctx.moveTo(s * 0.35, p + 2); ctx.lineTo(s * 0.35, s * 0.65)
        ctx.moveTo(s * 0.65, p + 2); ctx.lineTo(s * 0.65, s * 0.65)
        ctx.lineTo(s * 0.35, s * 0.65)
        ctx.stroke()
        // 引脚
        var pins = [0.3, 0.5, 0.7]
        for (var i = 0; i < 3; i++) {
            ctx.beginPath()
            ctx.moveTo(p + 2 + w * pins[i], p + 2)
            ctx.lineTo(p + 2 + w * pins[i], p)
            ctx.moveTo(p + 2 + w * pins[i], s - p - 2)
            ctx.lineTo(p + 2 + w * pins[i], s - p)
            ctx.stroke()
        }
    }

    // 统计 — 柱状图
    function drawStatistics(ctx, s, p) {
        var baseY = s - p
        var bw = (s - 2*p - 6) / 3
        // 三根柱
        ctx.strokeRect(p, baseY - s*0.3, bw, s*0.3)
        ctx.strokeRect(p + bw + 3, baseY - s*0.5, bw, s*0.5)
        ctx.strokeRect(p + (bw + 3) * 2, baseY - s*0.2, bw, s*0.2)
        // 底线
        ctx.beginPath()
        ctx.moveTo(p, baseY)
        ctx.lineTo(s - p, baseY)
        ctx.stroke()
    }

    // 设备 — 服务器/路由器
    function drawDevice(ctx, s, p) {
        var w = s - 2*p, h = s * 0.28
        // 上层
        ctx.strokeRect(p, p + 1, w, h)
        // 下层
        ctx.strokeRect(p, p + h + 4, w, h)
        // LED
        ctx.beginPath()
        ctx.arc(p + w * 0.2, p + h * 0.5, 1.2, 0, 2*Math.PI)
        ctx.arc(p + w * 0.8, p + h * 0.5, 1.2, 0, 2*Math.PI)
        ctx.arc(p + w * 0.2, p + h + 4 + h * 0.5, 1.2, 0, 2*Math.PI)
        ctx.arc(p + w * 0.8, p + h + 4 + h * 0.5, 1.2, 0, 2*Math.PI)
        ctx.fill()
    }

    // 通道 — 层叠矩形
    function drawChannel(ctx, s, p) {
        var w = s * 0.55, h = s * 0.2
        ctx.strokeRect((s - w)/2, p + 2, w, h)
        ctx.strokeRect((s - w)/2, s/2 - h/2, w, h)
        ctx.strokeRect((s - w)/2, s - p - h - 2, w, h)
    }

    // 流 — 波浪线
    function drawStream(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p, s * 0.35)
        ctx.bezierCurveTo(s*0.3, s*0.15, s*0.3, s*0.55, s/2, s*0.35)
        ctx.bezierCurveTo(s*0.7, s*0.15, s*0.7, s*0.55, s - p, s*0.35)
        ctx.moveTo(p, s * 0.65)
        ctx.bezierCurveTo(s*0.3, s*0.45, s*0.3, s*0.85, s/2, s*0.65)
        ctx.bezierCurveTo(s*0.7, s*0.45, s*0.7, s*0.85, s - p, s*0.65)
        ctx.stroke()
    }

    // 模型 — 立方体
    function drawModel(ctx, s, p) {
        var w = s - 2*p - 2
        var cx = s/2
        // 三维立方体
        ctx.strokeRect(p + 1, p + 2, w, w)
        ctx.beginPath()
        ctx.moveTo(p + 1, p + 2)
        ctx.lineTo(cx - w*0.15, p)
        ctx.lineTo(s - p - 1, p)
        ctx.lineTo(s - p - 1, p + w + 2)
        ctx.lineTo(cx + w*0.15, cx + w*0.15 + 2)
        ctx.moveTo(s - p - 1, p)
        ctx.lineTo(s - p - 1 - w*0.15 - 1, p)
        ctx.stroke()
    }

    // 联邦 — 地球/网络
    function drawFederation(ctx, s, p) {
        var cx = s/2, r = s * 0.32
        // 外圆
        ctx.beginPath()
        ctx.arc(cx, cx, r, 0, 2*Math.PI)
        ctx.stroke()
        // 经线
        ctx.beginPath()
        ctx.ellipse(cx, cx, r * 0.4, r, 0, 0, 2*Math.PI)
        ctx.stroke()
        // 纬线
        ctx.beginPath()
        ctx.moveTo(cx - r, cx)
        ctx.lineTo(cx + r, cx)
        ctx.stroke()
    }

    // 联动 — 链条
    function drawLinkage(ctx, s, p) {
        var r = s * 0.13
        var cx1 = s * 0.33, cx2 = s * 0.67
        var cy = s/2
        // 左环
        ctx.beginPath()
        ctx.arc(cx1, cy, r, 0, 2*Math.PI)
        ctx.stroke()
        // 右环
        ctx.beginPath()
        ctx.arc(cx2, cy, r, 0, 2*Math.PI)
        ctx.stroke()
        // 连接
        ctx.beginPath()
        ctx.moveTo(cx1 + r, cy)
        ctx.lineTo(cx2 - r, cy)
        ctx.stroke()
    }

    // 设置 — 齿轮
    function drawSettings(ctx, s, p) {
        var cx = s/2, r = s * 0.28
        // 外齿
        ctx.beginPath()
        for (var i = 0; i < 8; i++) {
            var a1 = (i / 8) * 2 * Math.PI
            var a2 = ((i + 0.3) / 8) * 2 * Math.PI
            var a3 = ((i + 0.7) / 8) * 2 * Math.PI
            var a4 = ((i + 1) / 8) * 2 * Math.PI
            var r1 = r * 0.7, r2 = r
            if (i === 0) ctx.moveTo(cx + r1 * Math.cos(a1), cx + r1 * Math.sin(a1))
            else ctx.lineTo(cx + r1 * Math.cos(a1), cx + r1 * Math.sin(a1))
            ctx.lineTo(cx + r2 * Math.cos(a2), cx + r2 * Math.sin(a2))
            ctx.lineTo(cx + r2 * Math.cos(a3), cx + r2 * Math.sin(a3))
            ctx.lineTo(cx + r1 * Math.cos(a4), cx + r1 * Math.sin(a4))
        }
        ctx.closePath()
        ctx.stroke()
        // 中心圆
        ctx.beginPath()
        ctx.arc(cx, cx, r * 0.35, 0, 2*Math.PI)
        ctx.stroke()
    }

    // 搜索 — 放大镜
    function drawSearch(ctx, s, p) {
        var cx = s * 0.42, r = s * 0.25
        ctx.beginPath()
        ctx.arc(cx, cx, r, 0, 2*Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(cx + r * 0.7, cx + r * 0.7)
        ctx.lineTo(s - p, s - p)
        ctx.stroke()
    }

    // 刷新 — 循环箭头
    function drawRefresh(ctx, s, p) {
        var cx = s/2, r = s * 0.3
        ctx.beginPath()
        ctx.arc(cx, cx, r, -Math.PI * 0.4, Math.PI * 1.1)
        ctx.stroke()
        // 箭头头
        ctx.beginPath()
        ctx.moveTo(cx + r * 0.95, cx - r * 0.35)
        ctx.lineTo(cx + r * 1.15, cx - r * 0.15)
        ctx.lineTo(cx + r * 0.75, cx - r * 0.1)
        ctx.closePath()
        ctx.fill()
    }

    // 导出 — 下载箭头
    function drawExport(ctx, s, p) {
        var cx = s/2
        ctx.beginPath()
        ctx.moveTo(cx, p + 2)
        ctx.lineTo(cx, s * 0.55)
        ctx.stroke()
        // 箭头
        ctx.beginPath()
        ctx.moveTo(p + 3, s * 0.4)
        ctx.lineTo(cx, s * 0.6)
        ctx.lineTo(s - p - 3, s * 0.4)
        ctx.stroke()
        // 底线
        ctx.beginPath()
        ctx.moveTo(p, s - p - 2)
        ctx.lineTo(s - p, s - p - 2)
        ctx.stroke()
    }

    // 展开
    function drawExpand(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, p + 5); ctx.lineTo(p + 5, p + 2); ctx.lineTo(p + 8, p + 5)
        ctx.moveTo(p + 2, s - p - 5); ctx.lineTo(p + 5, s - p - 2); ctx.lineTo(p + 8, s - p - 5)
        ctx.stroke()
    }

    // 收起
    function drawCollapse(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, p + 2); ctx.lineTo(p + 5, p + 5); ctx.lineTo(p + 8, p + 2)
        ctx.moveTo(p + 2, s - p - 2); ctx.lineTo(p + 5, s - p - 5); ctx.lineTo(p + 8, s - p - 2)
        ctx.stroke()
    }

    // 盾牌
    function drawShield(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(s/2, p)
        ctx.lineTo(s - p - 2, p + 4)
        ctx.lineTo(s - p - 2, s * 0.5)
        ctx.quadraticCurveTo(s - p - 2, s - p - 2, s/2, s - p)
        ctx.quadraticCurveTo(p + 2, s - p - 2, p + 2, s * 0.5)
        ctx.lineTo(p + 2, p + 4)
        ctx.closePath()
        ctx.stroke()
        // 内部勾
        ctx.beginPath()
        ctx.moveTo(s * 0.35, s * 0.45)
        ctx.lineTo(s * 0.45, s * 0.58)
        ctx.lineTo(s * 0.65, s * 0.35)
        ctx.stroke()
    }

    function drawClose(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 3, p + 3); ctx.lineTo(s - p - 3, s - p - 3)
        ctx.moveTo(s - p - 3, p + 3); ctx.lineTo(p + 3, s - p - 3)
        ctx.stroke()
    }

    function drawPlay(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 4, p + 2)
        ctx.lineTo(s - p - 2, s/2)
        ctx.lineTo(p + 4, s - p - 2)
        ctx.closePath()
        ctx.fill()
    }

    function drawStop(ctx, s, p) {
        ctx.strokeRect(p + 3, p + 3, s - 2*p - 6, s - 2*p - 6)
        ctx.fillRect(p + 4, p + 4, s - 2*p - 8, s - 2*p - 8)
    }

    function drawSnapshot(ctx, s, p) {
        var w = s - 2*p, h = s * 0.5
        var y = (s - h) / 2
        ctx.strokeRect(p, y, w, h)
        // 快门圆
        ctx.beginPath()
        ctx.arc(s/2, y + h/2, h * 0.28, 0, 2*Math.PI)
        ctx.stroke()
        // 顶部凸起
        ctx.beginPath()
        ctx.moveTo(s * 0.38, y)
        ctx.lineTo(s * 0.42, y - 3)
        ctx.lineTo(s * 0.58, y - 3)
        ctx.lineTo(s * 0.62, y)
        ctx.stroke()
    }

    function drawDelete(ctx, s, p) {
        var w = s - 2*p, h = s * 0.35
        var y = (s - h) / 2
        // 桶身
        ctx.beginPath()
        ctx.moveTo(p + 2, y)
        ctx.lineTo(s - p - 2, y)
        ctx.lineTo(s - p - 5, y + h)
        ctx.lineTo(p + 5, y + h)
        ctx.closePath()
        ctx.stroke()
        // 删除线
        ctx.beginPath()
        ctx.moveTo(s * 0.4, y + h * 0.3)
        ctx.lineTo(s * 0.6, y + h * 0.7)
        ctx.moveTo(s * 0.6, y + h * 0.3)
        ctx.lineTo(s * 0.4, y + h * 0.7)
        ctx.stroke()
    }

    function drawEdit(ctx, s, p) {
        var w = s - 2*p
        // 笔
        ctx.beginPath()
        ctx.moveTo(p + 2, s - p - 2)
        ctx.lineTo(s * 0.35, s * 0.65)
        ctx.lineTo(s - p - 2, p + 2)
        ctx.lineTo(s - p - 5, p + 5)
        ctx.lineTo(s * 0.3, s * 0.7)
        ctx.closePath()
        ctx.stroke()
    }

    function drawAdd(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 3, s/2); ctx.lineTo(s - p - 3, s/2)
        ctx.moveTo(s/2, p + 3); ctx.lineTo(s/2, s - p - 3)
        ctx.stroke()
    }

    function drawCheck(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, s * 0.5)
        ctx.lineTo(s * 0.38, s * 0.72)
        ctx.lineTo(s - p - 2, s * 0.28)
        ctx.stroke()
    }

    function drawWarning(ctx, s, p) {
        drawAlarm(ctx, s, p)
    }

    function drawInfo(ctx, s, p) {
        ctx.beginPath()
        ctx.arc(s/2, s/2, (s - 2*p)/2, 0, 2*Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(s/2, s * 0.4); ctx.lineTo(s/2, s * 0.68)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(s/2, s * 0.3, 1, 0, 2*Math.PI)
        ctx.fill()
    }

    function drawUser(ctx, s, p) {
        // 头
        ctx.beginPath()
        ctx.arc(s/2, s * 0.33, s * 0.13, 0, 2*Math.PI)
        ctx.stroke()
        // 身
        ctx.beginPath()
        ctx.arc(s/2, s * 0.85, s * 0.25, Math.PI, 2*Math.PI)
        ctx.stroke()
    }

    function drawLock(ctx, s, p) {
        var w = s - 2*p - 4, h = s * 0.3
        var y = s * 0.45
        // 锁体
        ctx.strokeRect(p + 2, y, w, h)
        // 锁环
        ctx.beginPath()
        ctx.arc(s/2, y, w * 0.35, Math.PI, 2*Math.PI)
        ctx.stroke()
    }

    function drawMap(ctx, s, p) {
        var w = s - 2*p
        // 地图框
        ctx.beginPath()
        ctx.moveTo(p + w * 0.15, p)
        ctx.lineTo(p + w * 0.5, p + 3)
        ctx.lineTo(p + w * 0.85, p)
        ctx.lineTo(p + w, p + 3)
        ctx.lineTo(p + w, s - p - 3)
        ctx.lineTo(p + w * 0.85, s - p)
        ctx.lineTo(p + w * 0.5, s - p - 3)
        ctx.lineTo(p + w * 0.15, s - p)
        ctx.lineTo(p, s - p - 3)
        ctx.lineTo(p, p + 3)
        ctx.closePath()
        ctx.stroke()
        // 折线(道路)
        ctx.beginPath()
        ctx.moveTo(p + w * 0.3, p + 4)
        ctx.lineTo(p + w * 0.5, s * 0.4)
        ctx.lineTo(p + w * 0.35, s * 0.6)
        ctx.lineTo(p + w * 0.7, s - p - 4)
        ctx.stroke()
    }

    function drawHeatmap(ctx, s, p) {
        var cells = 4
        var cw = (s - 2*p) / cells
        for (var r = 0; r < cells; r++) {
            for (var c = 0; c < cells; c++) {
                var intensity = (r + c) / (cells * 2 - 2)
                ctx.globalAlpha = 0.15 + intensity * 0.7
                ctx.fillRect(p + c * cw + 1, p + r * cw + 1, cw - 2, cw - 2)
            }
        }
        ctx.globalAlpha = 1.0
    }

    function drawTrajectory(ctx, s, p) {
        // 轨迹路径
        ctx.beginPath()
        ctx.moveTo(p + 2, s - p - 2)
        ctx.bezierCurveTo(s * 0.3, s * 0.6, s * 0.3, s * 0.3, s * 0.55, s * 0.4)
        ctx.bezierCurveTo(s * 0.7, s * 0.45, s * 0.8, s * 0.2, s - p - 2, p + 2)
        ctx.stroke()
        // 起点圆
        ctx.beginPath()
        ctx.arc(p + 2, s - p - 2, 2, 0, 2*Math.PI)
        ctx.fill()
        // 终点圆
        ctx.beginPath()
        ctx.arc(s - p - 2, p + 2, 2, 0, 2*Math.PI)
        ctx.fill()
    }

    function drawImage(ctx, s, p) {
        var w = s - 2*p
        ctx.strokeRect(p, p + 2, w, s - 2*p - 4)
        // 山
        ctx.beginPath()
        ctx.moveTo(p + 2, s - p - 3)
        ctx.lineTo(s * 0.35, s * 0.5)
        ctx.lineTo(s * 0.5, s * 0.65)
        ctx.lineTo(s * 0.7, s * 0.4)
        ctx.lineTo(s - p - 2, s - p - 3)
        ctx.stroke()
        // 太阳
        ctx.beginPath()
        ctx.arc(s * 0.7, s * 0.3, 1.5, 0, 2*Math.PI)
        ctx.fill()
    }

    function drawFolder(ctx, s, p) {
        var w = s - 2*p
        ctx.beginPath()
        ctx.moveTo(p, p + 4)
        ctx.lineTo(p + w * 0.4, p + 4)
        ctx.lineTo(p + w * 0.45 + 2, p)
        ctx.lineTo(p + w, p)
        ctx.lineTo(p + w, s - p - 2)
        ctx.lineTo(p, s - p - 2)
        ctx.closePath()
        ctx.stroke()
    }

    function drawDownload(ctx, s, p) {
        drawExport(ctx, s, p)
    }

    function drawUpload(ctx, s, p) {
        var cx = s/2
        ctx.beginPath()
        ctx.moveTo(cx, s * 0.6)
        ctx.lineTo(cx, p + 2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(p + 3, p + 5)
        ctx.lineTo(cx, p + 2)
        ctx.lineTo(s - p - 3, p + 5)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(p, s - p - 2)
        ctx.lineTo(s - p, s - p - 2)
        ctx.stroke()
    }

    function drawClock(ctx, s, p) {
        var r = (s - 2*p) / 2
        var cx = s/2
        ctx.beginPath()
        ctx.arc(cx, cx, r, 0, 2*Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(cx, cx)
        ctx.lineTo(cx, cx - r * 0.6)
        ctx.moveTo(cx, cx)
        ctx.lineTo(cx + r * 0.4, cx)
        ctx.stroke()
    }

    function drawCalendar(ctx, s, p) {
        var w = s - 2*p
        ctx.strokeRect(p, p + 3, w, s - 2*p - 5)
        // 挂钩
        ctx.beginPath()
        ctx.moveTo(p, p + 6); ctx.lineTo(p + w, p + 6)
        ctx.moveTo(p + w * 0.25, p); ctx.lineTo(p + w * 0.25, p + 8)
        ctx.moveTo(p + w * 0.75, p); ctx.lineTo(p + w * 0.75, p + 8)
        ctx.stroke()
    }

    function drawFilter(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, p + 2)
        ctx.lineTo(s - p - 2, p + 2)
        ctx.lineTo(s * 0.6, s * 0.45)
        ctx.lineTo(s * 0.6, s - p - 2)
        ctx.lineTo(s * 0.4, s - p - 4)
        ctx.lineTo(s * 0.4, s * 0.45)
        ctx.closePath()
        ctx.stroke()
    }

    function drawSort(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, s * 0.3); ctx.lineTo(s - p - 2, s * 0.3)
        ctx.moveTo(p + 6, s * 0.5); ctx.lineTo(s - p - 6, s * 0.5)
        ctx.moveTo(p + 10, s * 0.7); ctx.lineTo(s - p - 10, s * 0.7)
        ctx.stroke()
    }

    function drawMore(ctx, s, p) {
        for (var i = 0; i < 3; i++) {
            ctx.beginPath()
            ctx.arc(p + 3 + i * (s - 2*p - 6) / 2, s/2, 1.5, 0, 2*Math.PI)
            ctx.fill()
        }
    }

    function drawChevronLeft(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(s - p - 2, p + 3)
        ctx.lineTo(p + 3, s/2)
        ctx.lineTo(s - p - 2, s - p - 3)
        ctx.stroke()
    }

    function drawChevronRight(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 3, p + 3)
        ctx.lineTo(s - p - 2, s/2)
        ctx.lineTo(p + 3, s - p - 3)
        ctx.stroke()
    }

    function drawChevronDown(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 3, p + 3)
        ctx.lineTo(s/2, s - p - 2)
        ctx.lineTo(s - p - 3, p + 3)
        ctx.stroke()
    }

    function drawMenu(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, s * 0.3); ctx.lineTo(s - p - 2, s * 0.3)
        ctx.moveTo(p + 2, s/2); ctx.lineTo(s - p - 2, s/2)
        ctx.moveTo(p + 2, s * 0.7); ctx.lineTo(s - p - 2, s * 0.7)
        ctx.stroke()
    }

    function drawBell(ctx, s, p) {
        var w = s - 2*p
        ctx.beginPath()
        ctx.moveTo(p + 2, s - p - 4)
        ctx.quadraticCurveTo(p + 2, p + 3, s/2, p + 2)
        ctx.quadraticCurveTo(s - p - 2, p + 3, s - p - 2, s - p - 4)
        ctx.lineTo(p + 2, s - p - 4)
        ctx.stroke()
        // 摆锤
        ctx.beginPath()
        ctx.arc(s/2, s - p - 2, 1.5, 0, 2*Math.PI)
        ctx.fill()
    }

    function drawEye(ctx, s, p) {
        var w = s - 2*p
        ctx.beginPath()
        ctx.moveTo(p + 1, s/2)
        ctx.quadraticCurveTo(s/2, p + 1, s - p - 1, s/2)
        ctx.quadraticCurveTo(s/2, s - p - 1, p + 1, s/2)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(s/2, s/2, s * 0.1, 0, 2*Math.PI)
        ctx.fill()
    }

    function drawBrain(ctx, s, p) {
        var cx = s/2
        // 左半球
        ctx.beginPath()
        ctx.arc(cx - s * 0.05, cx, s * 0.2, Math.PI * 0.5, Math.PI * 1.5)
        ctx.stroke()
        // 右半球
        ctx.beginPath()
        ctx.arc(cx + s * 0.05, cx, s * 0.2, Math.PI * 1.5, Math.PI * 0.5)
        ctx.stroke()
        // 沟回
        ctx.beginPath()
        ctx.moveTo(cx - s * 0.1, cx - s * 0.05)
        ctx.lineTo(cx - s * 0.05, cx + s * 0.05)
        ctx.moveTo(cx + s * 0.05, cx - s * 0.05)
        ctx.lineTo(cx + s * 0.1, cx + s * 0.05)
        ctx.stroke()
    }

    function drawTool(ctx, s, p) {
        // 扳手
        ctx.beginPath()
        ctx.arc(p + 4, p + 4, 3, -Math.PI * 0.2, Math.PI * 1.2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(p + 6, p + 6)
        ctx.lineTo(s - p - 2, s - p - 2)
        ctx.stroke()
    }

    function drawSend(ctx, s, p) {
        ctx.beginPath()
        ctx.moveTo(p + 2, s/2)
        ctx.lineTo(s - p - 2, p + 2)
        ctx.lineTo(s - p - 4, s - p - 2)
        ctx.lineTo(p + 2, s/2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(s * 0.5, s * 0.5)
        ctx.lineTo(s - p - 4, s - p - 2)
        ctx.stroke()
    }

    // 审计 — 文档+放大镜
    function drawAudit(ctx, s, p) {
        var w = s - 2*p
        // 文档
        ctx.strokeRect(p + 1, p + 1, w * 0.65, w)
        // 文档行
        ctx.beginPath()
        ctx.moveTo(p + 4, p + 5); ctx.lineTo(p + w * 0.5, p + 5)
        ctx.moveTo(p + 4, p + 9); ctx.lineTo(p + w * 0.5, p + 9)
        ctx.moveTo(p + 4, p + 13); ctx.lineTo(p + w * 0.4, p + 13)
        ctx.stroke()
        // 放大镜
        ctx.beginPath()
        ctx.arc(p + w * 0.78, p + w * 0.75, s * 0.12, 0, 2*Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(p + w * 0.87, p + w * 0.84)
        ctx.lineTo(s - p - 1, s - p - 1)
        ctx.stroke()
    }
}
