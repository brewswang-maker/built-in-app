// ========================================================================
// VideoGridView.qml — 增强版视频预览 (对标Web端LiveView 474行)
// 新增: PTZ完整面板(预置位+速度) | WebRTC播放 | 截图 | 全屏 | 对讲 | 双击全屏 | 通道列表
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 5.15

Item {
    id: videoGridPage

    property int activeSlot: -1
    property bool isFullscreen: false

    // ═══ 工具栏 ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8

            Text { text: "📹 视频预览"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            // 通道名
            Text {
                text: activeSlot >= 0 && activeSlot < deviceController.devices.length ?
                    deviceController.devices[activeSlot].device_name || "" : ""
                font.pixelSize: 13; color: "#3B82F6"
                visible: text !== ""
            }

            Item { Layout.fillWidth: true }

            // 宫格切换
            Row { spacing: 4
                Repeater {
                    model: [1, 4, 9, 16]
                    delegate: Button {
                        width: 40; height: 32; text: modelData === 1 ? "单" : modelData + ""
                        font.pixelSize: 12; highlighted: mediaController.currentLayout === modelData
                        onClicked: mediaController.setLayout(modelData)
                        background: Rectangle { color: parent.highlighted ? "#00D4AA" : "#252830"; radius: 4 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: parent.highlighted ? "#0D0F12" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: "#252830" }

            // 操作按钮
            Button { text: "📷 截图"; font.pixelSize: 11; onClicked: mediaController.snapshot(activeSlot >= 0 ? activeSlot : 0)
                background: Rectangle { color: "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button { text: mediaController.isRecording ? "⏹ 停止" : "⏺ 录像"; font.pixelSize: 11
                onClicked: mediaController.isRecording ? mediaController.stopRecording(activeSlot) : mediaController.startRecording(activeSlot)
                background: Rectangle { color: mediaController.isRecording ? "#FF3D71" : "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: mediaController.isRecording ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button { text: "🎤 对讲"; font.pixelSize: 11
                background: Rectangle { color: "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: mediaController.startTalk(activeSlot)
            }
            Button { text: "⛶ 全屏"; font.pixelSize: 11
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    isFullscreen = !isFullscreen
                    if (isFullscreen && activeSlot >= 0) mediaController.setLayout(1)
                    else mediaController.setLayout(4)
                }
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 4; spacing: 4

        // ═══ 左侧: 通道列表 (多宫格时隐藏) ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 180; color: "#141720"; radius: 8
            visible: mediaController.currentLayout === 1

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 4

                Text { text: "📡 通道列表"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 16; height: parent.height - 100; spacing: 2; clip: true
                    model: deviceController.devices

                    delegate: Rectangle {
                        width: ListView.view.width; height: 36; radius: 4
                        color: videoGridPage.activeSlot === index ? "#1A3A2A" : "#0D0F12"
                        border.color: videoGridPage.activeSlot === index ? "#00D4AA" : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData.status === "online" ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.device_name || ("CH" + (index + 1)); font.pixelSize: 11; color: videoGridPage.activeSlot === index ? "#00D4AA" : "#E8E8E8"; width: 100; elide: Text.ElideRight }
                            Text { text: modelData.status === "online" ? "●" : "○"; font.pixelSize: 10; color: modelData.status === "online" ? "#00D4AA" : "#4A4D58" }
                        }
                        MouseArea { anchors.fill: parent; onClicked: videoGridPage.activeSlot = index }
                    }
                }

                // 搜索
                TextField {
                    width: parent.width - 16; height: 28; placeholderText: "搜索通道..."
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 11
                    background: Rectangle { color: "#252830"; radius: 4 }
                }
            }
        }

        // ═══ 中央: 视频网格 ═══
        Grid {
            id: grid
            Layout.fillHeight: true; Layout.fillWidth: true; spacing: 2

            property int cols: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
            property int rows: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
            columns: cols

            Repeater {
                model: mediaController.currentLayout

                VideoTile {
                    width: grid.width / grid.cols - 2
                    height: grid.height / grid.rows - 2
                    deviceId: index < deviceController.devices.length ? deviceController.devices[index].device_id || "" : ""
                    channelName: index < deviceController.devices.length ? deviceController.devices[index].device_name || ("Camera_" + (index + 1)) : ("Camera_" + (index + 1))
                    status: index < deviceController.devices.length ? deviceController.devices[index].status || "offline" : "offline"
                    algorithmTag: index < deviceController.devices.length ? deviceController.devices[index].algorithm || "" : ""
                    active: videoGridPage.activeSlot === index

                    // 双击全屏
                    MouseArea {
                        anchors.fill: parent; z: 10; propagateComposedEvents: true
                        onDoubleClicked: { videoGridPage.activeSlot = index; mediaController.setLayout(1); videoGridPage.isFullscreen = true }
                        onClicked: { videoGridPage.activeSlot = index; mouse.accepted = false }
                    }
                }
            }
        }

        // ═══ 右侧: PTZ控制面板 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 170; color: "#141720"; radius: 8
            visible: mediaController.currentLayout === 1 && activeSlot >= 0

            ScrollView {
                anchors.fill: parent; clip: true

                Column {
                    width: 154; spacing: 8; padding: 8

                    Text { text: "🎯 云台控制"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; width: parent.width }

                    // PTZ方向盘 (Canvas绘制)
                    Canvas {
                        id: ptzCanvas
                        width: 140; height: 140
                        property string activeDir: ""

                        onPaint: {
                            var ctx = getContext("2d")
                            var cx = 70, cy = 70, r = 55
                            ctx.clearRect(0, 0, width, height)

                            // 外圆
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.fillStyle = "#0D0F12"; ctx.fill()
                            ctx.strokeStyle = "#252830"; ctx.lineWidth = 2; ctx.stroke()

                            // 方向按钮 (8个扇区)
                            var dirs = ["up", "right_up", "right", "right_down", "down", "left_down", "left", "left_up"]
                            var labels = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
                            for (var i = 0; i < 8; i++) {
                                var angle = (i / 8) * 2 * Math.PI - Math.PI / 2
                                var bx = cx + Math.cos(angle) * 38
                                var by = cy + Math.sin(angle) * 38
                                ctx.beginPath(); ctx.arc(bx, by, 14, 0, 2 * Math.PI)
                                ctx.fillStyle = activeDir === dirs[i] ? "#3B82F6" : "#252830"; ctx.fill()
                                ctx.fillStyle = activeDir === dirs[i] ? "#FFF" : "#8B8FA3"
                                ctx.font = "14px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"
                                ctx.fillText(labels[i], bx, by)
                            }

                            // 中心
                            ctx.beginPath(); ctx.arc(cx, cy, 16, 0, 2 * Math.PI)
                            ctx.fillStyle = "#1A3A2A"; ctx.fill()
                            ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 1.5; ctx.stroke()
                            ctx.fillStyle = "#00D4AA"; ctx.font = "10px sans-serif"
                            ctx.fillText("OK", cx, cy)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: {
                                var cx = 70, cy = 70
                                var dx = mouseX - cx, dy = mouseY - cy
                                var dist = Math.sqrt(dx * dx + dy * dy)
                                if (dist < 16) { ptzCanvas.activeDir = "ok" }
                                else if (dist < 55) {
                                    var angle = Math.atan2(dy, dx) * 180 / Math.PI
                                    if (angle > -22.5 && angle <= 22.5) ptzCanvas.activeDir = "right"
                                    else if (angle > 22.5 && angle <= 67.5) ptzCanvas.activeDir = "right_down"
                                    else if (angle > 67.5 && angle <= 112.5) ptzCanvas.activeDir = "down"
                                    else if (angle > 112.5 && angle <= 157.5) ptzCanvas.activeDir = "left_down"
                                    else if (angle > 157.5 || angle <= -157.5) ptzCanvas.activeDir = "left"
                                    else if (angle > -157.5 && angle <= -112.5) ptzCanvas.activeDir = "left_up"
                                    else if (angle > -112.5 && angle <= -67.5) ptzCanvas.activeDir = "up"
                                    else ptzCanvas.activeDir = "right_up"
                                    ptzCanvas.requestPaint()
                                }
                            }
                            onPressed: {
                                if (ptzCanvas.activeDir === "ok") mediaController.ptzControl(activeSlot, "auto_scan", 0.5)
                                else mediaController.ptzControl(activeSlot, ptzCanvas.activeDir, ptzSpeed.value)
                            }
                            onReleased: { ptzCanvas.activeDir = ""; ptzCanvas.requestPaint() }
                        }
                    }

                    // PTZ速度
                    Text { text: "速度: " + ptzSpeed.value.toFixed(1); font.pixelSize: 10; color: "#8B8FA3" }
                    Slider { id: ptzSpeed; width: 140; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.1 }

                    // 变倍/焦距/光圈
                    Text { text: "变倍 Zoom"; font.pixelSize: 10; color: "#8B8FA3" }
                    Row { spacing: 4
                        Button { width: 60; height: 26; text: "➖"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "zoom_out", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { width: 60; height: 26; text: "➕"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "zoom_in", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Text { text: "焦距 Focus"; font.pixelSize: 10; color: "#8B8FA3" }
                    Row { spacing: 4
                        Button { width: 60; height: 26; text: "近"; font.pixelSize: 11
                            onClicked: mediaController.ptzControl(activeSlot, "focus_near", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { width: 60; height: 26; text: "远"; font.pixelSize: 11
                            onClicked: mediaController.ptzControl(activeSlot, "focus_far", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }

                    // 预置位
                    Text { text: "📌 预置位"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Grid {
                        columns: 3; spacing: 4
                        Repeater {
                            model: 6
                            delegate: Button {
                                width: 42; height: 28; text: "P" + (index + 1)
                                font.pixelSize: 10
                                onClicked: mediaController.ptzGotoPreset(activeSlot, index + 1)
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onPressAndHold: mediaController.ptzSetPreset(activeSlot, index + 1)
                            }
                        }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }

                    // 轮巡
                    Text { text: "🔄 轮巡"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Row { spacing: 4
                        Button { text: "▶ 开始"; font.pixelSize: 10
                            onClicked: mediaController.startPatrol(activeSlot)
                            background: Rectangle { color: "#00D4AA"; radius: 4; width: 50; height: 26 }
                            contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { text: "⏹ 停止"; font.pixelSize: 10
                            onClicked: mediaController.stopPatrol(activeSlot)
                            background: Rectangle { color: "#FF3D71"; radius: 4; width: 50; height: 26 }
                            contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }
    }
}
