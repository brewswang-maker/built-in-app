// ========================================================================
// SituationView.qml — 安全态势大屏 (3D厂区 + 实时告警 + 多维评分)
// 超越Web端: 本地OpenGL渲染3D场景，零网络延迟的实时推送
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: situationView

    // ── 顶部标题栏 ──
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: "#0A0C10"
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24

            Text {
                text: "🛡️ 华盾AI 安全态势大屏"
                font.pixelSize: 18
                font.bold: true
                color: "#00D4AA"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                font.pixelSize: 13
                color: "#8B8FA3"
            }

            Rectangle {
                width: 8; height: 8; radius: 4
                color: "#00D4AA"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
            Text {
                text: "实时在线"
                font.pixelSize: 12
                color: "#00D4AA"
            }
        }
    }

    // ── 三栏布局 ──
    RowLayout {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        anchors.margins: 8

        // ═══ 左侧面板 ═══
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            color: "#0D0F12"
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 安全评分仪表盘
                Rectangle {
                    width: parent.width - 24
                    height: 180
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "📊 安全评分"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#E8E8E8"
                        }

                        // 圆形进度条
                        Rectangle {
                            width: 120; height: 120
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Canvas {
                                id: scoreCanvas
                                anchors.fill: parent
                                property real score: 85

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    // 底环
                                    ctx.strokeStyle = "#252830"
                                    ctx.lineWidth = 8
                                    ctx.beginPath()
                                    ctx.arc(60, 60, 50, 0, 2 * Math.PI)
                                    ctx.stroke()
                                    // 进度环
                                    var deg = (score / 100) * 2 * Math.PI - Math.PI / 2
                                    ctx.strokeStyle = score >= 80 ? "#00D4AA" : score >= 60 ? "#FFB800" : "#FF3D71"
                                    ctx.lineWidth = 8
                                    ctx.beginPath()
                                    ctx.arc(60, 60, 50, -Math.PI / 2, deg)
                                    ctx.stroke()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "85"
                                font.pixelSize: 36
                                font.bold: true
                                color: "#00D4AA"
                            }
                        }

                        Row {
                            spacing: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: "入侵:92"; font.pixelSize: 11; color: "#00D4AA" }
                            Text { text: "消防:78"; font.pixelSize: 11; color: "#FFB800" }
                            Text { text: "PPE:95"; font.pixelSize: 11; color: "#00D4AA" }
                        }
                    }
                }

                // 告警趋势24h
                Rectangle {
                    width: parent.width - 24
                    height: 140
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: "🚨 告警趋势 (24h)"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#E8E8E8"
                        }

                        Canvas {
                            id: trendCanvas
                            width: parent.width - 24
                            height: 90

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var data = [3,5,2,8,12,6,4,15,9,7,3,5]
                                var max = Math.max.apply(null, data)
                                var barW = (width - 20) / data.length
                                for (var i = 0; i < data.length; i++) {
                                    var h = (data[i] / max) * 70
                                    ctx.fillStyle = data[i] > 10 ? "#FF3D71" : "#FFB800"
                                    ctx.fillRect(10 + i * barW + 2, height - h - 10, barW - 4, h)
                                }
                            }
                            Component.onCompleted: requestPaint()
                        }
                    }
                }

                // 设备状态饼图
                Rectangle {
                    width: parent.width - 24
                    height: 120
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: "📹 设备状态"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#E8E8E8"
                        }

                        Row {
                            spacing: 12
                            Text { text: "🟢 在线: 12"; font.pixelSize: 12; color: "#00D4AA" }
                            Text { text: "🔴 离线: 3"; font.pixelSize: 12; color: "#FF3D71" }
                            Text { text: "🟡 维护: 1"; font.pixelSize: 12; color: "#FFB800" }
                        }
                    }
                }
            }
        }

        // ═══ 中间 — 3D厂区地图 + 最新告警流 ═══
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "#0D0F12"
            radius: 8

            Column {
                anchors.fill: parent
                spacing: 8

                // 3D地图区域 (用Canvas模拟OpenGL 3D渲染)
                Rectangle {
                    width: parent.width
                    height: parent.height * 0.65
                    color: "#0A0C10"
                    radius: 8

                    Canvas {
                        id: scene3d
                        anchors.fill: parent
                        anchors.margins: 8

                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            ctx.clearRect(0, 0, w, h)

                            // 天空渐变
                            var grad = ctx.createLinearGradient(0, 0, 0, h * 0.4)
                            grad.addColorStop(0, "#0A1628")
                            grad.addColorStop(1, "#0D0F12")
                            ctx.fillStyle = grad
                            ctx.fillRect(0, 0, w, h)

                            // 地面网格 (透视效果)
                            ctx.strokeStyle = "#1A2D45"
                            ctx.lineWidth = 0.5
                            for (var i = 0; i < 20; i++) {
                                var y = h * 0.55 + i * 12
                                var spread = (i / 20) * w * 0.8
                                ctx.beginPath()
                                ctx.moveTo(w/2 - spread, y)
                                ctx.lineTo(w/2 + spread, y)
                                ctx.stroke()
                            }

                            // 建筑1 — 仓库A
                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.15, h*0.25, 120, 160)
                            ctx.strokeStyle = "#2A5A8C"
                            ctx.strokeRect(w*0.15, h*0.25, 120, 160)
                            ctx.fillStyle = "#E8E8E8"
                            ctx.font = "11px sans-serif"
                            ctx.fillText("仓库A", w*0.15+38, h*0.25+85)

                            // 建筑2 — 办公楼
                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.55, h*0.2, 100, 180)
                            ctx.strokeStyle = "#2A5A8C"
                            ctx.strokeRect(w*0.55, h*0.2, 100, 180)
                            ctx.fillStyle = "#E8E8E8"
                            ctx.fillText("办公楼", w*0.55+25, h*0.2+95)

                            // 建筑3 — 停车场
                            ctx.fillStyle = "#1A3A5C"
                            ctx.fillRect(w*0.35, h*0.45, 140, 80)
                            ctx.strokeStyle = "#2A5A8C"
                            ctx.strokeRect(w*0.35, h*0.45, 140, 80)
                            ctx.fillStyle = "#E8E8E8"
                            ctx.fillText("停车场", w*0.35+42, h*0.45+45)

                            // 摄像头标记 (闪烁)
                            var cameras = [
                                { x: w*0.15, y: h*0.2, name: "CAM-01", alert: false },
                                { x: w*0.45, y: h*0.3, name: "CAM-02", alert: true },
                                { x: w*0.7, y: h*0.15, name: "CAM-03", alert: false },
                                { x: w*0.3, y: h*0.55, name: "CAM-04", alert: false },
                                { x: w*0.6, y: h*0.42, name: "CAM-05", alert: true }
                            ]
                            for (var c = 0; c < cameras.length; c++) {
                                var cam = cameras[c]
                                // 视野锥
                                ctx.fillStyle = cam.alert ? "rgba(255,61,113,0.12)" : "rgba(0,212,170,0.08)"
                                ctx.beginPath()
                                ctx.moveTo(cam.x, cam.y)
                                ctx.lineTo(cam.x - 30, cam.y + 50)
                                ctx.lineTo(cam.x + 30, cam.y + 50)
                                ctx.closePath()
                                ctx.fill()

                                // 摄像头图标
                                ctx.fillStyle = cam.alert ? "#FF3D71" : "#00D4AA"
                                ctx.beginPath()
                                ctx.arc(cam.x, cam.y, 6, 0, 2 * Math.PI)
                                ctx.fill()

                                ctx.fillStyle = "#8B8FA3"
                                ctx.font = "9px sans-serif"
                                ctx.fillText(cam.name, cam.x - 15, cam.y - 10)
                            }

                            // 告警脉冲动画
                            var t = Date.now() / 1000
                            for (var a = 0; a < cameras.length; a++) {
                                if (cameras[a].alert) {
                                    var radius = 15 + Math.sin(t * 3) * 8
                                    ctx.strokeStyle = "rgba(255,61,113," + (0.6 - Math.sin(t*3)*0.3) + ")"
                                    ctx.lineWidth = 2
                                    ctx.beginPath()
                                    ctx.arc(cameras[a].x, cameras[a].y, radius, 0, 2 * Math.PI)
                                    ctx.stroke()
                                }
                            }

                            // 图例
                            ctx.fillStyle = "#4A4D58"
                            ctx.font = "10px sans-serif"
                            ctx.fillText("📹 正常  🔴 告警  🏢 监控区域", 12, h - 10)
                        }

                        Timer {
                            interval: 100
                            running: true
                            repeat: true
                            onTriggered: scene3d.requestPaint()
                        }
                    }
                }

                // 最新告警流
                Rectangle {
                    width: parent.width
                    height: parent.height * 0.35 - 16
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: "🚨 最新告警"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#E8E8E8"
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 30
                            clip: true
                            spacing: 4
                            model: ListModel {
                                ListElement { time: "11:32:15"; location: "仓库A-入口"; type: "人员入侵"; level: "高"; status: "未处置" }
                                ListElement { time: "11:28:03"; location: "停车场-B区"; type: "烟雾检测"; level: "紧急"; status: "处置中" }
                                ListElement { time: "11:15:42"; location: "办公楼-3F"; type: "未戴安全帽"; level: "中"; status: "已处置" }
                                ListElement { time: "10:58:19"; location: "仓库A-出口"; type: "人员聚集"; level: "中"; status: "已处置" }
                                ListElement { time: "10:42:07"; location: "周界-北侧"; type: "越线检测"; level: "高"; status: "未处置" }
                            }
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                color: model.level === "紧急" ? "#2A0A10" : model.level === "高" ? "#1A0A10" : "#1A1D23"
                                radius: 4

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 12

                                    Rectangle {
                                        width: 4; height: parent.height - 8
                                        color: model.level === "紧急" ? "#FF3D71" :
                                               model.level === "高" ? "#FF6B35" :
                                               model.level === "中" ? "#FFB800" : "#8B8FA3"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: model.time; font.pixelSize: 11; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: model.location; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter; width: 120 }
                                    Text { text: model.type; font.pixelSize: 12; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter; width: 90 }
                                    Rectangle {
                                        width: 56; height: 22; radius: 4
                                        color: model.status === "已处置" ? "#0A2A1A" :
                                               model.status === "处置中" ? "#2A2A0A" : "#2A0A10"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            text: model.status
                                            font.pixelSize: 10
                                            color: model.status === "已处置" ? "#00D4AA" :
                                                   model.status === "处置中" ? "#FFB800" : "#FF3D71"
                                            anchors.centerIn: parent
                                        }
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
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            color: "#0D0F12"
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // AI推理性能
                Rectangle {
                    width: parent.width - 24
                    height: 160
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text { text: "🧠 AI推理性能"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 12
                            Text { text: "TPU:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "78.3%"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "吞吐:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "25.4 FPS"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "延迟:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "38ms"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 12
                            Text { text: "模型数:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "5 / 8槽位"; font.pixelSize: 12; color: "#E8E8E8" }
                        }

                        ProgressBar {
                            width: parent.width
                            value: 0.783
                            background: Rectangle { color: "#252830"; radius: 4; height: 8 }
                            contentItem: Rectangle {
                                width: parent.visualPosition * parent.width
                                height: 8; radius: 4; color: "#FFB800"
                            }
                        }
                    }
                }

                // 模型状态列表
                Rectangle {
                    width: parent.width - 24
                    height: 200
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text { text: "📦 模型状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Repeater {
                            model: [
                                { name: "人员检测", status: "运行", fps: "25.4", tpu: "32%" },
                                { name: "烟火检测", status: "运行", fps: "28.1", tpu: "22%" },
                                { name: "PPE检测", status: "运行", fps: "22.0", tpu: "18%" },
                                { name: "车牌识别", status: "空闲", fps: "-", tpu: "0%" },
                                { name: "人脸比对", status: "停止", fps: "-", tpu: "0%" }
                            ]
                            delegate: Rectangle {
                                width: parent.width
                                height: 28
                                color: "transparent"
                                Row {
                                    anchors.fill: parent
                                    spacing: 6
                                    Rectangle { width: 6; height: 6; radius: 3; color: modelData.status === "运行" ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.name; font.pixelSize: 11; color: "#E8E8E8"; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.fps + " FPS"; font.pixelSize: 10; color: "#8B8FA3"; width: 50; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "TPU " + modelData.tpu; font.pixelSize: 10; color: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                // 硬件状态
                Rectangle {
                    width: parent.width - 24
                    height: 150
                    color: "#141720"
                    radius: 8

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text { text: "⚙️ 硬件状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                        Repeater {
                            model: [
                                { name: "BM1684X TPU", value: "78°C", bar: 0.78, color: "#FFB800" },
                                { name: "DDR4 内存", value: "2.1/4GB", bar: 0.525, color: "#3B82F6" },
                                { name: "eMMC 存储", value: "12/32GB", bar: 0.375, color: "#8B5CF6" },
                                { name: "网口吞吐", value: "180Mbps", bar: 0.18, color: "#10B981" }
                            ]
                            delegate: Column {
                                width: parent.width
                                spacing: 2
                                Row {
                                    Text { text: modelData.name; font.pixelSize: 11; color: "#8B8FA3"; width: 100 }
                                    Text { text: modelData.value; font.pixelSize: 11; color: "#E8E8E8"; anchors.right: parent.right }
                                }
                                ProgressBar {
                                    width: parent.width; value: modelData.bar; height: 4
                                    background: Rectangle { color: "#252830"; radius: 2; height: 4 }
                                    contentItem: Rectangle { width: parent.visualPosition * parent.width; height: 4; radius: 2; color: modelData.color }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
