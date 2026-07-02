// ========================================================================
// HeatmapOverlay.qml — 告警热力图 + 轨迹回放 Canvas 组件
// 对标海康告警热力图: 区域密度可视化 + 时间轴回放
// 可嵌入任意父容器 (anchors.fill: parent)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: heatRoot

    // ── 数据输入 ──
    // 格式: [{ x: 0~1, y: 0~1, count: 3, type: "perimeter" }]
    property var heatPoints: []
    // 轨迹数据: [{ x: 0~1, y: 0~1, t: timestamp_ms }]
    property var trajectoryPoints: []
    // 回放进度 0.0~1.0
    property real playbackProgress: 1.0
    // 是否显示热力图
    property bool showHeatmap: true
    // 是否显示轨迹
    property bool showTrajectory: false
    // 回放速度
    property real playbackSpeed: 1.0
    // 当前回放位置索引
    property int currentTrajectoryIdx: 0

    // ── 回放定时器 ──
    Timer {
        id: trajectoryTimer
        interval: 50
        repeat: true
        running: showTrajectory && trajectoryPoints.length > 0
        onTriggered: {
            if (currentTrajectoryIdx < trajectoryPoints.length - 1) {
                currentTrajectoryIdx += Math.max(1, Math.floor(playbackSpeed * 2))
                heatCanvas.requestPaint()
            } else {
                currentTrajectoryIdx = trajectoryPoints.length - 1
                stop()
            }
        }
    }

    // ── 主绘制 Canvas ──
    Canvas {
        id: heatCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height
            ctx.clearRect(0, 0, w, h)

            // ① 热力图层
            if (heatRoot.showHeatmap && heatRoot.heatPoints.length > 0) {
                // 先画一层模糊背景
                for (var i = 0; i < heatRoot.heatPoints.length; i++) {
                    var p = heatRoot.heatPoints[i]
                    var px = p.x * w
                    var py = p.y * h
                    var intensity = Math.min(1.0, p.count / 10)

                    // 径向渐变 — 蓝绿黄红
                    var radius = 40 + intensity * 30
                    var grad = ctx.createRadialGradient(px, py, 0, px, py, radius)
                    var alpha = 0.15 + intensity * 0.55

                    if (intensity < 0.25) {
                        grad.addColorStop(0, "rgba(0, 100, 255, " + alpha + ")")
                        grad.addColorStop(0.5, "rgba(0, 200, 200, " + (alpha * 0.6) + ")")
                    } else if (intensity < 0.5) {
                        grad.addColorStop(0, "rgba(0, 220, 120, " + alpha + ")")
                        grad.addColorStop(0.5, "rgba(100, 240, 50, " + (alpha * 0.6) + ")")
                    } else if (intensity < 0.75) {
                        grad.addColorStop(0, "rgba(255, 200, 0, " + alpha + ")")
                        grad.addColorStop(0.5, "rgba(255, 150, 0, " + (alpha * 0.6) + ")")
                    } else {
                        grad.addColorStop(0, "rgba(255, 60, 60, " + alpha + ")")
                        grad.addColorStop(0.5, "rgba(200, 30, 80, " + (alpha * 0.6) + ")")
                    }
                    grad.addColorStop(1, "rgba(0, 0, 0, 0)")

                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.arc(px, py, radius, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }

            // ② 轨迹回放层
            if (heatRoot.showTrajectory && heatRoot.trajectoryPoints.length > 1) {
                var endIdx = Math.min(heatRoot.currentTrajectoryIdx, heatRoot.trajectoryPoints.length - 1)

                // 轨迹路径线
                ctx.strokeStyle = "#00D4AA"
                ctx.lineWidth = 2.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()

                for (var j = 0; j <= endIdx; j++) {
                    var tp = heatRoot.trajectoryPoints[j]
                    var tx = tp.x * w
                    var ty = tp.y * h
                    if (j === 0) ctx.moveTo(tx, ty)
                    else ctx.lineTo(tx, ty)
                }
                ctx.stroke()

                // 轨迹渐变拖尾 (最近5个点高亮)
                if (endIdx >= 5) {
                    ctx.strokeStyle = "#3B82F6"
                    ctx.lineWidth = 4
                    ctx.beginPath()
                    var tailStart = endIdx - 5
                    for (var k = tailStart; k <= endIdx; k++) {
                        var ttp = heatRoot.trajectoryPoints[k]
                        if (k === tailStart) ctx.moveTo(ttp.x * w, ttp.y * h)
                        else ctx.lineTo(ttp.x * w, ttp.y * h)
                    }
                    ctx.stroke()
                }

                // 当前位置脉冲点
                var cur = heatRoot.trajectoryPoints[endIdx]
                var cx = cur.x * w
                var cy = cur.y * h

                // 外圈脉冲
                ctx.fillStyle = "rgba(0, 212, 170, 0.2)"
                ctx.beginPath()
                ctx.arc(cx, cy, 12, 0, 2 * Math.PI)
                ctx.fill()

                // 内圈实心
                ctx.fillStyle = "#00D4AA"
                ctx.beginPath()
                ctx.arc(cx, cy, 5, 0, 2 * Math.PI)
                ctx.fill()

                // 起点标记
                var start = heatRoot.trajectoryPoints[0]
                ctx.fillStyle = "#3B82F6"
                ctx.beginPath()
                ctx.arc(start.x * w, start.y * h, 4, 0, 2 * Math.PI)
                ctx.fill()

                // 终点标记
                var last = heatRoot.trajectoryPoints[heatRoot.trajectoryPoints.length - 1]
                ctx.fillStyle = "#FF3D71"
                ctx.beginPath()
                ctx.arc(last.x * w, last.y * h, 4, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    // ── 控制工具栏 ──
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 200; height: 36
        radius: 8
        color: "#141420"
        border.color: "#252830"
        opacity: 0.9

        Row {
            anchors.centerIn: parent
            spacing: 8

            // 热力图开关
            Button {
                width: 70; height: 26
                text: "热力图"
                font.pixelSize: 12
                highlighted: heatRoot.showHeatmap
                background: Rectangle {
                    color: heatRoot.showHeatmap ? "#00D4AA" : "#252830"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12
                    color: heatRoot.showHeatmap ? "#0D0F12" : "#8B8FA3"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    heatRoot.showHeatmap = !heatRoot.showHeatmap
                    heatCanvas.requestPaint()
                }
            }

            // 轨迹开关
            Button {
                width: 70; height: 26
                text: "轨迹"
                font.pixelSize: 12
                highlighted: heatRoot.showTrajectory
                background: Rectangle {
                    color: heatRoot.showTrajectory ? "#3B82F6" : "#252830"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12
                    color: heatRoot.showTrajectory ? "#FFF" : "#8B8FA3"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    heatRoot.showTrajectory = !heatRoot.showTrajectory
                    if (heatRoot.showTrajectory) {
                        heatRoot.currentTrajectoryIdx = 0
                        trajectoryTimer.start()
                    }
                    heatCanvas.requestPaint()
                }
            }
        }
    }

    // ── 回放时间轴 ──
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 40
        radius: 8
        color: "#141420"
        border.color: "#252830"
        opacity: 0.9
        visible: heatRoot.showTrajectory && heatRoot.trajectoryPoints.length > 1

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // 回退
            Button {
                width: 24; height: 24
                flat: true
                background: Rectangle { color: "transparent" }
                contentItem: AppIcon { name: "refresh"; size: 14; iconColor: "#8B8FA3" }
                onClicked: {
                    heatRoot.currentTrajectoryIdx = 0
                    heatCanvas.requestPaint()
                }
            }

            // 进度条
            Slider {
                width: parent.width - 100
                anchors.verticalCenter: parent.verticalCenter
                from: 0
                to: Math.max(1, heatRoot.trajectoryPoints.length - 1)
                value: heatRoot.currentTrajectoryIdx
                onMoved: {
                    heatRoot.currentTrajectoryIdx = Math.floor(value)
                    heatCanvas.requestPaint()
                }
            }

            // 速度选择
            ComboBox {
                width: 60; height: 24
                font.pixelSize: 12
                model: ["0.5x", "1x", "2x", "4x"]
                currentIndex: 1
                background: Rectangle { color: "#252830"; radius: 4 }
                contentItem: Text {
                    text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"
                    verticalAlignment: Text.AlignVCenter; leftPadding: 4
                }
                onActivated: {
                    var rates = [0.5, 1.0, 2.0, 4.0]
                    heatRoot.playbackSpeed = rates[currentIndex]
                }
            }
        }
    }

    // ── 图例 ──
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 8
        width: 100; height: 60
        radius: 6
        color: "#141420"
        opacity: 0.85
        visible: heatRoot.showHeatmap

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text { text: "告警密度"; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter }

            Row {
                spacing: 2
                Rectangle { width: 16; height: 8; color: Qt.rgba(0, 0.39, 1, 0.6); radius: 2 }
                Rectangle { width: 16; height: 8; color: Qt.rgba(0, 0.86, 0.47, 0.6); radius: 2 }
                Rectangle { width: 16; height: 8; color: Qt.rgba(1, 0.78, 0, 0.6); radius: 2 }
                Rectangle { width: 16; height: 8; color: Qt.rgba(1, 0.24, 0.24, 0.6); radius: 2 }
            }

            Text { text: "低   高"; font.pixelSize: 8; color: "#4A4D58"; horizontalAlignment: Text.AlignHCenter }
        }
    }

    // ── 外部接口 ──
    function setHeatData(points) {
        heatPoints = points
        heatCanvas.requestPaint()
    }

    function setTrajectoryData(points) {
        trajectoryPoints = points
        currentTrajectoryIdx = 0
        heatCanvas.requestPaint()
    }

    function replayTrajectory() {
        currentTrajectoryIdx = 0
        trajectoryTimer.start()
    }
}
