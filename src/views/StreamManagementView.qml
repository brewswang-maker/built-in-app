// ========================================================================
// StreamManagementView.qml — 流媒体管理 (推拉流 + 码率监控 + 流列表 + 批量停止)
// 接入 mediaController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: streamView

    // ── 内部状态 ──
    property var activeStreams: []
    property var historyStreams: []
    property var streamStats: ({ activeCount: 0, totalViewers: 0, totalBitrate: 0, zlmOnline: false })
    property string activeTab: "active"
    property bool showProxyDialog: false
    property string proxyUrl: ""
    property string proxyApp: "live"
    property string proxyStreamName: ""
    property var selectedStreamIds: []
    property var bitrateHistory: []

    // ── ZLM 统计 ──
    property int zlmCpu: 0
    property int zlmMemory: 0
    property int zlmThreads: 0
    property int zlmStreamCount: 0

    // ── 生命周期 ──
    Component.onCompleted: {
        mediaController.refreshStreams()
        statusController.startPolling(5000)
    }

    // ── 监听 Controller 信号 ──
    Connections {
        target: mediaController
        function onChannelsUpdated() {
            parseStreamList()
        }
        function onStreamStarted(deviceId, url) {
            statusText.text = "✅ 流已启动: " + url
            statusText.color = "#00D4AA"
            statusTimer.start()
        }
        function onStreamStopped(sessionId) {
            statusText.text = "⏹ 流已停止: " + sessionId
            statusText.color = "#FFB800"
            statusTimer.start()
            mediaController.refreshStreams()
        }
        function onErrorOccurred(code, message) {
            statusText.text = "❌ 错误: " + message
            statusText.color = "#FF3D71"
            statusTimer.start()
        }
    }

    Connections {
        target: statusController
        function onStatusUpdated() {
            zlmCpu = Math.round(statusController.cpuUsage)
            zlmMemory = Math.round(statusController.memoryUsage)
            updateBitrateChart()
        }
    }

    Timer { id: statusTimer; interval: 4000; onTriggered: statusText.text = "" }

    // ── 定时刷新码率图 ──
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: updateBitrateChart()
    }

    // ── 解析流列表 ──
    function parseStreamList() {
        var channels = mediaController.channels
        var active = []
        var history = []
        var totalViewers = 0
        var totalBitrate = 0

        for (var i = 0; i < channels.length; i++) {
            var ch = channels[i]
            var item = {
                streamId: ch.streamId || (ch.deviceId + "_" + ch.channelNo),
                app: ch.app || "live",
                stream: ch.stream || ch.channelNo,
                schema: ch.schema || ch.protocol || "RTSP",
                sourceDevice: ch.sourceDevice || ch.deviceName || ch.deviceId || "-",
                viewerCount: ch.viewerCount || ch.viewers || 0,
                bitrate: ch.bitrate || 0,
                codec: ch.codec || "H.265",
                resolution: ch.resolution || "-",
                fps: ch.fps || 0,
                createdAt: ch.createdAt || "-",
                status: ch.status || "active"
            }
            totalViewers += item.viewerCount
            totalBitrate += item.bitrate

            if (item.status === "active" || item.status === "streaming") {
                active.push(item)
            } else {
                history.push(item)
            }
        }

        activeStreams = active
        historyStreams = history
        streamStats = {
            activeCount: active.length,
            totalViewers: totalViewers,
            totalBitrate: totalBitrate,
            zlmOnline: true
        }
    }

    function updateBitrateChart() {
        var entry = {
            time: Date.now(),
            total: streamStats.totalBitrate
        }
        bitrateHistory.push(entry)
        if (bitrateHistory.length > 60) bitrateHistory.shift()
        bitrateCanvas.requestPaint()
    }

    function formatBitrate(bps) {
        if (!bps) return "0 bps"
        if (bps >= 1000000) return (bps / 1000000).toFixed(1) + " Mbps"
        if (bps >= 1000) return (bps / 1000).toFixed(1) + " Kbps"
        return bps + " bps"
    }

    function formatBitrateShort(bps) {
        if (!bps) return "0"
        if (bps >= 1000000) return (bps / 1000000).toFixed(1) + "M"
        if (bps >= 1000) return (bps / 1000).toFixed(0) + "K"
        return bps + ""
    }

    // ── 状态提示 ──
    Text {
        id: statusText
        anchors.top: parent.top; anchors.left: parent.left; anchors.leftMargin: 16
        font.pixelSize: 11; color: "#8B8FA3"; height: 0; z: 10
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 工具栏
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "📺 流媒体管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: "ZLMediaKit: " + (streamStats.zlmOnline ? "运行中" : "离线"); font.pixelSize: 12; color: streamStats.zlmOnline ? "#00D4AA" : "#FF3D71" }
            Button {
                text: "➕ 添加拉流"; font.pixelSize: 12
                onClicked: showProxyDialog = true
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "⏹ 批量停止(" + selectedStreamIds.length + ")"; font.pixelSize: 12
                visible: selectedStreamIds.length > 0
                onClicked: {
                    for (var i = 0; i < selectedStreamIds.length; i++) {
                        mediaController.stopStream(selectedStreamIds[i])
                    }
                    selectedStreamIds = []
                }
                background: Rectangle { color: "#FF3D71"; radius: 6; width: 140; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "🔄 刷新"; font.pixelSize: 12
                onClicked: mediaController.refreshStreams()
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ── 统计卡片 ──
    Rectangle {
        id: statsRow
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 60; color: "transparent"

        Row {
            anchors.fill: parent; spacing: 8

            Repeater {
                model: [
                    { icon: "📺", label: "活跃流数", value: streamStats.activeCount, color: "#3B82F6" },
                    { icon: "👁", label: "总观看数", value: streamStats.totalViewers, color: "#00D4AA" },
                    { icon: "📊", label: "总码率", value: formatBitrate(streamStats.totalBitrate), color: "#8B5CF6" },
                    { icon: "🖥", label: "ZLM状态", value: streamStats.zlmOnline ? "在线" : "离线", color: streamStats.zlmOnline ? "#00D4AA" : "#FF3D71" }
                ]
                delegate: Rectangle {
                    width: (statsRow.width - 24) / 4; height: 60; color: "#141720"; radius: 8
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 2
                        Row { spacing: 4; Text { text: modelData.icon; font.pixelSize: 11 }; Text { text: modelData.label; font.pixelSize: 9; color: "#8B8FA3" } }
                        Text { text: modelData.value; font.pixelSize: 18; font.bold: true; color: modelData.color }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.top: statsRow.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 码率实时图表 + ZLM状态 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 300
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📊 码率监控 (实时)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: bitrateCanvas
                    width: parent.width - 24; height: 160

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                        // Y轴标签
                        ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                        ctx.fillText("高", 2, 12)
                        ctx.fillText("中", 2, h / 2)
                        ctx.fillText("0", 2, h - 4)

                        // 网格
                        ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                        for (var i = 0; i <= 4; i++) {
                            ctx.beginPath(); ctx.moveTo(0, h * i / 4); ctx.lineTo(w, h * i / 4); ctx.stroke()
                        }

                        // 绘制码率线
                        if (bitrateHistory.length > 1) {
                            var maxVal = 0
                            for (var i = 0; i < bitrateHistory.length; i++) {
                                if (bitrateHistory[i].total > maxVal) maxVal = bitrateHistory[i].total
                            }
                            if (maxVal === 0) maxVal = 1

                            ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 2
                            ctx.beginPath()
                            for (var i = 0; i < bitrateHistory.length; i++) {
                                var x = (i / 60) * w
                                var y = h - (bitrateHistory[i].total / maxVal) * (h - 20)
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.stroke()

                            // 渐变填充
                            ctx.lineTo((bitrateHistory.length - 1) / 60 * w, h)
                            ctx.lineTo(0, h)
                            ctx.closePath()
                            var grad = ctx.createLinearGradient(0, 0, 0, h)
                            grad.addColorStop(0, "rgba(59,130,246,0.3)")
                            grad.addColorStop(1, "rgba(59,130,246,0.0)")
                            ctx.fillStyle = grad; ctx.fill()
                        }
                    }
                }

                // 图例
                Row { spacing: 12
                    Text { text: "● 总码率"; font.pixelSize: 10; color: "#3B82F6" }
                    Text { text: formatBitrate(streamStats.totalBitrate); font.pixelSize: 10; color: "#E8E8E8"; font.bold: true }
                }

                // ZLM 状态面板
                Rectangle {
                    width: parent.width - 24; height: 150; color: "#0D0F12"; radius: 6
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Text { text: "ZLMediaKit 统计"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 8
                            Text { text: "活跃流:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: streamStats.activeCount; font.pixelSize: 11; color: "#00D4AA"; font.bold: true }
                        }
                        Row { spacing: 8
                            Text { text: "总带宽:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: formatBitrate(streamStats.totalBitrate); font.pixelSize: 11; color: "#E8E8E8" }
                        }
                        Row { spacing: 8
                            Text { text: "WebRTC会话:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: streamStats.totalViewers; font.pixelSize: 11; color: "#E8E8E8" }
                        }
                        Row { spacing: 8
                            Text { text: "CPU使用:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: zlmCpu + "%"; font.pixelSize: 11; color: zlmCpu > 80 ? "#FF3D71" : zlmCpu > 60 ? "#FFB800" : "#00D4AA" }
                        }
                        Row { spacing: 8
                            Text { text: "内存:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: zlmMemory + "%"; font.pixelSize: 11; color: zlmMemory > 80 ? "#FF3D71" : zlmMemory > 60 ? "#FFB800" : "#00D4AA" }
                        }
                        Row { spacing: 8
                            Text { text: "RTSP拉流:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: streamStats.activeCount; font.pixelSize: 11; color: "#E8E8E8" }
                        }
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

                // Tab 切换
                Row {
                    spacing: 0; width: parent.width
                    Rectangle {
                        width: 80; height: 32; radius: 6; color: activeTab === "active" ? "#252830" : "transparent"
                        Text { text: "活跃流 (" + activeStreams.length + ")"; font.pixelSize: 12; color: activeTab === "active" ? "#00D4AA" : "#8B8FA3"; font.bold: activeTab === "active"; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; onClicked: activeTab = "active" }
                    }
                    Rectangle {
                        width: 90; height: 32; radius: 6; color: activeTab === "history" ? "#252830" : "transparent"
                        Text { text: "历史流 (" + historyStreams.length + ")"; font.pixelSize: 12; color: activeTab === "history" ? "#00D4AA" : "#8B8FA3"; font.bold: activeTab === "history"; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; onClicked: activeTab = "history" }
                    }
                }

                // 流列表
                ListView {
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4

                    model: activeTab === "active" ? activeStreams : historyStreams

                    delegate: Rectangle {
                        width: ListView.view.width; height: 60; color: "#141720"; radius: 6

                        property var streamData: modelData
                        property bool isSelected: selectedStreamIds.indexOf(streamData.streamId) >= 0

                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2

                            Row {
                                spacing: 8; width: parent.width
                                // 选择框
                                Rectangle {
                                    width: 18; height: 18; radius: 3; anchors.verticalCenter: parent.verticalCenter
                                    color: isSelected ? "#3B82F6" : "transparent"
                                    border.color: isSelected ? "#3B82F6" : "#4A4D58"; border.width: 1
                                    Text { text: "✓"; font.pixelSize: 10; color: "#FFF"; visible: isSelected; anchors.centerIn: parent }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var idx = selectedStreamIds.indexOf(streamData.streamId)
                                            if (idx >= 0) {
                                                var copy = selectedStreamIds.slice()
                                                copy.splice(idx, 1)
                                                selectedStreamIds = copy
                                            } else {
                                                selectedStreamIds = selectedStreamIds.concat([streamData.streamId])
                                            }
                                        }
                                    }
                                }
                                Text { text: streamData.sourceDevice; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; width: 130; elide: Text.ElideMiddle }
                                Rectangle { width: 50; height: 14; radius: 3; color: "#1A2A3A"
                                    Text { text: streamData.schema; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                                }
                                Rectangle { width: 35; height: 14; radius: 3; color: "#1A3A2A"
                                    Text { text: streamData.codec; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent }
                                }
                                Text { text: streamData.resolution; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: formatBitrateShort(streamData.bitrate); font.pixelSize: 10; color: "#FFB800" }
                                Text { text: streamData.fps + "fps"; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "👁 " + streamData.viewerCount; font.pixelSize: 10; color: "#8B8FA3" }

                                Item { width: 10 }

                                Button {
                                    text: "播放"; font.pixelSize: 9
                                    onClicked: mediaController.startStream(streamData.streamId, "")
                                    background: Rectangle { color: "#3B82F6"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                                Button {
                                    text: "截图"; font.pixelSize: 9
                                    onClicked: mediaController.snapshot(streamData.streamId)
                                    background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                                Button {
                                    text: "断开"; font.pixelSize: 9
                                    onClicked: mediaController.stopStream(streamData.streamId)
                                    background: Rectangle { color: "#FF3D71"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            Text {
                                text: streamData.app + "/" + streamData.stream + "  |  ID: " + streamData.streamId
                                font.pixelSize: 9; color: "#4A4D58"
                                elide: Text.ElideMiddle; width: parent.width
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 添加拉流代理弹窗
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        visible: showProxyDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showProxyDialog = false }
        Rectangle {
            width: 440; height: 340; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12

                Row { width: parent.width; spacing: 8
                    Text { text: "➕ 添加拉流代理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 130 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showProxyDialog = false } }
                }

                Grid {
                    columns: 2; columnSpacing: 12; rowSpacing: 8; width: parent.width
                    Text { text: "源地址:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        text: proxyUrl; onTextChanged: proxyUrl = text
                        width: 260; font.pixelSize: 12; color: "#E8E8E8"
                        placeholderText: "rtsp://192.168.1.100:554/stream1"; placeholderTextColor: "#4A4D58"
                        background: Rectangle { color: "#252830"; radius: 6 }
                    }
                    Text { text: "应用名:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        text: proxyApp; onTextChanged: proxyApp = text
                        width: 260; font.pixelSize: 12; color: "#E8E8E8"
                        placeholderText: "live"; placeholderTextColor: "#4A4D58"
                        background: Rectangle { color: "#252830"; radius: 6 }
                    }
                    Text { text: "流名:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        text: proxyStreamName; onTextChanged: proxyStreamName = text
                        width: 260; font.pixelSize: 12; color: "#E8E8E8"
                        placeholderText: "stream_001"; placeholderTextColor: "#4A4D58"
                        background: Rectangle { color: "#252830"; radius: 6 }
                    }
                }

                Row {
                    spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button {
                        text: "取消"; font.pixelSize: 13; onClicked: showProxyDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "确认添加"; font.pixelSize: 13
                        onClicked: {
                            if (proxyUrl && proxyApp && proxyStreamName) {
                                mediaController.startStream(proxyUrl, proxyApp + "/" + proxyStreamName)
                                showProxyDialog = false
                                proxyUrl = ""; proxyApp = "live"; proxyStreamName = ""
                                statusText.text = "✅ 拉流代理已添加"; statusText.color = "#00D4AA"; statusTimer.start()
                            }
                        }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }
}
