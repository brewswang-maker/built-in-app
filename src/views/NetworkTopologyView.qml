// ========================================================================
// NetworkTopologyView.qml — IoT 设备拓扑图 (1:1 对齐 Web 端 /topology 截图)
//
// 数据来源: deviceController.devices (GET /api/v1/devices)
// 布局: 力导向简化版 — 边缘盒子/网关居中, 摄像头等终端设备环形分布
// 主题: 浅色 (Web 内容区白底), 与截图一致
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: topoView

    // ── 主题色 (Web Element 浅色) ──
    readonly property color cPageBg: "#F5F7FA"
    readonly property color cCardBg: "#FFFFFF"
    readonly property color cBorder: "#E4E7ED"
    readonly property color cTextPrimary: "#303133"
    readonly property color cTextSecondary: "#909399"
    readonly property color cOnline: "#67C23A"
    readonly property color cOffline: "#C0C4CC"
    readonly property color cAlarm: "#E6A23C"
    readonly property color cMaint: "#3B82F6"

    // 状态 → 颜色 (Web: 绿在线/灰离线/橙告警/蓝维护)
    function statusColor(st) {
        if (st === "online") return cOnline
        if (st === "offline") return cOffline
        if (st === "warning" || st === "alarming") return cAlarm
        if (st === "maintenance") return cMaint
        return cOffline
    }

    // 设备类型 → 底部图例色块 (Web: 蓝边缘盒子/绿摄像头/黄NVR/红DVR)
    function typeColor(t) {
        t = String(t || "").toLowerCase()
        if (t.indexOf("box") >= 0 || t.indexOf("gateway") >= 0 || t.indexOf("edge") >= 0) return "#3B82F6"
        if (t.indexOf("nvr") >= 0) return "#E6A23C"
        if (t.indexOf("dvr") >= 0) return "#F56C6C"
        return "#67C23A"   // camera / 默认
    }

    function typeName(t) {
        t = String(t || "").toLowerCase()
        if (t.indexOf("box") >= 0 || t.indexOf("gateway") >= 0 || t.indexOf("edge") >= 0) return "边缘盒子"
        if (t.indexOf("nvr") >= 0) return "NVR"
        if (t.indexOf("dvr") >= 0) return "DVR"
        return "摄像头"
    }

    Component.onCompleted: deviceController.refreshDevices()

    Connections {
        target: deviceController
        function onDevicesUpdated() { canvas.requestPaint() }
    }

    Rectangle { anchors.fill: parent; color: cPageBg }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── 标题栏: IoT 设备拓扑图 + N 个设备 · N 在线 | 力导向 ▾ | 刷新 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "IoT 设备拓扑图"
                font.pixelSize: 18
                font.bold: true
                color: cTextPrimary
            }

            Rectangle {
                width: badgeText.implicitWidth + 20
                height: 24
                radius: 12
                color: "#ECF5FF"
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: deviceController.deviceCount + " 个设备 · " + deviceController.onlineCount + " 在线"
                    font.pixelSize: 12
                    color: "#3B82F6"
                }
            }

            Item { Layout.fillWidth: true }

            // 布局方式下拉 (Web: 力导向)
            Rectangle {
                width: 96; height: 32
                radius: 4
                color: cCardBg
                border.color: cBorder
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6
                    Text { text: "力导向"; font.pixelSize: 13; color: cTextPrimary }
                    Item { Layout.fillWidth: true }
                    AppIcon { name: "chevronDown"; size: 12; iconColor: cTextSecondary }
                }
            }

            // 刷新按钮
            Rectangle {
                width: 80; height: 32
                radius: 4
                color: refreshMa.containsMouse ? "#ECF5FF" : cCardBg
                border.color: refreshMa.containsMouse ? "#3B82F6" : cBorder
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    AppIcon { name: "refresh"; size: 14; iconColor: "#3B82F6" }
                    Text { text: "刷新"; font.pixelSize: 13; color: "#3B82F6" }
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: deviceController.refreshDevices()
                }
            }
        }

        // ── 拓扑画布卡片 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: cCardBg
            border.color: cBorder

            // 左上状态图例 (Web: 在线/离线/告警/维护)
            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 8
                z: 2

                Repeater {
                    model: [
                        { c: cOnline,  t: "在线" },
                        { c: cOffline, t: "离线" },
                        { c: cAlarm,   t: "告警" },
                        { c: cMaint,   t: "维护" }
                    ]
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: modelData.c
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.t
                            font.pixelSize: 12
                            color: cTextSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                anchors.margins: 1
                onPaint: drawTopology()

                function drawTopology() {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var w = width, h = height
                    var devs = deviceController.devices || []
                    var cx = w / 2, cy = h / 2

                    if (devs.length === 0) {
                        // 空态: 如实呈现
                        ctx.fillStyle = "#909399"
                        ctx.font = "14px sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText("暂无设备数据", cx, cy - 8)
                        ctx.font = "12px sans-serif"
                        ctx.fillStyle = "#C0C4CC"
                        ctx.fillText("请在 设备管理 中添加设备后刷新", cx, cy + 14)
                        return
                    }

                    // 简化力导向: 单设备居中; 多设备环形均布
                    var positions = []
                    if (devs.length === 1) {
                        positions.push({ x: cx, y: cy })
                    } else {
                        var r = Math.min(w, h) * 0.32
                        for (var i = 0; i < devs.length; i++) {
                            var ang = -Math.PI / 2 + (2 * Math.PI * i) / devs.length
                            positions.push({ x: cx + r * Math.cos(ang), y: cy + r * Math.sin(ang) })
                        }
                    }

                    // 连线 (多设备时连向中心)
                    if (devs.length > 1) {
                        ctx.strokeStyle = "rgba(192,196,204,0.6)"
                        ctx.lineWidth = 1
                        for (var l = 0; l < positions.length; l++) {
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.lineTo(positions[l].x, positions[l].y)
                            ctx.stroke()
                        }
                    }

                    // 设备节点: 圆底 + 相机图标 + ID 标签
                    for (var d = 0; d < devs.length; d++) {
                        var dev = devs[d]
                        var p = positions[d]
                        var sc = statusColor(dev.status)

                        // 节点圆 (Web: 绿色相机图标)
                        ctx.beginPath()
                        ctx.arc(p.x, p.y, 22, 0, 2 * Math.PI)
                        ctx.fillStyle = "#FFFFFF"
                        ctx.fill()
                        ctx.lineWidth = 2
                        ctx.strokeStyle = sc
                        ctx.stroke()

                        // 相机图标 (简化绘制)
                        ctx.fillStyle = sc
                        ctx.fillRect(p.x - 10, p.y - 6, 20, 13)
                        ctx.beginPath()
                        ctx.moveTo(p.x + 10, p.y - 3)
                        ctx.lineTo(p.x + 16, p.y - 6)
                        ctx.lineTo(p.x + 16, p.y + 6)
                        ctx.lineTo(p.x + 10, p.y + 3)
                        ctx.closePath()
                        ctx.fill()

                        // 状态小圆点
                        ctx.beginPath()
                        ctx.arc(p.x + 16, p.y - 16, 5, 0, 2 * Math.PI)
                        ctx.fillStyle = sc
                        ctx.fill()
                        ctx.lineWidth = 1.5
                        ctx.strokeStyle = "#FFFFFF"
                        ctx.stroke()

                        // 设备 ID 标签 (Web: 图标下方)
                        ctx.fillStyle = cTextPrimary
                        ctx.font = "12px sans-serif"
                        ctx.textAlign = "center"
                        var id = dev.deviceId || dev.id || dev.name || "-"
                        ctx.fillText(String(id), p.x, p.y + 40)
                    }
                }
            }

            // 底部类型图例 (Web: 蓝边缘盒子/绿摄像头/黄NVR/红DVR)
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 12
                spacing: 20

                Repeater {
                    model: [
                        { c: "#3B82F6", t: "边缘盒子" },
                        { c: "#67C23A", t: "摄像头" },
                        { c: "#E6A23C", t: "NVR" },
                        { c: "#F56C6C", t: "DVR" }
                    ]
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 12; height: 12; radius: 2
                            color: modelData.c
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.t
                            font.pixelSize: 12
                            color: cTextSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
