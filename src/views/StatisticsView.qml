import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: statsPage

    // ── Safety Score (Center) ──
    Rectangle {
        id: scoreCard
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        width: 200
        height: 200
        color: "#1A1D23"
        radius: 16

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "🛡️"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "85"
                font.pixelSize: 56
                font.bold: true
                color: "#00D4AA"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "安全评分"
                font.pixelSize: 14
                color: "#8B8FA3"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Ring progress
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.beginPath()
                ctx.arc(width/2, height/2, 90, 0, Math.PI * 2)
                ctx.strokeStyle = "#252830"
                ctx.lineWidth = 6
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(width/2, height/2, 90, -Math.PI/2, -Math.PI/2 + Math.PI * 2 * 0.85)
                ctx.strokeStyle = "#00D4AA"
                ctx.lineWidth = 6
                ctx.lineCap = "round"
                ctx.stroke()
            }
            Component.onCompleted: requestPaint()
        }
    }

    // ── Stat Cards Grid ──
    Grid {
        anchors.top: scoreCard.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.topMargin: 16
        spacing: 12
        columns: 3
        rows: 2

        Repeater {
            model: [
                { icon: "🚨", title: "今日告警", value: alarmController.alarmCount, sub: "较昨日 ↓12%", color: "#FF3D71" },
                { icon: "📹", title: "在线设备", value: deviceController.deviceCount, sub: "全部在线", color: "#00D4AA" },
                { icon: "🧠", title: "AI推理", value: "1,247", sub: "平均延迟 45ms", color: "#FFB800" },
                { icon: "🎯", title: "告警趋势", value: "↓40%", sub: "近7日持续下降", color: "#00D4AA" },
                { icon: "⚡", title: "TPU负载", value: statusController.tpuUtilization.toFixed(0) + "%", sub: statusController.activeModels + " 模型活跃", color: "#FF6B35" },
                { icon: "💾", title: "内存使用", value: statusController.memoryUsage.toFixed(0) + "%", sub: "4.2GB / 8GB", color: "#8B8FA3" }
            ]

            delegate: Rectangle {
                width: statsPage.width / 3 - 20
                height: 140
                color: "#1A1D23"
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 4

                    Text {
                        text: modelData.icon + " " + modelData.title
                        font.pixelSize: 13
                        color: "#8B8FA3"
                    }
                    Text {
                        text: modelData.value
                        font.pixelSize: 32
                        font.bold: true
                        color: modelData.color
                    }
                    Text {
                        text: modelData.sub
                        font.pixelSize: 11
                        color: "#4A4D58"
                    }
                }
            }
        }
    }

    // ── Export Button ──
    Button {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 16
        text: "📥 导出CSV"
        font.pixelSize: 12
        onClicked: {}  // TODO: export
        background: Rectangle { color: "#252830"; radius: 6 }
        contentItem: Text {
            text: parent.text; font.pixelSize: parent.font.pixelSize
            color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
