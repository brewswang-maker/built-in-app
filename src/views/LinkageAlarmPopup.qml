// ========================================================================
// LinkageAlarmPopup.qml — 海康级联动告警弹窗
// 显示: 实时视频联动 + 录像回放联动 + 抓图 + 位置地图 + AI研判 + 操作按钮
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: linkagePopup
    width: 800; height: 520
    color: "transparent"
    flags: Qt.Popup | Qt.FramelessWindowHint

    property var currentAlarm: null
    property var linkageActions: []

    signal confirmed()
    signal falseAlarm()
    signal silenced()

    function showAlarm(alarm, actions) {
        currentAlarm = alarm
        linkageActions = actions || []
        visible = true

        // 严重告警红色边框脉冲
        if (alarm && alarm.severity >= 4) borderAnim.start()
        autoCloseTimer.start()
    }

    function dismiss() { visible = false; autoCloseTimer.stop(); borderAnim.stop() }

    Rectangle {
        anchors.fill: parent; radius: 12; color: "#0D0F12"
        border.color: "#FF3D71"; border.width: 2

        SequentialAnimation on border.color {
            id: borderAnim
            running: false; loops: Animation.Infinite
            ColorAnimation { from: "#FF3D71"; to: "#0D0F12"; duration: 800 }
            ColorAnimation { from: "#0D0F12"; to: "#FF3D71"; duration: 800 }
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            // ═══ 顶栏: 告警摘要 ═══
            Rectangle {
                Layout.fillWidth: true; height: 40; color: "#141720"; radius: 8

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    Rectangle { width: 8; height: 8; radius: 4; color: "#FF3D71"
                        SequentialAnimation on opacity { running: true; loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.2; duration: 600 }
                            NumberAnimation { from: 0.2; to: 1; duration: 600 } } }

                    Text { text: currentAlarm ? "🚨 " + currentAlarm.alarm_type : "🚨 告警"; font.pixelSize: 15; font.bold: true; color: "#FF3D71" }
                    Text { text: currentAlarm ? currentAlarm.location_name || "" : ""; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: currentAlarm ? currentAlarm.device_name || "" : ""; font.pixelSize: 11; color: "#4A4D58" }
                    Item { Layout.fillWidth: true }
                    Text { text: currentAlarm ? currentAlarm.time || "" : ""; font.pixelSize: 11; color: "#4A4D58" }

                    // 倒计时
                    Text { id: countdownText; text: "15s"; font.pixelSize: 11; color: "#FF6B35"; font.bold: true }
                    Button { text: "✕"; font.pixelSize: 14
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#4A4D58" }
                        onClicked: linkagePopup.dismiss()
                    }
                }
            }

            // ═══ 主内容: 视频 + 信息 ═══
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                // ─── 左: 联动视频区域 ───
                Rectangle {
                    Layout.fillHeight: true; Layout.fillWidth: true; color: "#0A0C10"; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; spacing: 0

                        // 视频画面 (联动实时视频)
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true; color: "#000"
                            radius: 8

                            // 模拟视频画面
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, width, height)

                                    // 检测框
                                    if (currentAlarm && currentAlarm.bbox) {
                                        var b = currentAlarm.bbox
                                        ctx.strokeStyle = "#FF3D71"; ctx.lineWidth = 2
                                        ctx.strokeRect(b[0]*width, b[1]*height, (b[2]-b[0])*width, (b[3]-b[1])*height)

                                        // 标签
                                        ctx.fillStyle = "#FF3D71"
                                        ctx.fillRect(b[0]*width, b[1]*height-18, 120, 18)
                                        ctx.fillStyle = "#FFF"; ctx.font = "11px sans-serif"
                                        ctx.fillText(currentAlarm.target_label || "Person", b[0]*width+4, b[1]*height-4)
                                    }

                                    // 叠加事件信息 (CLIENT_OVERLAY_INFO)
                                    ctx.fillStyle = "rgba(0,0,0,0.7)"; ctx.fillRect(0, 0, width, 28)
                                    ctx.fillStyle = "#E8E8E8"; ctx.font = "11px sans-serif"
                                    ctx.fillText(currentAlarm ? "📹 " + currentAlarm.device_name + " | CH" + (currentAlarm.channel_id || "?") : "", 8, 18)

                                    // ROI区域
                                    ctx.strokeStyle = "rgba(0,212,170,0.5)"; ctx.lineWidth = 1; ctx.setLineDash([4,4])
                                    ctx.strokeRect(width*0.1, height*0.1, width*0.8, height*0.8)
                                    ctx.setLineDash([])
                                }
                                Component.onCompleted: requestPaint()
                            }

                            // LIVE标签
                            Rectangle { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8; width: 48; height: 20; radius: 4; color: "#FF3D71"
                                Row { anchors.centerIn: parent; spacing: 2
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#FFF"
                                        SequentialAnimation on opacity { running: true; loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0; duration: 500 }
                                            NumberAnimation { from: 0; to: 1; duration: 500 } } }
                                    Text { text: "LIVE"; font.pixelSize: 9; color: "#FFF"; font.bold: true }
                                }
                            }
                        }

                        // 联动动作标签栏
                        Rectangle {
                            Layout.fillWidth: true; height: 28; color: "#141720"; radius: 4

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 4

                                Text { text: "🔗 联动:"; font.pixelSize: 10; color: "#8B8FA3" }

                                Repeater {
                                    model: [
                                        { icon: "📹", label: "实时视频", active: true },
                                        { icon: "📸", label: "抓图×3", active: true },
                                        { icon: "🔊", label: "声光", active: true },
                                        { icon: "🎥", label: "事件录像", active: true },
                                        { icon: "📍", label: "预置点", active: false }
                                    ]
                                    delegate: Rectangle { width: 68; height: 20; radius: 4
                                        color: modelData.active ? "#0A3A2A" : "#1A1A2A"
                                        Row { anchors.centerIn: parent; spacing: 2
                                            Text { text: modelData.icon; font.pixelSize: 9 }
                                            Text { text: modelData.label; font.pixelSize: 8; color: modelData.active ? "#00D4AA" : "#4A4D58" }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Button { text: "📼 回放"; font.pixelSize: 9
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "🗺️ 地图"; font.pixelSize: 9
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }

                // ─── 右: 告警详情 + AI研判 ───
                Rectangle {
                    Layout.fillHeight: true; Layout.preferredWidth: 280; color: "#141720"; radius: 8

                    ScrollView {
                        anchors.fill: parent; clip: true

                        Column {
                            width: 264; spacing: 6; padding: 8

                            // 事件图片 (联动抓图)
                            Text { text: "📸 联动抓图"; font.pixelSize: 11; color: "#FFB800"; font.bold: true }
                            Rectangle { width: 260; height: 146; color: "#0A0C10"; radius: 6
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, width, height)
                                        // 模拟截图 + 检测框
                                        if (currentAlarm && currentAlarm.bbox) {
                                            var b = currentAlarm.bbox
                                            ctx.strokeStyle = "#FF3D71"; ctx.lineWidth = 2
                                            ctx.strokeRect(b[0]*width, b[1]*height, (b[2]-b[0])*width, (b[3]-b[1])*height)
                                            // 骨架点
                                            ctx.fillStyle = "#00D4AA"
                                            var cx = (b[0]+b[2])/2*width, cy = (b[1]+b[3])/2*height
                                            for (var i = 0; i < 5; i++) {
                                                ctx.beginPath()
                                                ctx.arc(cx + (Math.random()-0.5)*40, cy + (Math.random()-0.5)*60, 3, 0, Math.PI*2)
                                                ctx.fill()
                                            }
                                        }
                                        ctx.fillStyle = "#4A4D58"; ctx.font = "10px sans-serif"
                                        ctx.fillText("Snapshot " + new Date().toLocaleTimeString(), 8, height-8)
                                    }
                                    Component.onCompleted: requestPaint()
                                }
                            }

                            // 告警信息
                            Text { text: "📋 告警信息"; font.pixelSize: 11; color: "#FFB800"; font.bold: true }
                            Grid { columns: 2; columnSpacing: 8; rowSpacing: 2; width: parent.width
                                Text { text: "类型:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? currentAlarm.alarm_type : "-"; font.pixelSize: 10; color: "#E8E8E8" }
                                Text { text: "级别:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? "🔴 严重" : "-"; font.pixelSize: 10; color: "#FF3D71" }
                                Text { text: "通道:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? "CH" + currentAlarm.channel_id : "-"; font.pixelSize: 10; color: "#E8E8E8" }
                                Text { text: "位置:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? currentAlarm.location_name || "-" : "-"; font.pixelSize: 10; color: "#E8E8E8" }
                                Text { text: "置信度:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.confidence * 100).toFixed(1) + "%" : "-"; font.pixelSize: 10; color: "#00D4AA" }
                                Text { text: "目标:"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: currentAlarm ? currentAlarm.target_label || "-" : "-"; font.pixelSize: 10; color: "#E8E8E8" }
                            }

                            Rectangle { height: 1; color: "#252830"; width: parent.width }

                            // AI研判
                            Text { text: "🧠 AI研判"; font.pixelSize: 11; color: "#6C5CE7"; font.bold: true }
                            Rectangle { width: 260; height: 48; color: "#0A0A2A"; radius: 6
                                Text { text: currentAlarm ? currentAlarm.ai_analysis || "人员翻越周界围栏，非动物/树枝干扰" : "分析中..."; font.pixelSize: 10; color: "#B8B8FF"; wrapMode: Text.WordWrap; width: 244; anchors.centerIn: parent } }

                            // 建议处置
                            Text { text: "💡 建议处置"; font.pixelSize: 11; color: "#FFB800"; font.bold: true }
                            Text { text: currentAlarm ? currentAlarm.suggested_action || "派遣安保巡查东围墙区域" : "-"; font.pixelSize: 10; color: "#FFB800" }

                            Rectangle { height: 1; color: "#252830"; width: parent.width }

                            // 联动状态
                            Text { text: "🔗 联动执行状态"; font.pixelSize: 11; color: "#00D4AA"; font.bold: true }
                            Column { spacing: 2; width: parent.width
                                Repeater { model: [
                                    { icon: "📹", text: "实时视频已弹出", status: "done" },
                                    { icon: "📸", text: "抓图 3/3 已完成", status: "done" },
                                    { icon: "🎥", text: "事件录像进行中...", status: "running" },
                                    { icon: "🔊", text: "声光报警触发中 (10s)", status: "running" },
                                    { icon: "📍", text: "云台已转至预置点P1", status: "done" },
                                    { icon: "☁️", text: "已推送至云端", status: "done" }
                                ]
                                delegate: Row { spacing: 4
                                    Text { text: modelData.status === "done" ? "✅" : modelData.status === "running" ? "⏳" : "⬜"; font.pixelSize: 10 }
                                    Text { text: modelData.icon; font.pixelSize: 10 }
                                    Text { text: modelData.text; font.pixelSize: 10; color: modelData.status === "running" ? "#FFB800" : "#8B8FA3" }
                                }}
                            }
                        }
                    }
                }
            }

            // ═══ 底栏: 操作按钮 ═══
            Rectangle {
                Layout.fillWidth: true; height: 44; color: "#141720"; radius: 8

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    Button { text: "✅ 确认告警"; font.pixelSize: 12
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { linkagePopup.confirmed(); linkagePopup.dismiss() }
                    }
                    Button { text: "❌ 误报"; font.pixelSize: 12
                        background: Rectangle { color: "#2A1A1A"; radius: 8; width: 70; height: 32; border.color: "#FF3D71"; border.width: 1 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { linkagePopup.falseAlarm(); linkagePopup.dismiss() }
                    }
                    Button { text: "🔇 静音"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { linkagePopup.silenced(); linkagePopup.dismiss() }
                    }
                    Button { text: "📼 回放"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button { text: "🎙️ 对讲"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    Item { Layout.fillWidth: true }

                    Text { text: "自动关闭: " + autoCloseTimer.countdown + "s"; font.pixelSize: 10; color: "#4A4D58" }
                }
            }
        }
    }

    // 自动关闭计时器
    Timer {
        id: autoCloseTimer
        interval: 1000; repeat: true
        property int countdown: 15
        onTriggered: {
            countdown--
            countdownText.text = countdown + "s"
            if (countdown <= 0) linkagePopup.dismiss()
        }
        onStarted: countdown = 15
    }
}
