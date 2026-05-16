// ========================================================================
// AlarmPopup.qml — 增强版告警弹窗 (符合产品设计文档v5.1 §2.3)
// 新增: 截图区+3秒回放 | AI研判详情 | 建议处置 | 关联告警链 | 威胁等级 | 持续时间 | 声光
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root
    width: 520
    height: 580
    color: "transparent"
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // ── 告警属性 (产品设计文档§2.3完整字段) ──
    property string eventType: ""
    property string level: "warning"       // critical / warning / info
    property string eventTime: ""
    property string location: ""
    property string description: ""
    property real confidence: 0.0
    property string aiVerdict: ""
    property string suggestion: ""
    property string snapshotUrl: ""
    property string relatedAlarm: ""
    property int duration: 0
    property string channelName: ""
    property int targetCount: 0
    property int autoCloseMs: 15000
    property bool soundEnabled: true
    property bool flashEnabled: true

    readonly property var levelColors: ({ "critical": "#FF3D71", "warning": "#FF6B35", "info": "#00D4AA" })
    readonly property var levelLabels: ({ "critical": "🔴 高", "warning": "🟡 中", "info": "🟢 低" })
    readonly property color levelColor: levelColors[level] || levelColors["warning"]

    signal confirmed()
    signal falseAlarm()
    signal muted()
    signal replay()
    signal viewDetail(string alarmId)

    onVisibleChanged: {
        if (visible) {
            autoCloseTimer.start()
            flashTimer.start()
        } else {
            flashTimer.stop()
        }
    }

    // ── 声光告警 (产品文档功能矩阵要求) ──
    Timer { id: flashTimer; interval: 500; running: false; repeat: true
        onTriggered: flashOverlay.visible = !flashOverlay.visible
    }
    Timer { id: autoCloseTimer; interval: root.autoCloseMs; running: false; onTriggered: root.close() }

    // ── 脉冲动画边框 ──
    Rectangle {
        anchors.fill: parent
        radius: 14
        border.color: root.levelColor
        border.width: 3
        color: "#1A1D23"

        SequentialAnimation on border.width {
            running: root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 2; to: 4; duration: 600 }
            NumberAnimation { from: 4; to: 2; duration: 600 }
        }

        // 闪烁遮罩 (critical级别)
        Rectangle {
            id: flashOverlay
            anchors.fill: parent
            radius: 14
            color: "transparent"
            visible: false
            opacity: 0.08

            Rectangle {
                anchors.fill: parent; radius: 14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.level === "critical" ? "#FF3D71" : "transparent" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ═══ Header ═══
            Row {
                width: parent.width; spacing: 10

                Rectangle { width: 5; height: 40; radius: 2; color: root.levelColor }

                Column { spacing: 2; Layout.fillWidth: true
                    Text { text: "🚨 告警! — " + root.eventType; font.pixelSize: 18; font.bold: true; color: "#E8E8E8" }
                    Text { text: root.eventTime + "  |  " + root.channelName; font.pixelSize: 12; color: "#8B8FA3" }
                }

                // 威胁等级
                Rectangle { width: 64; height: 28; radius: 14; color: root.levelColor; opacity: 0.9
                    Text { anchors.centerIn: parent; text: levelLabels[root.level] || "🟡 中"; font.pixelSize: 12; color: "#FFF"; font.bold: true }
                }

                // 关闭按钮
                Rectangle { width: 28; height: 28; radius: 14; color: "#252830"
                    Text { anchors.centerIn: parent; text: "✕"; color: "#8B8FA3"; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: root.close() }
                }
            }

            // ═══ 截图区 (产品设计文档§2.3: 告警截图/3秒回放) ═══
            Rectangle {
                width: parent.width; height: 160; radius: 8; color: "#141720"; clip: true

                Image {
                    anchors.fill: parent
                    source: root.snapshotUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // 无截图时的占位
                Rectangle {
                    anchors.fill: parent; color: "#0D0F12"; visible: !parent.children[0].visible
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            // 模拟检测框
                            ctx.strokeStyle = "#FF3D71"; ctx.lineWidth = 2; ctx.setLineDash([6, 4])
                            ctx.strokeRect(width * 0.3, height * 0.2, width * 0.35, height * 0.55)
                            // 标签
                            ctx.fillStyle = "#FF3D71"; ctx.font = "bold 11px sans-serif"
                            ctx.fillText("人员 97.3%", width * 0.3, height * 0.18)
                            // 骨架关键点
                            var joints = [[0.38,0.35],[0.42,0.35],[0.40,0.48],[0.36,0.48],[0.40,0.62],[0.44,0.62]]
                            ctx.setLineDash([])
                            for (var i = 0; i < joints.length; i++) {
                                ctx.beginPath()
                                ctx.arc(width * joints[i][0], height * joints[i][1], 3, 0, 2 * Math.PI)
                                ctx.fillStyle = "#00D4AA"; ctx.fill()
                            }
                            // 连线
                            ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 1.5
                            ctx.beginPath(); ctx.moveTo(width*0.38,height*0.35); ctx.lineTo(width*0.42,height*0.35); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(width*0.40,height*0.35); ctx.lineTo(width*0.40,height*0.48); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(width*0.40,height*0.48); ctx.lineTo(width*0.36,height*0.48); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(width*0.40,height*0.48); ctx.lineTo(width*0.44,height*0.48); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(width*0.40,height*0.48); ctx.lineTo(width*0.40,height*0.62); ctx.stroke()
                        }
                        Component.onCompleted: requestPaint()
                    }
                    Text { text: "📸 告警快照 — 检测可视化"; color: "#4A4D58"; font.pixelSize: 14; anchors.centerIn: parent }
                }

                // 截图信息叠加
                Row {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 8; spacing: 12
                    Rectangle { height: 22; radius: 4; color: "rgba(0,0,0,0.6)"
                        Text { text: "🎯 目标: 人员 x" + root.targetCount; font.pixelSize: 10; color: "#FFF"; leftPadding: 6; rightPadding: 6; anchors.centerIn: parent }
                    }
                    Rectangle { height: 22; radius: 4; color: "rgba(0,0,0,0.6)"
                        Text { text: "置信度: " + (root.confidence * 100).toFixed(1) + "%"; font.pixelSize: 10; color: "#00D4AA"; leftPadding: 6; rightPadding: 6; anchors.centerIn: parent }
                    }
                    Rectangle { height: 22; radius: 4; color: "rgba(0,0,0,0.6)"
                        Text { text: "📍 " + root.location; font.pixelSize: 10; color: "#FFF"; leftPadding: 6; rightPadding: 6; anchors.centerIn: parent }
                    }
                }

                // 3秒回放按钮
                Button {
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                    text: "▶ 3秒回放"
                    background: Rectangle { color: "rgba(0,0,0,0.7)"; radius: 4; width: 76; height: 24 }
                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.replay()
                }
            }

            // ═══ 告警详情 (产品设计文档§2.3完整字段) ═══
            Rectangle {
                width: parent.width; height: 130; radius: 8; color: "#141720"
                clip: true

                Column {
                    anchors.fill: parent; anchors.margins: 10; spacing: 4

                    Text { text: "📋 告警详情"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Grid {
                        columns: 2; columnSpacing: 20; rowSpacing: 3; width: parent.width
                        Text { text: "事件类型:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: root.eventType; font.pixelSize: 11; color: "#E8E8E8"; font.bold: true }
                        Text { text: "威胁等级:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: levelLabels[root.level] || "🟡 中"; font.pixelSize: 11; color: root.levelColor; font.bold: true }
                        Text { text: "持续时间:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: root.duration + "秒"; font.pixelSize: 11; color: "#E8E8E8" }
                        Text { text: "关联告警:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: root.relatedAlarm || "无"; font.pixelSize: 11; color: root.relatedAlarm ? "#FFB800" : "#4A4D58" }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    // AI研判 (产品设计文档§2.3: "AI研判: 单人翻越围墙，非动物/树枝")
                    Row { spacing: 6; width: parent.width
                        Text { text: "🤖 AI研判:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: root.aiVerdict || "分析中..."; font.pixelSize: 11; color: "#00D4AA"; wrapMode: Text.WordWrap; width: parent.width - 70 }
                    }

                    // 建议处置 (产品设计文档§2.3: "建议: 立即派遣安保巡查")
                    Row { spacing: 6; width: parent.width
                        Text { text: "💡 建议:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: root.suggestion || "请确认告警"; font.pixelSize: 11; color: "#FFB800"; wrapMode: Text.WordWrap; width: parent.width - 70; font.bold: true }
                    }
                }
            }

            // ═══ 进度条 (自动关闭倒计时) ═══
            Canvas {
                width: parent.width; height: 4
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var elapsed = autoCloseTimer.interval > 0 ? 0 : 0
                    ctx.fillStyle = "#252830"; ctx.fillRect(0, 0, width, height)
                    ctx.fillStyle = root.levelColor; ctx.fillRect(0, 0, width * 0.7, height)
                }
                Component.onCompleted: requestPaint()
            }

            // ═══ 操作按钮 (产品设计文档§2.3: 确认/误报/静音/回放) ═══
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Button {
                    text: "✅ 确认"
                    background: Rectangle { color: "#00D4AA"; radius: 8; width: 100; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { root.confirmed(); root.close() }
                }
                Button {
                    text: "❌ 误报"
                    background: Rectangle { color: "#FF6B35"; radius: 8; width: 100; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { root.falseAlarm(); root.close() }
                }
                Button {
                    text: "🔇 静音"
                    background: Rectangle { color: "#252830"; radius: 8; width: 80; height: 38; border.color: "#4A4D58"; border.width: 1 }
                    contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { root.muted(); root.close() }
                }
                Button {
                    text: "📹 回放"
                    background: Rectangle { color: "#252830"; radius: 8; width: 80; height: 38; border.color: "#4A4D58"; border.width: 1 }
                    contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { root.replay(); root.close() }
                }
            }
        }
    }

    // ── 声音提示 ──
    SoundEffect { id: alarmSound; source: "qrc:/sounds/alarm.wav"; volume: root.soundEnabled ? 0.6 : 0 }
    onVisibleChanged: { if (visible && root.soundEnabled && root.level === "critical") alarmSound.play() }

    // ── 监听新告警 ──
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            root.eventType = alarm.type || alarm.alarm_type || ""
            root.level = alarm.level || alarm.severity || "warning"
            root.eventTime = alarm.time || alarm.timestamp || Qt.formatDateTime(new Date(), "HH:mm:ss")
            root.location = alarm.location || alarm.zone || ""
            root.description = alarm.description || ""
            root.confidence = alarm.confidence || 0
            root.aiVerdict = alarm.aiVerdict || alarm.ai_analysis || ""
            root.suggestion = alarm.suggestion || alarm.recommendation || ""
            root.snapshotUrl = alarm.snapshotUrl || alarm.snapshot_url || ""
            root.relatedAlarm = alarm.relatedAlarm || alarm.correlated_alarm || ""
            root.duration = alarm.duration || 0
            root.channelName = alarm.channel || alarm.channelName || ""
            root.targetCount = alarm.targetCount || alarm.target_count || 1
            root.show()
        }
    }
}
