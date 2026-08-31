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
    width: 760; height: 480
    color: "transparent"
    // [UX 2026-08-31] 原 Qt.Popup 特性: 点击窗口外任意区域/按 ESC 都会自动关闭,
    //   值守人员查看告警时误点外部即丢内容。改为普通无边框置顶窗口:
    //   只能通过右上角 ✕ / 确认 / 误报 / 静音按钮或 60s 倒计时主动关闭,
    //   与 Web 端 AlarmPopup 关闭策略对齐
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property string alarmId: ""
    property var currentAlarm: null
    property var linkageActions: []
    property var linkageLogs: []
    property var linkageStats: ({})
    property var alarmQueue: []         // 队列(分页用): [{id, alarm, ...}, ...]
    property int queueIdx: -1
    property string noteText: ""        // 处理备注
    property int autoCloseSec: 60       // 默认60秒 (与 Web 截图一致)

    readonly property var levelGradient: ({
        "critical": ["#F5365C", "#F9A825"],
        "high":     ["#FF6B35", "#FFB800"],
        "medium":   ["#3294ED", "#00D4AA"],
        "low":      ["#67C23A", "#409EFF"],
        "info":     ["#909399", "#67C23A"]
    })

    function alarmLevel(a) {
        var lv = a && (a.level || a.severity)
        if (lv === undefined || lv === null) return "medium"
        if (typeof lv === "number") {
            if (lv >= 5) return "critical"
            if (lv >= 4) return "high"
            if (lv >= 3) return "medium"
            return "low"
        }
        lv = String(lv).toLowerCase()
        if (lv === "critical") return "critical"
        if (lv === "high") return "high"
        if (lv === "medium" || lv === "warning" || lv === "mid") return "medium"
        if (lv === "low") return "low"
        if (lv === "info") return "info"
        return "medium"
    }
    function gradientFor(a) {
        var lv = alarmLevel(a)
        return levelGradient[lv] || levelGradient.medium
    }
    function formatAlarmTime(a) {
        var t = a ? (a.created_at || a.timestamp || a.time) : null
        if (!t) return "-"
        try {
            var d = (typeof t === "string" || t > 1e12) ? new Date(t) : new Date(t * 1000)
            if (isNaN(d.getTime())) return String(t)
            var pad = function (n) { return n < 10 ? "0" + n : "" + n }
            return d.getFullYear() + "/" + pad(d.getMonth() + 1) + "/" + pad(d.getDate()) + " " +
                   pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
        } catch (e) { return String(t) }
    }
    function levelLabel(a) {
        var lv = alarmLevel(a)
        return {critical:"严重", high:"高", medium:"中", low:"低", info:"信息"}[lv] || lv
    }
    function levelColor(lv) {
        return {critical:"#F56C6C", high:"#E6A23C", medium:"#409EFF", low:"#67C23A", info:"#909399"}[lv] || "#909399"
    }

    signal confirmed()
    signal falseAlarm()
    signal silenced()

    function _isHighLevel(a) {
        // [FIX v7.6 2026-08-26] 优先级防覆盖: 与 Web useAlarmPopup.HIGH_PRIORITY 对齐
        //   critical/high 不被中/低优先级告警覆盖 (避免高优先级告警被后续低优先级 "被顶掉")
        if (!a) return false
        var lv = alarmLevel(a)
        return lv === "critical" || lv === "high"
    }

    function showAlarm(alarm, actions) {
        // [FIX v7.6 2026-08-26] 优先级防覆盖: 当前弹窗级别 >= high 时, 新告警仅入队列不覆盖
        if (linkagePopup.visible && currentAlarm && _isHighLevel(currentAlarm)
            && !_isHighLevel(alarm)) {
            qInfo && console.log("[LinkageAlarmPopup] skip overwrite: current="
                + alarmLevel(currentAlarm) + ", new=" + alarmLevel(alarm))
            // 仍推入队列供用户后续查看
            if (alarm && alarm.id) {
                var exists2 = -1
                for (var k = 0; k < alarmQueue.length; k++) {
                    if (alarmQueue[k].id === alarm.id) { exists2 = k; break }
                }
                if (exists2 < 0) alarmQueue.push(alarm)
            }
            return
        }

        currentAlarm = alarm
        alarmId = alarm.alarm_id || alarm.id || ""
        if (actions) linkageActions = actions
        // 推入队列
        if (alarm && alarm.id) {
            var exists = -1
            for (var i = 0; i < alarmQueue.length; i++) {
                if (alarmQueue[i].id === alarm.id) { exists = i; break }
            }
            if (exists < 0) alarmQueue.push(alarm)
            for (var j = 0; j < alarmQueue.length; j++) {
                if (alarmQueue[j].id === alarm.id) { queueIdx = j; break }
            }
        }
        autoCloseTimer.countdown = autoCloseSec
        countdownText.text = autoCloseSec + "s"
        headerBar.requestPaint()
        borderAnim.start()
        // [FIX v7.6 2026-08-26] restart() 重置倒计时 — 首次 showAlarm 才启, dismiss 才会 stop
        autoCloseTimer.restart()
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

    function refreshForCurrent() {
        // 切换队列告警后: 重新拉视频 + 刷新联动日志
        if (alarmId) {
            linkageController.refreshLogs(alarmId)
            linkageController.getRuleStats()
        }
        // 重新计时
        autoCloseTimer.countdown = autoCloseSec
        countdownText.text = autoCloseSec + "s"
        borderAnim.restart()
        autoCloseTimer.restart()
        headerBar.requestPaint()
        // 重新拉视频流
        if (currentAlarm && currentAlarm.channel_id) {
            var chId = currentAlarm.channel_id_str || ("" + currentAlarm.channel_id)
            if (chId.length >= 20 && chId.indexOf("gb_") !== 0) {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/gb_" + chId
            } else {
                alarmVideo.source = "rtsp://127.0.0.1:554/rtp/" + chId
            }
            alarmVideo.play()
        }
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
        anchors.fill: parent; radius: 6; color: "#FFFFFF"
        border.color: linkagePopup.alarmLevel(currentAlarm) === "critical" ? "#F93A55" : "#E4E7ED"
        border.width: 2

        // ═══ 告警闪烁边框 (与 Web 截图保持一致) ═══
        SequentialAnimation on border.color {
            id: borderAnim
            running: false; loops: Animation.Infinite
            ColorAnimation { from: "#F56C6C"; to: "#FFFFFF"; duration: 800 }
            ColorAnimation { from: "#FFFFFF"; to: "#F56C6C"; duration: 800 }
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 0; spacing: 0

            // ═══ 顶栏: 告警摘要 (渐变色背景, 1:1 对齐 Web 截图) ═══
            Rectangle {
                id: headerBar
                Layout.fillWidth: true; Layout.preferredHeight: 38
                radius: 0
                // 渐变背景, 按告警级别动态变色
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: linkagePopup.gradientFor(currentAlarm)[0] }
                    GradientStop { position: 1.0; color: linkagePopup.gradientFor(currentAlarm)[1] }
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                    // 闪烁圆点 (严重告警时闪烁)
                    Rectangle {
                        id: criticalDot
                        width: 8; height: 8; radius: 4
                        color: "#FFFFFF"
                        visible: linkagePopup.alarmLevel(currentAlarm) === "critical"
                        SequentialAnimation on opacity { running: criticalDot.visible; loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.2; duration: 600 }
                            NumberAnimation { from: 0.2; to: 1; duration: 600 } }
                    }
                    // 告警类型
                    Text {
                        text: currentAlarm ? "" + (currentAlarm.alarm_type || currentAlarm.type || "告警") : "告警"
                        font.pixelSize: 15; font.bold: true; color: "#FFFFFF"
                    }
                    // 设备信息
                    Text {
                        text: currentAlarm
                            ? ((currentAlarm.device_name ? currentAlarm.device_name + " | " : "")
                               + (currentAlarm.channel_name || currentAlarm.channel || ""))
                            : ""
                        font.pixelSize: 12; color: "#FFFFFF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Item { Layout.fillWidth: true }

                    // 队列分页 N/M
                    Row {
                        visible: alarmQueue.length > 1
                        spacing: 4
                        Text {
                            text: (queueIdx + 1) + "/" + alarmQueue.length
                            font.pixelSize: 12; color: "#AADDFF"; anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: prevBtn
                            text: "‹"; font.pixelSize: 18; color: prevMa.containsMouse ? "#FFFFFF" : "#AADDFF"
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: prevMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: queueIdx > 0
                                onClicked: {
                                    if (queueIdx > 0) {
                                        queueIdx--
                                        var a = alarmQueue[queueIdx]
                                        currentAlarm = a
                                        alarmId = a.alarm_id || a.id || ""
                                        linkagePopup.refreshForCurrent()
                                    }
                                }
                            }
                        }
                        Text {
                            id: nextBtn
                            text: "›"; font.pixelSize: 18; color: nextMa.containsMouse ? "#FFFFFF" : "#AADDFF"
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: nextMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: queueIdx >= 0 && queueIdx < alarmQueue.length - 1
                                onClicked: {
                                    if (queueIdx >= 0 && queueIdx < alarmQueue.length - 1) {
                                        queueIdx++
                                        var a = alarmQueue[queueIdx]
                                        currentAlarm = a
                                        alarmId = a.alarm_id || a.id || ""
                                        linkagePopup.refreshForCurrent()
                                    }
                                }
                            }
                        }
                    }
                    // 倒计时
                    Text {
                        id: countdownText
                        text: "60s"; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    // 关闭按钮 (亮青色, 与截图一致)
                    Item {
                        width: 22; height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "✕"; font.pixelSize: 16; color: "#00FFFF"
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: linkagePopup.dismiss()
                        }
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
                                    ctx.strokeStyle = "#67C23A"
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
                                    font.pixelSize: 12; color: "#303133"; anchors.centerIn: parent
                                }
                            }

                            // LIVE标签
                            Rectangle { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8; width: 48; height: 20; radius: 4; color: "#F56C6C"
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
                                    ctx.strokeStyle = "#F56C6C"; ctx.lineWidth = 2
                                    ctx.strokeRect(b[0]*width, b[1]*height, (b[2]-b[0])*width, (b[3]-b[1])*height)
                                    ctx.fillStyle = "#F56C6C"
                                    ctx.fillRect(b[0]*width, b[1]*height-18, 120, 18)
                                    ctx.fillStyle = "#FFF"; ctx.font = "11px sans-serif"
                                    ctx.fillText(currentAlarm.target_label || "Target", b[0]*width+4, b[1]*height-4)
                                }
                                Component.onCompleted: requestPaint()
                            }
                        }

                        // 联动动作标签栏 (底栏)
                        Rectangle {
                            Layout.fillWidth: true; height: 28; color: "#FFFFFF"; radius: 4

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 4

                                Text { text: "联动:"; font.pixelSize: 12; color: "#909399" }

                                Repeater {
                                    model: linkageActions
                                    delegate: Rectangle { width: 68; height: 20; radius: 4
                                        color: modelData.active ? "#0A3A2A" : "#1A1A2A"
                                        Row { anchors.centerIn: parent; spacing: 2
                                            Text { text: modelData.icon || ""; font.pixelSize: 12 }
                                            Text { text: modelData.label || "-"; font.pixelSize: 8; color: modelData.active ? "#67C23A" : "#4A4D58" }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Button { text: "回放"; font.pixelSize: 12
                                    background: Rectangle { color: "#F5F7FA"; radius: 4; width: 40; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#909399"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                    Layout.fillHeight: true; Layout.preferredWidth: 280; color: "#FFFFFF"; radius: 8

                    ScrollView {
                        anchors.fill: parent; clip: true

                        Column {
                            width: 264; spacing: 6; padding: 8

                            // 联动抓图区域
                            Text { text: "联动抓图"; font.pixelSize: 12; color: "#E6A23C"; font.bold: true }
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
                            Text { text: "告警信息"; font.pixelSize: 12; color: "#E6A23C"; font.bold: true }
                            Grid { columns: 2; columnSpacing: 8; rowSpacing: 2; width: parent.width
                                Text { text: "类型:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.alarm_type || currentAlarm.type || "-") : "-"; font.pixelSize: 12; color: "#303133" }
                                Text { text: "级别:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text {
                                    text: currentAlarm ? (levelLabels[currentAlarm.level || currentAlarm.severity] || "—") : "-"
                                    font.pixelSize: 12
                                    color: currentAlarm && (currentAlarm.level === "critical" || currentAlarm.severity >= 4) ? "#F56C6C" : "#E6A23C"
                                }
                                Text { text: "通道:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? ("CH" + (currentAlarm.channel_id || "-")) : "-"; font.pixelSize: 12; color: "#303133" }
                                Text { text: "位置:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.location_name || currentAlarm.location || "-") : "-"; font.pixelSize: 12; color: "#303133" }
                                Text { text: "置信度:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? ((currentAlarm.confidence * 100 || 0).toFixed(1) + "%") : "-"; font.pixelSize: 12; color: "#67C23A" }
                                Text { text: "目标:"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: currentAlarm ? (currentAlarm.target_label || "-") : "-"; font.pixelSize: 12; color: "#303133" }
                            }

                            readonly property var levelLabels: ({ "critical": "严重", "warning": "警告", "info": "信息" })

                            // 处理备注 (与 Web 截图对齐)
                            Text { text: "处理备注"; font.pixelSize: 12; color: "#606266"; font.bold: true }
                            Rectangle {
                                width: 260; height: 80; color: "#FFFFFF"
                                border.color: noteTa.activeFocus ? "#409EFF" : "#DCDFE6"
                                radius: 4
                                TextArea {
                                    id: noteTa
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    wrapMode: TextArea.Wrap
                                    font.pixelSize: 12
                                    color: "#303133"
                                    background: null
                                    onTextChanged: linkagePopup.noteText = text
                                }
                                Text {
                                    visible: noteTa.text.length === 0 && !noteTa.activeFocus
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    text: "请输入处理备注"
                                    font.pixelSize: 12
                                    color: "#C0C4CC"
                                    verticalAlignment: Text.AlignTop
                                }
                            }

                            Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }

                            // AI研判
                            Text { text: "AI研判"; font.pixelSize: 12; color: "#6C5CE7"; font.bold: true }
                            Rectangle { width: 260; height: 48; color: "#0A0A2A"; radius: 6
                                Text {
                                    text: currentAlarm ? (currentAlarm.ai_analysis || currentAlarm.aiVerdict || "分析中...") : "分析中..."
                                    font.pixelSize: 12; color: "#B8B8FF"; wrapMode: Text.WordWrap; width: 244; anchors.centerIn: parent
                                }
                            }

                            // 建议处置
                            Text { text: "建议处置"; font.pixelSize: 12; color: "#E6A23C"; font.bold: true }
                            Text {
                                text: currentAlarm ? (currentAlarm.suggested_action || currentAlarm.suggestion || "-") : "-"
                                font.pixelSize: 12; color: "#E6A23C"
                            }

                            Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }

                            // 联动执行状态 — 从 linkageController.logs 获取
                            Text { text: "联动执行状态"; font.pixelSize: 12; color: "#67C23A"; font.bold: true }
                            Column {
                                id: linkageStatusCol
                                spacing: 2; width: parent.width

                                Repeater {
                                    id: linkageStatusRepeater
                                    model: linkageLogs

                                    delegate: Row { spacing: 4
                                        Text { text: modelData.status === "done" ? "OK" : modelData.status === "running" ? "..." : "-"; font.pixelSize: 12 }
                                        Text { text: modelData.icon || ""; font.pixelSize: 12 }
                                        Text { text: modelData.text || modelData.action || "-"; font.pixelSize: 12; color: modelData.status === "running" ? "#E6A23C" : "#909399" }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ 底栏: 操作按钮 ═══
            Rectangle {
                Layout.fillWidth: true; height: 44; color: "#FFFFFF"; radius: 8

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
                        background: Rectangle { color: "#2A1A1A"; radius: 8; width: 70; height: 32; border.color: "#E4E7ED"; border.width: 1 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#F56C6C"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.id) {
                                alarmController.markFalseAlarm(currentAlarm.id)
                            }
                            linkagePopup.falseAlarm()
                            linkagePopup.dismiss()
                        }
                    }
                    Button { text: "静音"; font.pixelSize: 12
                        background: Rectangle { color: "#F5F7FA"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#909399"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.id) {
                                alarmController.handleAlarm(currentAlarm.id, "mute")
                            }
                            linkagePopup.silenced()
                            linkagePopup.dismiss()
                        }
                    }
                    Button { text: "回放"; font.pixelSize: 12
                        background: Rectangle { color: "#F5F7FA"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#909399"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            if (currentAlarm && currentAlarm.channel_id) {
                                mediaController.startStream(currentAlarm.channel_id, "playback")
                            }
                        }
                    }
                    Button { text: "对讲"; font.pixelSize: 12
                        background: Rectangle { color: "#F5F7FA"; radius: 8; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#909399"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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

    // 自动关闭计时器 (默认 60s, 与 Web 截图一致)
    Timer {
        id: autoCloseTimer
        interval: 1000; repeat: true
        property int countdown: 60
        onTriggered: {
            countdown--
            countdownText.text = countdown + "s"
            if (countdown <= 0) linkagePopup.dismiss()
        }
        Component.onCompleted: countdown = autoCloseSec
    }
}
