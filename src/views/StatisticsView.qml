// ========================================================================
// StatisticsView.qml — 增强版统计 (对标Web端340行)
// 新增: Canvas图表(告警趋势/类型分布/设备状态) | 日期选择 | CSV导出 | 安全评分仪表盘
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: statsPage

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Text { text: "📊 统计分析"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            ComboBox { width: 100; height: 30; model: ["今天", "近7天", "近30天", "自定义"]; background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
            TextField { width: 100; height: 30; placeholderText: "开始日期"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 11; background: Rectangle { color: "#252830"; radius: 6 }; visible: false }
            TextField { width: 100; height: 30; placeholderText: "结束日期"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 11; background: Rectangle { color: "#252830"; radius: 6 }; visible: false }

            Item { Layout.fillWidth: true }

            Button { text: "📥 导出CSV"; font.pixelSize: 11
                background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: statusController.exportStats("csv")
            }
            Button { text: "🔄 刷新"; font.pixelSize: 11
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ═══ 顶部统计卡片 ═══
    Row {
        id: statCards
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8; height: 80

        Repeater {
            model: [
                { icon: "🚨", label: "告警总数", value: "156", sub: "较昨日↓12%", color: "#FF3D71" },
                { icon: "✅", label: "处置率", value: "95%", sub: "较昨日+3%", color: "#00D4AA" },
                { icon: "📹", label: "设备在线", value: "16/20", sub: "4台离线", color: "#3B82F6" },
                { icon: "🛡️", label: "安全评分", value: "85", sub: "良好", color: "#FFB800" },
                { icon: "🧠", label: "AI推理", value: "12.5ms", sub: "平均延迟", color: "#6C5CE7" }
            ]

            delegate: Rectangle {
                width: (statCards.width - 4 * 8) / 5; height: 80; color: "#0D0F12"; radius: 8
                Column { anchors.fill: parent; anchors.margins: 10; spacing: 2
                    Row { spacing: 4
                        Text { text: modelData.icon; font.pixelSize: 14 }
                        Text { text: modelData.label; font.pixelSize: 10; color: "#8B8FA3" }
                    }
                    Text { text: modelData.value; font.pixelSize: 22; font.bold: true; color: modelData.color }
                    Text { text: modelData.sub; font.pixelSize: 10; color: "#8B8FA3" }
                }
            }
        }
    }

    // ═══ 图表区域 ═══
    RowLayout {
        anchors.top: statCards.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左: 告警趋势折线图 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true; color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📈 告警趋势 (近7天)"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: trendCanvas
                    width: parent.width - 24; height: parent.height - 80

                    property var criticalData: [3, 1, 5, 2, 4, 1, 3]
                    property var warningData: [12, 8, 15, 7, 10, 6, 11]
                    property var infoData: [8, 9, 11, 6, 8, 5, 5]
                    property var labels: ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                        var maxVal = 20
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
                        for (var i = 0; i < labels.length; i++) {
                            var x = padL + (i / (labels.length - 1)) * chartW
                            ctx.fillText(labels[i], x, h - 6)
                        }

                        function drawLine(data, color, alpha) {
                            ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath()
                            for (var i = 0; i < data.length; i++) {
                                var x = padL + (i / (data.length - 1)) * chartW
                                var y = padT + (1 - data[i] / maxVal) * chartH
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                            // 填充
                            ctx.lineTo(padL + ((data.length - 1) / (data.length - 1)) * chartW, padT + chartH)
                            ctx.lineTo(padL, padT + chartH); ctx.closePath()
                            ctx.fillStyle = color.replace(")", "," + alpha + ")").replace("rgb", "rgba")
                            ctx.fill()
                        }

                        drawLine(infoData, "rgb(0,212,170)", 0.05)
                        drawLine(warningData, "rgb(255,107,53)", 0.05)
                        drawLine(criticalData, "rgb(255,61,113)", 0.05)
                    }
                    Component.onCompleted: requestPaint()
                }

                Row { spacing: 16
                    Row { spacing: 4; Rectangle { width: 12; height: 3; radius: 1; color: "#FF3D71" } Text { text: "严重"; font.pixelSize: 10; color: "#FF3D71" } }
                    Row { spacing: 4; Rectangle { width: 12; height: 3; radius: 1; color: "#FF6B35" } Text { text: "警告"; font.pixelSize: 10; color: "#FF6B35" } }
                    Row { spacing: 4; Rectangle { width: 12; height: 3; radius: 1; color: "#00D4AA" } Text { text: "信息"; font.pixelSize: 10; color: "#00D4AA" } }
                }
            }
        }

        // ── 右: 告警类型分布 + 设备状态饼图 ──
        ColumnLayout {
            Layout.fillHeight: true; Layout.preferredWidth: 300; spacing: 8

            // 告警类型分布
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: "#141720"; radius: 8

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6

                    Text { text: "🥧 告警类型分布"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Canvas {
                        width: parent.width - 24; height: parent.height - 50
                        property var data: [42, 28, 18, 12, 8, 6]
                        property var labels: ["周界入侵", "绊线检测", "烟火", "安全帽", "人脸", "人群"]
                        property var colors: ["#FF3D71", "#FF6B35", "#FFB800", "#3B82F6", "#6C5CE7", "#00D4AA"]

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 70, cy = height / 2, r = Math.min(cx, cy) - 10
                            var total = 0; for (var i = 0; i < data.length; i++) total += data[i]
                            var start = -Math.PI / 2
                            for (var i = 0; i < data.length; i++) {
                                var angle = (data[i] / total) * 2 * Math.PI
                                ctx.beginPath(); ctx.moveTo(cx, cy)
                                ctx.arc(cx, cy, r, start, start + angle); ctx.closePath()
                                ctx.fillStyle = colors[i]; ctx.fill()
                                start += angle
                            }
                            ctx.beginPath(); ctx.arc(cx, cy, r * 0.5, 0, 2 * Math.PI)
                            ctx.fillStyle = "#141720"; ctx.fill()
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "bold 14px sans-serif"; ctx.textAlign = "center"
                            ctx.fillText(total, cx, cy + 5)
                            for (var i = 0; i < labels.length; i++) {
                                ctx.fillStyle = colors[i]; ctx.fillRect(155, 10 + i * 22, 10, 10)
                                ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"; ctx.textAlign = "left"
                                ctx.fillText(labels[i] + " " + data[i] + " (" + Math.round(data[i] / total * 100) + "%)", 170, 19 + i * 22)
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }

            // 设备状态
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 140; color: "#141720"; radius: 8

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6

                    Text { text: "📹 设备状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Row { spacing: 24; anchors.horizontalCenter: parent.horizontalCenter
                        Column { spacing: 2
                            Rectangle { width: 60; height: 60; radius: 30; color: "#1A3A2A"; border.color: "#00D4AA"; border.width: 2
                                Text { text: "16"; font.pixelSize: 22; font.bold: true; color: "#00D4AA"; anchors.centerIn: parent } }
                            Text { text: "在线"; font.pixelSize: 11; color: "#00D4AA"; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        Column { spacing: 2
                            Rectangle { width: 60; height: 60; radius: 30; color: "#2A1A1A"; border.color: "#FF3D71"; border.width: 2
                                Text { text: "4"; font.pixelSize: 22; font.bold: true; color: "#FF3D71"; anchors.centerIn: parent } }
                            Text { text: "离线"; font.pixelSize: 11; color: "#FF3D71"; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        Column { spacing: 2
                            Rectangle { width: 60; height: 60; radius: 30; color: "#1A1A2A"; border.color: "#FFB800"; border.width: 2
                                Text { text: "2"; font.pixelSize: 22; font.bold: true; color: "#FFB800"; anchors.centerIn: parent } }
                            Text { text: "维护中"; font.pixelSize: 11; color: "#FFB800"; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }
        }
    }
}
