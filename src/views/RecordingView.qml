// ========================================================================
// RecordingView.qml — 录像回放 (时间轴 + 多路同步 + 本地存储管理)
// Controller: mediaController
// 零硬编码数据，所有交互通过Controller
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: recordingView

    property string selectedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string selectedChannel: ""
    property string selectedEventType: ""
    // [FIX 2026-07-01] AI标签筛选透传到 RecordingController.query()
    property string selectedAiTag: ""
    property int selectedMinConfidence: 0
    property var recordingSegments: []
    property real playbackPosition: 0
    property string playbackUrl: ""
    property bool isPlaying: false
    property var lockedRecordings: ({})

    Component.onCompleted: {
        mediaController.refreshStreams()
        recordingController.refreshRecordings()  // [FIX 2026-07-01] 初始化加载录像记录
    }

    Connections {
        target: mediaController
        function onStreamStarted(sessionId, url) {
            playbackUrl = url || ""
            isPlaying = true
            playerOverlay.text = "正在播放..."
        }
        function onStreamStopped(sessionId) {
            playbackUrl = ""
            isPlaying = false
            playerOverlay.text = "点击播放录像"
        }
        function onChannelsUpdated() {
            // streams 列表更新后，重建通道选择器
            var streamList = mediaController.channels || []
            var channelNames = ["全部通道"]
            for (var i = 0; i < streamList.length; i++) {
                channelNames.push(streamList[i].name || streamList[i].channelName || ("通道" + (i + 1)))
            }
            channelSelect.model = channelNames

            // 更新录像段
            recordingSegments = []
            for (var j = 0; j < streamList.length; j++) {
                var segs = streamList[j].segments || streamList[j].recordings || []
                for (var k = 0; k < segs.length; k++) {
                    recordingSegments.push(segs[k])
                }
            }
            timelineCanvas.requestPaint()
        }
    }

    // ── 顶部工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            AppIcon { name: "record"; size: 22; iconColor: "#E8E8E8"; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Text { text: "录像回放"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            // 通道筛选
            ComboBox {
                id: channelSelect
                width: 180
                model: ["全部通道"]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: channelSelect.displayText
                    color: "#E8E8E8"; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter; leftPadding: 10
                }
                onCurrentTextChanged: {
                    selectedChannel = currentIndex === 0 ? "" : currentText
                }
            }

            // 事件类型筛选
            ComboBox {
                id: eventTypeSelect
                width: 140
                model: ["全部类型", "连续录像", "移动侦测", "告警录像"]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: eventTypeSelect.displayText
                    color: "#E8E8E8"; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter; leftPadding: 10
                }
                onCurrentTextChanged: {
                    var typeMap = ["", "continuous", "motion", "alarm"]
                    selectedEventType = currentIndex === 0 ? "" : (typeMap[currentIndex] || "")
                }
            }

            // P3.5: AI标签筛选 (对标海康录像AI检索)
            ComboBox {
                id: aiTagSelect
                width: 160
                model: ["全部AI标签", "人员检测", "车辆检测", "安全帽", "火焰/烟雾", "人脸识别", "人群密度", "摔倒检测"]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: aiTagSelect.displayText
                    color: "#E8E8E8"; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter; leftPadding: 10
                }
                // [FIX 2026-07-01] AI标签透传到 selectedAiTag
                onCurrentTextChanged: {
                    var tagMap = {
                        "全部AI标签": "",
                        "人员检测": "person",
                        "车辆检测": "vehicle",
                        "安全帽": "helmet",
                        "火焰/烟雾": "fire_smoke",
                        "人脸识别": "face",
                        "人群密度": "crowd",
                        "摔倒检测": "fall"
                    }
                    selectedAiTag = tagMap[currentText] || ""
                }
            }

            // P3.5: 最低置信度
            Row {
                spacing: 2
                SpinBox {
                    id: minConfidenceSpin
                    width: 80
                    from: 0; to: 100; value: 0; stepSize: 10
                    background: Rectangle { color: "#252830"; radius: 6 }
                    contentItem: Text {
                        text: minConfidenceSpin.value + "%"
                        color: "#E8E8E8"; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // [V4-X2 2026-07-08] 搜索按钮 — 有 AI 标签 / 置信度 走 smart-search 智能检索
            //   ai_tag / min_confidence 组合 → POST /api/v1/recordings/smart-search
            //   其他筛选 → POST /api/v1/recordings/query (传统录像查询)
            Button {
                text: "搜索"
                font.pixelSize: 13; font.bold: true
                background: Rectangle { color: "#00D4AA"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var filter = {
                        "channel": selectedChannel,
                        "event_type": selectedEventType,
                        "ai_tag": selectedAiTag,
                        "min_confidence": selectedMinConfidence / 100.0,
                        "date": selectedDate
                    }
                    // 智能检索分支: 只要指定了 AI 标签或设置了最低置信度,
                    //   调 smart-search 端点查 alarm_events 表 (含 AI 标签)
                    if (selectedAiTag || selectedMinConfidence > 0) {
                        recordingController.querySmart(filter)
                    } else {
                        recordingController.query(filter)
                    }
                }
            }

            Button {
                text: selectedDate
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: calendarPopup.open()
            }
            Button {
                text: "前一天"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var d = Date.fromLocaleDateString(Qt.locale(), selectedDate, "yyyy-MM-dd")
                    d.setDate(d.getDate() - 1)
                    selectedDate = Qt.formatDate(d, "yyyy-MM-dd")
                    mediaController.refreshStreams()
                }
            }
            Button {
                text: "后一天"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var d = Date.fromLocaleDateString(Qt.locale(), selectedDate, "yyyy-MM-dd")
                    d.setDate(d.getDate() + 1)
                    selectedDate = Qt.formatDate(d, "yyyy-MM-dd")
                    mediaController.refreshStreams()
                }
            }
        }
    }

    Popup {
        id: calendarPopup
        y: toolbar.height
        width: 300; height: 50
        Column {
            spacing: 4
            TextField {
                id: dateField
                width: 280; height: 36
                placeholderText: "yyyy-MM-dd"
                text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                color: "#E8E8E8"; font.pixelSize: 13
                background: Rectangle { color: "#252830"; radius: 6 }
            }
            Button {
                text: "确定"; width: 280; height: 32
                background: Rectangle { color: "#00D4AA"; radius: 6 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    calendarPopup.close()
                    mediaController.refreshStreams()
                }
            }
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

                    Text {
                        id: playerOverlay
                        anchors.centerIn: parent
                        text: "点击播放录像"
                        font.pixelSize: 16; color: "#4A4D58"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: {
                            if (selectedChannel) {
                                var streams = mediaController.channels || []
                                for (var i = 0; i < streams.length; i++) {
                                    if (streams[i].name === selectedChannel || streams[i].channelName === selectedChannel) {
                                        mediaController.startStream(streams[i].id || streams[i].channelId || "", "playback")
                                        break
                                    }
                                }
                            } else if (mediaController.channels.length > 0) {
                                var s = mediaController.channels[0]
                                mediaController.startStream(s.id || s.channelId || "", "playback")
                            }
                        }
                    }

                    // 通道信息叠加
                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8
                        width: 160; height: 24; color: "#99000000"; radius: 4
                        Text { text: (selectedChannel || "全部通道"); font.pixelSize: 12; color: "#E8E8E8"; anchors.centerIn: parent }
                    }

                    // 时间戳叠加
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                        width: 140; height: 24; color: "#99000000"; radius: 4
                        Text { text: selectedDate + " " + playbackTimeText.text; font.pixelSize: 12; color: "#FFB800"; anchors.centerIn: parent }
                    }

                    // 多路同步缩略图
                    Row {
                        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 8
                        spacing: 4

                        Repeater {
                            model: Math.min(mediaController.channels.length, 4)
                            delegate: Rectangle {
                                width: 80; height: 45; color: "#141720"; radius: 4
                                border.color: index === 0 ? "#00D4AA" : "#252830"; border.width: index === 0 ? 2 : 1
                                Text {
                                    text: {
                                        var streamList = mediaController.channels
                                        return streamList[index] ? (streamList[index].name || ("CH" + (index+1))) : ("CH" + (index+1))
                                    }
                                    font.pixelSize: 12; color: "#8B8FA3"; anchors.centerIn: parent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var streamList = mediaController.channels
                                        if (streamList[index]) {
                                            mediaController.startStream(streamList[index].id || streamList[index].channelId || "", "playback")
                                        }
                                    }
                                }
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
                            Button {
                                text: "|<"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }
                                contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: playbackPosition = Math.max(0, playbackPosition - 1)
                            }
                            Button {
                                text: "<<"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }
                                contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: playbackPosition = Math.max(0, playbackPosition - 0.1)
                            }
                            Button {
                                text: isPlaying ? "||" : ">"; font.pixelSize: 14
                                background: Rectangle { color: "#00D4AA"; radius: 4; width: 40; height: 28 }
                                contentItem: Text { text: parent.text; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (isPlaying) {
                                        mediaController.stopStream(selectedChannel || "")
                                    } else if (selectedChannel) {
                                        var streamList = mediaController.channels
                                        for (var i = 0; i < streamList.length; i++) {
                                            if (streamList[i].name === selectedChannel || streamList[i].channelName === selectedChannel) {
                                                mediaController.startStream(streamList[i].id || streamList[i].channelId || "", "playback")
                                                break
                                            }
                                        }
                                    } else if (mediaController.channels.length > 0) {
                                        var s = mediaController.channels[0]
                                        mediaController.startStream(s.id || s.channelId || "", "playback")
                                    }
                                }
                            }
                            Button {
                                text: ">>"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }
                                contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: playbackPosition = Math.min(24, playbackPosition + 0.1)
                            }
                            Button {
                                text: ">|"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 32; height: 28 }
                                contentItem: Text { text: parent.text; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: playbackPosition = Math.min(24, playbackPosition + 1)
                            }

                            Text { text: "|"; font.pixelSize: 14; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }

                            Text { text: "速度:"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            ComboBox {
                                id: speedCombo; width: 60
                                model: ["0.5x","1x","2x","4x","8x","16x"]; currentIndex: 1
                                background: Rectangle { color: "#252830"; radius: 4 }
                            }

                            Text { text: "|"; font.pixelSize: 14; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }

                            Text { id: playbackTimeText; text: "00:00:00"; font.pixelSize: 12; color: "#FFB800"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "/ 23:59:59"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }

                            Item { width: 20 }
                            Button {
                                text: "截图"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 48; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (selectedChannel) {
                                        var streamList = mediaController.channels
                                        for (var i = 0; i < streamList.length; i++) {
                                            if (streamList[i].name === selectedChannel || streamList[i].channelName === selectedChannel) {
                                                mediaController.snapshot(streamList[i].id || streamList[i].channelId || "")
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                            Button {
                                text: "下载"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 48; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    // 下载当前选中的录像段
                                    if (recordingSegments.length > 0) {
                                        var seg = recordingSegments[0]
                                        var recId = seg.id || seg.recording_id || seg.recordingId || ""
                                        if (recId) {
                                            recordingController.download(recId)
                                        }
                                    }
                                }
                            }
                            Button {
                                text: lockedRecordings[selectedChannel] ? "解锁" : "锁定"; font.pixelSize: 12
                                background: Rectangle { color: lockedRecordings[selectedChannel] ? "#FFB800" : "#252830"; radius: 4; width: 52; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: lockedRecordings[selectedChannel] ? "#0D0F12" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (selectedChannel) {
                                        lockedRecordings[selectedChannel] = !lockedRecordings[selectedChannel]
                                        lockedRecordingsChanged()
                                    }
                                }
                            }
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

                                // 录像段 — 从mediaController数据渲染
                                var segs = recordingSegments
                                for (var s = 0; s < segs.length; s++) {
                                    var seg = segs[s]
                                    var startH = seg.startTime || seg.startHour || 0
                                    var endH = seg.endTime || seg.endHour || 0
                                    var sx = (startH / 24) * width
                                    var sw = ((endH - startH) / 24) * width
                                    ctx.fillStyle = seg.type === "alarm" ? "#FF3D71" :
                                                    seg.type === "motion" ? "#FFB800" : "#00D4AA"
                                    ctx.globalAlpha = seg.type === "continuous" ? 0.6 : 0.9
                                    ctx.fillRect(sx, 6, sw, 14)
                                }
                                ctx.globalAlpha = 1

                                // 当前播放位置
                                var playX = (playbackPosition / 24) * width
                                if (playX > 0) {
                                    ctx.strokeStyle = "#FF3D71"
                                    ctx.lineWidth = 2
                                    ctx.beginPath()
                                    ctx.moveTo(playX, 0)
                                    ctx.lineTo(playX, height)
                                    ctx.stroke()

                                    ctx.fillStyle = "#FF3D71"
                                    ctx.beginPath()
                                    ctx.moveTo(playX - 4, 0)
                                    ctx.lineTo(playX + 4, 0)
                                    ctx.lineTo(playX, 5)
                                    ctx.closePath()
                                    ctx.fill()
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                            onClicked: {
                                var pos = (mouseX / width) * 24
                                playbackPosition = pos
                                var hours = Math.floor(pos)
                                var mins = Math.floor((pos - hours) * 60)
                                var secs = Math.floor(((pos - hours) * 60 - mins) * 60)
                                playbackTimeText.text = (hours < 10 ? "0" : "") + hours + ":" +
                                                        (mins < 10 ? "0" : "") + mins + ":" +
                                                        (secs < 10 ? "0" : "") + secs
                                timelineCanvas.requestPaint()
                            }
                            }
                        }

                        // 图例
                        Row {
                            spacing: 12
                            Text { text: "连续录像"; font.pixelSize: 12; color: "#00D4AA" }
                            Text { text: "移动侦测"; font.pixelSize: 12; color: "#FFB800" }
                            Text { text: "告警录像"; font.pixelSize: 12; color: "#FF3D71" }
                        }
                    }
                }
            }
        }

        // ── 录像列表 ──
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 200
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "录像列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width; height: parent.height - 30
                    clip: true; spacing: 4

                    model: recordingSegments

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48
                        color: "#0D0F12"; radius: 4

                        Row {
                            anchors.fill: parent; anchors.margins: 8; spacing: 12

                            // 状态指示灯
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: modelData.type === "alarm" ? "#FF3D71" :
                                      modelData.type === "motion" ? "#FFB800" : "#00D4AA"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 通道名
                            Text {
                                text: modelData.channelName || modelData.channel || "—"
                                font.pixelSize: 12; font.bold: true; color: "#E8E8E8"
                                width: 120
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 时间段
                            Text {
                                text: (modelData.startTime !== undefined ? modelData.startTime : "—") + " - " +
                                      (modelData.endTime !== undefined ? modelData.endTime : "—")
                                font.pixelSize: 12; color: "#8B8FA3"
                                width: 160
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 事件类型
                            Text {
                                text: modelData.type === "alarm" ? "告警录像" :
                                      modelData.type === "motion" ? "移动侦测" : "连续录像"
                                font.pixelSize: 12; color: "#FFB800"
                                width: 80
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 大小
                            Text {
                                text: modelData.size ? modelData.size : "—"
                                font.pixelSize: 12; color: "#8B8FA3"
                                width: 80
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item { width: 20 }

                            // 播放按钮
                            Button {
                                text: ">"; font.pixelSize: 12
                                background: Rectangle { color: "#00D4AA"; radius: 4; width: 28; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (modelData.channelId || modelData.channel_id) {
                                        mediaController.startStream(modelData.channelId || modelData.channel_id, "playback")
                                    }
                                }
                            }

                            // 锁定按钮
                            Button {
                                text: locked ? "L" : ""; font.pixelSize: 12
                                background: Rectangle { color: lockedRecordings[modelData.id] ? "#FFB800" : "#252830"; radius: 4; width: 28; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: lockedRecordings[modelData.id] ? "#0D0F12" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (modelData.id) {
                                        lockedRecordings[modelData.id] = !lockedRecordings[modelData.id]
                                        lockedRecordingsChanged()
                                    }
                                }
                            }

                            // 下载按钮
                            Button {
                                text: "DL"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 28; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    // 调用录像下载API
                                    var recId = modelData.id || modelData.recording_id || modelData.recordingId || ""
                                    if (recId) {
                                        recordingController.download(recId)
                                    }
                                }
                            }
                        }
                    }

                    // 空状态
                    Text {
                        anchors.centerIn: parent
                        text: "暂无录像数据"
                        font.pixelSize: 14; color: "#4A4D58"
                        visible: recordingSegments.length === 0
                    }
                }
            }
        }
    }
}
