// ========================================================================
// StreamManagementView.qml — 流媒体管理 (推拉流 + 码率监控 + 转码)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: streamView

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "📺 流媒体管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: "ZLMediaKit: 运行中"; font.pixelSize: 12; color: "#00D4AA" }
            Button { text: "🔄 刷新"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 码率实时图表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 300
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📊 码率监控 (实时)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: bitrateChart
                    width: parent.width - 24; height: 200
                    property var data: []

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                        // Y轴标签
                        ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                        ctx.fillText("8Mbps", 2, 12)
                        ctx.fillText("4Mbps", 2, h/2)
                        ctx.fillText("0", 2, h-4)

                        // 网格
                        ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                        for (var i = 0; i <= 4; i++) { ctx.beginPath(); ctx.moveTo(0, h*i/4); ctx.lineTo(w, h*i/4); ctx.stroke() }

                        // 多条码率线
                        var streams = [
                            { data: data.map(function(d){return d.ch1}), color: "#3B82F6", name: "CH1" },
                            { data: data.map(function(d){return d.ch2}), color: "#00D4AA", name: "CH2" },
                            { data: data.map(function(d){return d.ch3}), color: "#FFB800", name: "CH3" }
                        ]
                        for (var s = 0; s < streams.length; s++) {
                            ctx.strokeStyle = streams[s].color; ctx.lineWidth = 1.5
                            ctx.beginPath()
                            for (var i = 0; i < streams[s].data.length; i++) {
                                var x = (i / 60) * w
                                var y = h - (streams[s].data[i] / 8) * h
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                        }
                    }

                    Timer {
                        interval: 200; running: true; repeat: true
                        onTriggered: {
                            bitrateChart.data.push({
                                ch1: 5.5 + Math.random() * 1.5,
                                ch2: 3.2 + Math.random() * 0.8,
                                ch3: 2.0 + Math.random() * 0.5
                            })
                            if (bitrateChart.data.length > 60) bitrateChart.data.shift()
                            bitrateChart.requestPaint()
                        }
                    }
                }

                // 图例
                Row { spacing: 12
                    Text { text: "● CH1 主码流"; font.pixelSize: 10; color: "#3B82F6" }
                    Text { text: "● CH2 子码流"; font.pixelSize: 10; color: "#00D4AA" }
                    Text { text: "● CH3 三码流"; font.pixelSize: 10; color: "#FFB800" }
                }

                // 服务器统计
                Rectangle { width: parent.width - 24; height: 120; color: "#0D0F12"; radius: 6
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Text { text: "ZLMediaKit 统计"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 8; Text { text: "活跃流:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "12"; font.pixelSize: 11; color: "#00D4AA"; font.bold: true } }
                        Row { spacing: 8; Text { text: "总带宽:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "180 Mbps"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "WebRTC会话:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "3"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "HTTP-FLV:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "5"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "WS-FLV:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "4"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "RTSP拉流:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "12"; font.pixelSize: 11; color: "#E8E8E8" } }
                    }
                }
            }
        }

        // ── 右侧: 流列表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "活跃流列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { stream: "rtp://34020000001320000001"; src: "海康IPC-01 CH1"; codec: "H.265"; resolution: "3840x2160"; bitrate: "6.1Mbps"; fps: 25; viewers: 3; protocol: "GB28181" }
                        ListElement { stream: "rtp://34020000001320000001"; src: "海康IPC-01 CH2"; codec: "H.264"; resolution: "1920x1080"; bitrate: "2.1Mbps"; fps: 15; viewers: 1; protocol: "GB28181" }
                        ListElement { stream: "rtsp://192.168.1.101:554/stream1"; src: "大华IPC-02 CH1"; codec: "H.265"; resolution: "2560x1440"; bitrate: "4.2Mbps"; fps: 25; viewers: 2; protocol: "ONVIF" }
                        ListElement { stream: "rtp://34020000001320000003"; src: "宇视NVR-01 CH1"; codec: "H.265"; resolution: "3840x2160"; bitrate: "5.8Mbps"; fps: 25; viewers: 1; protocol: "GB28181" }
                        ListElement { stream: "rtp://34020000001320000003"; src: "宇视NVR-01 CH2"; codec: "H.264"; resolution: "1920x1080"; bitrate: "2.0Mbps"; fps: 15; viewers: 0; protocol: "GB28181" }
                        ListElement { stream: "rtsp://192.168.1.103:554/live"; src: "海康IPC-03 CH1"; codec: "H.265"; resolution: "2560x1440"; bitrate: "3.8Mbps"; fps: 25; viewers: 2; protocol: "RTSP" }
                        ListElement { stream: "rtp://34020000001320000006"; src: "海康球机-08 CH1"; codec: "H.264"; resolution: "1920x1080"; bitrate: "2.2Mbps"; fps: 25; viewers: 0; protocol: "EHOME" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 56; color: "#141720"; radius: 6

                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2

                            Row {
                                spacing: 8; width: parent.width
                                Text { text: model.src; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                Rectangle { width: 40; height: 14; radius: 3; color: "#1A2A3A"
                                    Text { text: model.protocol; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                                }
                                Rectangle { width: 30; height: 14; radius: 3; color: "#1A3A2A"
                                    Text { text: model.codec; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent }
                                }
                                Text { text: model.resolution; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: model.bitrate; font.pixelSize: 10; color: "#FFB800" }
                                Text { text: model.fps + "fps"; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "👁 " + model.viewers; font.pixelSize: 10; color: "#8B8FA3" }

                                Item { width: 10 }

                                Button { text: "预览"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "断开"; font.pixelSize: 9; background: Rectangle { color: "#FF3D71"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                            Text { text: model.stream; font.pixelSize: 9; color: "#4A4D58"; elide: Text.ElideMiddle; width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
