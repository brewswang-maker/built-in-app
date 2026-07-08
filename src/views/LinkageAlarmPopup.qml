// ========================================================================
// LinkageAlarmPopup.qml — 海康级联动告警弹窗
// 显示: 实时视频联动 + 录像回放联动 + 抓图 + AI研判 + 操作按钮
// Controller: linkageController + alarmController
// 零硬编码数据，所有交互通过Controller
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Window {
    id: linkagePopup
    width: 800; height: 520
    color: "transparent"
    flags: Qt.Popup | Qt.FramelessWindowHint

    property string alarmId: ""
    property var currentAlarm: null
    property var linkageActions: []
    property var linkageLogs: []
    property var linkageStats: ({})

    signal confirmed()
    signal falseAlarm()
    signal silenced()

    function showAlarm(alarm, actions) {
        currentAlarm = alarm
        alarmId = alarm.alarm_id || alarm.id || ""
        if (actions) linkageActions = actions
        autoCloseTimer.countdown = 15
        countdownText.text = "15s"
        borderAnim.start()
        autoCloseTimer.start()
        linkagePopup.show()

        // 初始化视频流
        if (alarm.stream_url) {
            alarmVideo.source = alarm.stream_url
            alarmVideo.play()
        } else if (alarm.channel_id) {
            var chId = alarm.channel_id_str || ("" + alarm.channel_id)
            if (chId.length >= 20 && chId.indexOf("gb_") !== 0) {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/gb_" + chId
            } else {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/" + chId
            }
            alarmVideo.play()
        }

        // 刷新联动日志
        if (alarmId) {
            linkageController.refreshLogs(alarmId)
            linkageController.getRuleStats()
        }
    }

    // [FIX 2026-07-09] 移除启动时多余请求: alarmController.refreshAlarms(10) 已在 main.qml:100 调用
    Component.onCompleted: {
        if (alarmId) {
            linkageController.refreshLogs(alarmId)
            linkageController.getRuleStats()
        }
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() {
            var alarms = alarmController.alarms
            for (var i = 0; i < alarms.length; i++) {
                if (alarms[i].id === alarmId) {
                    currentAlarm = alarms[i]
                    break
                }
            }
        }
    }

    Connections {
        target: linkageController
        function onLogsUpdated() {
            linkageLogs = linkageController.logs || []
            linkageStatusRepeater.model = linkageLogs
            // 构建 linkageActions 用于底栏标签
            var actions = []
            for (var i = 0; i < linkageLogs.length; i++) {
                actions.push({
                    icon: linkageLogs[i].icon || "",
                    label: linkageLogs[i].text || linkageLogs[i].action || "-",
                    active: linkageLogs[i].status === "running" || linkageLogs[i].status === "done"
                })
            }
            linkageActions = actions
        }
        function onStatsReceived(stats) {
            linkageStats = stats || {}
        }
    }

    function dismiss() {
        alarmVideo.stop()
        alarmVideo.source = ""
        visible = false
        autoCloseTimer.stop()
        borderAnim.stop()
    }

    onCurrentAlarmChanged: {
        if (currentAlarm && currentAlarm.stream_url) {
            alarmVideo.source = currentAlarm.stream_url
            alarmVideo.play()
        } else if (currentAlarm && currentAlarm.channel_id) {
            var chId = currentAlarm.channel_id_str || ("" + currentAlarm.channel_id)
            if (chId.length >= 20 && chId.indexOf("gb_") !== 0) {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/gb_" + chId
            } else {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/" + chId
            }
            alarmVideo.play()
        } else {
            alarmVideo.stop()
            alarmVideo.source = ""
        }
    }

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

                    Text {
                        text: currentAlarm ? "" + (currentAlarm.alarm_type || currentAlarm.type || "告警") : "告警"
                        font.pixelSize: 15; font.bold: true; color: "#FF3D71"
                    }
                    Text { text: currentAlarm ? (currentAlarm.location_name || currentAlarm.location || "") : ""; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: currentAlarm ? (currentAlarm.device_name || currentAlarm.channel || "") : ""; font.pixelSize: 12; color: "#4A4D58" }
                    Item { Layout.fillWidth: true }
                    Text { text: currentAlarm ? (currentAlarm.time || currentAlarm.timestamp || "") : ""; font.pixelSize: 12; color: "#4A4D58" }

                    // 倒计时
                    Text { id: countdownText; text: "15s"; font.pixelSize: 12; color: "#FF6B35"; font.bold: true }
                    Button { text: "X"; font.pixelSize: 14
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#4A4D58" }
                        onClicked: linkagePopup.dismiss()
                    }
                }
            }

            // ═══ 主内容: 视频 + 信息 ═══
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                // ─── 左: 联动实时视频区域 ───
                Rectangle {
                    Layout.fillHeight: true; Layout.fillWidth: true; color: "#0A0C10"; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; spacing: 0

                        // 视频画面 (等待流)
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true; color: "#000"
                            radius: 8

                            // 实时视频播放 (Qt 6 Video 组件)
                            Video {
                                id: alarmVideo
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectFit
                                autoPlay: false
                                onErrorOccurred: function(error, errorString) {
                                    console.warn("AlarmPopup Video error:", errorString)
                                    videoPlaceholder.visible = true
                                }
                                onPlaybackStateChanged: {
                                    videoPlaceholder.visible = (playbackState !== MediaPlayer.PlayingState)
                                }
                            }

                            // 视频占位 — 等待流
                            Text {
                                id: videoPlaceholder
                                anchors.centerIn: parent
                                text: alarmVideo.source.toString() === "" ? "等待流..." : "加载中..."
                                font.pixelSize: 16; color: "#4A4D58"
                                visible: true
                            }

                            // ROI 叠加占位 (从 currentAlarm.roi)
                            Canvas {
                                anchors.fill: parent
                                visible: currentAlarm && currentAlarm.roi
                                onPaint: {
                                    if (!currentAlarm || !currentAlarm.roi) return
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var roi = currentAlarm.roi
                                    ctx.strokeStyle = "#00D4AA"
                                    ctx.lineWidth = 2
                                    ctx.setLineDash([6, 4])
                                    ctx.beginPath()
                                    for (var i = 0; i < roi.length; i++) {
                                        if (i === 0) ctx.moveTo(roi[i][0] * width, roi[i][1] * height)
                                        else ctx.lineTo(roi[i][0] * width, roi[i][1] * height)
                                    }
                                    ctx.closePath()
                                    ctx.stroke()
                                    ctx.setLineDash([])
                                }
                            }

                            // 通道信息叠加
                            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8; width: 200; height: 28; color: "#B3000000"; radius: 4
                                Text {
                                    text: currentAlarm ? "" + (currentAlarm.device_name || "") + " | CH" + (currentAlarm.channel_id || "?") : ""
                                    font.pixelSize: 12; color: "#E8E8E8"; anchors.centerIn: parent
                                }
                            }

                            // LIVE标签
                            Rectangle { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8; width: 48; height: 20; radius: 4; color: "#FF3D71"
                                Row { anchors.centerIn: parent; spacing: 2
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#FFF"
                                        SequentialAnimation on opacity { running: true; loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0; duration: 500 }
                                            NumberAnimation { from: 0; to: 1; duration: 500 } } }
                                    Text { text: "LIVE"; font.pixelSize: 12; color: "#FFF"; font.bold: true }
                                }
                            }

                            // 检测框叠加 (从 currentAlarm.bbox)
                            Canvas {
                                anchors.fill: parent
                                visible: currentAlarm && currentAlarm.bbox
                                onPaint: {
                                    if (!currentAlarm || !currentAlarm.bbox) return
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var b = currentAlarm.bbox
                                    ctx.strokeStyle = "#FF3D71"; ctx.lineWidth = 2
                                    ctx.strokeRect(b[0]*width, b[1]*height, (b[2]-b[0])*width, (b[3]-b[1])*height)
                                    ctx.fillStyle = "#FF3D71"
                                    ctx.fillRect(b[0]*width, b[1]*height-18, 120, 18)
                                    ctx.fillStyle = "#FFF"; ctx.font = "11px sans-serif"
                                    ctx.fillText(currentAlarm.target_label || "Target", b[0]*width+4, b[1]*height-4)
                                }
                                Component.onCompleted: requestPaint()
                            }
                        }

                        // 联动动作标签栏 (底栏)
                        Rectangle {
                            Layout.fillWidth: true; height: 28; color: "#141720"; radius: 4

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 4

                                Text { text: "联动:"; font.pixelSize: 12; color: "#8B8FA3" }

                                Repeater {
                                    model: linkageActions
                                    delegate: Rectangle { width: 68; height: 20; radius: 4
                                        color: modelData.active ? "#0A3A2A" : "#1A1A2A"
                                        Row { anchors.centerIn: parent; spacing: 2
                                            Text { text: modelData.icon || ""; font.pixelSize: 12 }
                                            Text { text: modelData.label || "-"; font.pixelSize: 8; color: modelData.active ? "#00D4AA" : "#4A4D58" }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Button { text: "回放"; font.pixelSize: 12
                                    background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: {
                                        if (currentAlarm && currentAlarm.channel_id) {
                                            mediaController.startStream(currentAlarm.channel_id, "playback")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── 右: 联动抓图 + 告警信息 + AI研判 ───
                Rectangle {
                    Layout.fillHeight: true; Layout.preferredWidth: 280; color: "#141720"; radius: 8

                    ScrollView {
                        anchors.fill: parent; clip: true

                        Column {
                            width: 264; spacing: 6; padding: 8

                            // 联动抓图区域
                            Text { text: "联动抓图"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                            Rectangle {
                                width: 260; height: 146; color: "#0A0C10"; radius: 6; clip: true
                                // [FIX 2026-06-28] 加载实际快照图片
                                Image {
                                    anchors.fill: parent
                                    source: currentAlarm ? (currentAlarm.snapshot_url || currentAlarm.snapshotUrl || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: currentAlarm && currentAlarm.snapshot_url && status === Image.Ready
                                    cache: false
                                    asynchronous: true
                                }
                                BusyIndicator {
                                    anchors.centerIn: parent
                                    running: currentAlarm && currentAlarm.snapshot_url && parent.children[0].status === Image.Loading
                                    visible: running
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: currentAlarm && currentAlarm.snapshot_url ? "加载中..." : "等待抓图..."
                                    font.pixelSize: 14; color: "#4A4D58"
                                    visible: !currentAlarm || !currentAlarm.snapshot_url || parent.children[0].status !== Image.Ready
                                }
                            }

                            // 告警信息
                            Text { text: "告警信息"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                            Grid { columns: 2; columnSpacing: 8; rowSpacing: 2; width: parent.width
                                Text { text: "类型:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.alarm_type || currentAlarm.type || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                                Text { text: "级别:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text {
                                    text: currentAlarm ? (levelLabels[currentAlarm.level || currentAlarm.severity] || "—") : "-"
                                    font.pixelSize: 12
                                    color: currentAlarm && (currentAlarm.level === "critical" || currentAlarm.severity >= 4) ? "#FF3D71" : "#FFB800"
                                }
                                Text { text: "通道:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? ("CH" + (currentAlarm.channel_id || "-")) : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                                Text { text: "位置:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.location_name || currentAlarm.location || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                                Text { text: "置信度:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? ((currentAlarm.confidence * 100 || 0).toFixed(1) + "%") : "-"; font.pixelSize: 12; color: "#00D4AA" }
                                Text { text: "目标:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.target_label || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                            }

                            readonly property var levelLabels: ({ "critical": "严重", "warning": "警告", "info": "信息" })

                            Rectangle { height: 1; color: "#252830"; width: parent.width }

                            // AI研判
                            Text { text: "AI研判"; font.pixelSize: 12; color: "#6C5CE7"; font.bold: true }
                            Rectangle { width: 260; height: 48; color: "#0A0A2A"; radius: 6
                                Text {
                                    text: currentAlarm ? (currentAlarm.ai_analysis || currentAlarm.aiVerdict || "分析中...") : "分析中..."
                                    font.pixelSize: 12; color: "#B8B8FF"; wrapMode: Text.WordWrap; width: 244; anchors.centerIn: parent
                                }
                            }

                            // 建议处置
                            Text { text: "建议处置"; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                            Text {
                                text: currentAlarm ? (currentAlarm.suggested_action || currentAlarm.suggestion || "-") : "-"
                                font.pixelSize: 12; color: "#FFB800"
                            }

                            Rectangle { height: 1; color: "#252830"; width: parent.width }

                            // 联动执行状态 — 从 linkageController.logs 获取
                            Text { text: "联动执行状态"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                            Column {
                                id: linkageStatusCol
                                spacing: 2; width: parent.width

                                Repeater {
                                    id: linkageStatusRepeater
                                    model: linkageLogs

                                    delegate: Row { spacing: 4
                                        Text { text: modelData.status === "done" ? "OK" : modelData.status === "running" ? "..." : "-"; font.pixelSize: 12 }
                                        Text { text: modelData.icon || ""; font.pixelSize: 12 }
                                        Text { text: modelData.text || modelData.action || "-"; font.pixelSize: 12; color: modelData.status === "running" ? "#FFB800" : "#8B8FA3" }
                                    }
                                }
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

                    Button { text: "确认告警"; font.pixelSize: 12
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.id) {
                                alarmController.confirmAlarm(currentAlarm.id)
                            }
                            linkagePopup.confirmed()
                            linkagePopup.dismiss()
                        }
                    }
                    Button { text: "误报"; font.pixelSize: 12
                        background: Rectangle { color: "#2A1A1A"; radius: 8; width: 70; height: 32; border.color: "#FF3D71"; border.width: 1 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.id) {
                                alarmController.markFalseAlarm(currentAlarm.id)
                            }
                            linkagePopup.falseAlarm()
                            linkagePopup.dismiss()
                        }
                    }
                    Button { text: "静音"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.id) {
                                alarmController.handleAlarm(currentAlarm.id, "mute")
                            }
                            linkagePopup.silenced()
                            linkagePopup.dismiss()
                        }
                    }
                    Button { text: "回放"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.channel_id) {
                                mediaController.startStream(currentAlarm.channel_id, "playback")
                            }
                        }
                    }
                    Button { text: "对讲"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.channel_id) {
                                mediaController.startStream(currentAlarm.channel_id, "talk")
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text { text: "自动关闭: " + autoCloseTimer.countdown + "s"; font.pixelSize: 12; color: "#4A4D58" }
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
        Component.onCompleted: countdown = 15
    }
}
