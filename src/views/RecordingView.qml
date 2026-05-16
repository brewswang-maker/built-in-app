// ========================================================================
// RecordingView.qml — 录像回放 (时间轴 + 多路同步 + 本地存储管理)
// 超越Web端: 硬件解码加速、时间轴精确到帧、多路同步回放
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: recordingView

    // ── 顶部工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "📼 录像回放"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            ComboBox {
                id: channelSelect
                width: 180
                model: ["全部通道", "通道1 — 海康IPC-01", "通道2 — 大华IPC-02", "通道3 — 宇视NVR-CH1", "通道4 — 海康IPC-03"]
                background: Rectangle { color: "#252830"; radius: 6 }
            }

            Item { Layout.fillWidth: true }

            // 日期选择
            Button {
                text: "📅 " + calendarLabel.text
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: calendarPopup.open()
            }
            Button {
                text: "⏪ 前一天"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "后一天 ⏩"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // 隐藏的日期标签
    Text { id: calendarLabel; text: "2026-05-16"; visible: false }

    Popup {
        id: calendarPopup
        y: toolbar.height
        Calendar {
            selectedDate: new Date()
        }
    }

    // ── 主内容区 ──
    ColumnLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // 视频回放区域
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: "#0A0C10"; radius: 8

            Column {
                anchors.fill: parent; spacing: 0

                // 视频画面区
                Rectangle {
                    width: parent.width; height: parent.height - 120
                    color: "#000000"

                    // 播放器占位
                    Text {
                        anchors.centerIn: parent
                        text: "▶ 点击播放录像"
                        font.pixelSize: 16; color: "#4A4D58"
                    }

                    // 通道信息叠加
                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8
                        width: 160; height: 24; color: "rgba(0,0,0,0.6)"; radius: 4
                        Text { text: "📹 通道1 — 海康IPC-01"; font.pixelSize: 11; color: "#E8E8E8"; anchors.centerIn: parent }
                    }

                    // 时间戳叠加
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                        width: 140; height: 24; color: "rgba(0,0,0,0.6)"; radius: 4
                        Text { text: "2026-05-16 10:30:25"; font.pixelSize: 11; color: "#FFB800"; anchors.centerIn: parent }
                    }

                    // 多路同步视图 (缩略图)
                    Row {
                        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 8
                        spacing: 4

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                width: 80; height: 45; color: "#141720"; radius: 4
                                border.color: index === 0 ? "#00D4AA" : "#252830"; border.width: index === 0 ? 2 : 1
                                Text { text: "CH" + (index+1); font.pixelSize: 10; color: "#8B8FA3"; anchors.centerIn: parent }
                            }
                        }
                    }
                }

                // 时间轴区域
                Rectangle {
                    width: parent.width; height: 80; color: "#141720"

                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4

                        // 播放控制栏
                        Row {
                            spacing: 8
                            Button { text: "⏮"; font.pixelSize: 14; background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }; contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "⏪"; font.pixelSize: 14; background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }; contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "▶"; font.pixelSize: 16; background: Rectangle { color: "#00D4AA"; radius: 4; width: 40; height: 28 }; contentItem: Text { text: parent.text; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "⏩"; font.pixelSize: 14; background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }; contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "⏭"; font.pixelSize: 14; background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }; contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }

                            Text { text: "|"; font.pixelSize: 14; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }

                            Text { text: "速度:"; font.pixelSize: 11; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            ComboBox { width: 60; model: ["0.5x","1x","2x","4x","8x","16x"]; currentIndex: 1; background: Rectangle { color: "#252830"; radius: 4 } }

                            Text { text: "|"; font.pixelSize: 14; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }

                            Text { text: "10:30:25"; font.pixelSize: 12; color: "#FFB800"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "/ 23:59:59"; font.pixelSize: 11; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }

                            Item { width: 20 }
                            Button { text: "📷 截图"; font.pixelSize: 10; background: Rectangle { color: "#252830"; radius: 4; width: 48; height: 24 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "💾 导出"; font.pixelSize: 10; background: Rectangle { color: "#252830"; radius: 4; width: 48; height: 24 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }

                        // 时间轴Canvas
                        Canvas {
                            id: timelineCanvas
                            width: parent.width; height: 32

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                // 背景刻度
                                ctx.fillStyle = "#1A1D23"
                                ctx.fillRect(0, 0, width, height)

                                // 小时刻度
                                ctx.fillStyle = "#4A4D58"
                                ctx.font = "8px sans-serif"
                                for (var h = 0; h <= 24; h++) {
                                    var x = (h / 24) * width
                                    ctx.fillRect(x, 0, 1, height)
                                    if (h % 2 === 0) {
                                        ctx.fillText(h + ":00", x + 2, height - 2)
                                    }
                                }

                                // 录像段 (绿色条表示有录像)
                                var segments = [
                                    { start: 0, end: 8.5, type: "continuous" },
                                    { start: 8.5, end: 8.75, type: "alarm" },
                                    { start: 8.75, end: 10.5, type: "continuous" },
                                    { start: 10.5, end: 10.7, type: "alarm" },
                                    { start: 10.7, end: 11.5, type: "continuous" },
                                    { start: 11.5, end: 11.8, type: "motion" },
                                    { start: 11.8, end: 24, type: "continuous" }
                                ]
                                for (var s = 0; s < segments.length; s++) {
                                    var seg = segments[s]
                                    var sx = (seg.start / 24) * width
                                    var sw = ((seg.end - seg.start) / 24) * width
                                    ctx.fillStyle = seg.type === "alarm" ? "#FF3D71" :
                                                    seg.type === "motion" ? "#FFB800" : "#00D4AA"
                                    ctx.globalAlpha = seg.type === "continuous" ? 0.6 : 0.9
                                    ctx.fillRect(sx, 6, sw, 14)
                                }
                                ctx.globalAlpha = 1

                                // 当前播放位置
                                var playX = (10.507 / 24) * width
                                ctx.strokeStyle = "#FF3D71"
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(playX, 0)
                                ctx.lineTo(playX, height)
                                ctx.stroke()

                                // 三角标记
                                ctx.fillStyle = "#FF3D71"
                                ctx.beginPath()
                                ctx.moveTo(playX - 4, 0)
                                ctx.lineTo(playX + 4, 0)
                                ctx.lineTo(playX, 5)
                                ctx.closePath()
                                ctx.fill()
                            }
                            Component.onCompleted: requestPaint()

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var pos = (mouseX / width) * 24
                                    console.log("Seek to", pos, "hours")
                                    timelineCanvas.requestPaint()
                                }
                            }
                        }

                        // 图例
                        Row {
                            spacing: 12
                            Text { text: "🟢 连续录像"; font.pixelSize: 9; color: "#00D4AA" }
                            Text { text: "🟡 移动侦测"; font.pixelSize: 9; color: "#FFB800" }
                            Text { text: "🔴 告警录像"; font.pixelSize: 9; color: "#FF3D71" }
                        }
                    }
                }
            }
        }

        // ── 底部: 存储信息 ──
        Rectangle {
            Layout.fillWidth: true; height: 40; color: "#141720"; radius: 8

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16

                Text { text: "💾 本地存储"; font.pixelSize: 12; color: "#E8E8E8" }
                ProgressBar {
                    Layout.fillWidth: true; value: 0.375
                    background: Rectangle { color: "#252830"; radius: 4; height: 8 }
                    contentItem: Rectangle { width: parent.visualPosition * parent.width; height: 8; radius: 4; color: "#3B82F6" }
                }
                Text { text: "12.0 / 32.0 GB"; font.pixelSize: 11; color: "#8B8FA3" }
                Text { text: "|"; font.pixelSize: 14; color: "#252830" }
                Text { text: "录像文件: 1,247"; font.pixelSize: 11; color: "#8B8FA3" }
                Text { text: "|"; font.pixelSize: 14; color: "#252830" }
                Text { text: "保留天数: 15天"; font.pixelSize: 11; color: "#8B8FA3" }
                Text { text: "|"; font.pixelSize: 14; color: "#252830" }
                Text { text: "最早: 2026-05-01"; font.pixelSize: 11; color: "#8B8FA3" }
            }
        }
    }
}
