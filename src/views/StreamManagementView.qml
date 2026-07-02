// ========================================================================
// StreamManagementView.qml — 流媒体管理
// 接入 mediaController — box-sdk REST API
// 功能: 活跃/历史Tab / 流地址复制 / 批量停止 / 带宽监控 / 码率图表
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: streamView

    property int currentTab: 0
    property var selectedStreams: []
    property string statusMsg: ""
    property double totalBitrate: 0.0
    property double maxBandwidth: 200.0
    property var bitrateHistory: []

    Component.onCompleted: mediaController.refreshStreams()

    Connections {
        target: mediaController
        function onChannelsUpdated() { recalcBandwidth() }
        function onStreamStopped(channelId) { statusMsg = "Stopped: " + channelId; statusTimer.start() }
        function onStreamStarted(channelId) { statusMsg = "Started: " + channelId; statusTimer.start() }
        function onErrorOccurred(code, message) { statusMsg = "Error: " + message; statusTimer.start() }
    }

    Timer { id: statusTimer; interval: 3000; onTriggered: statusMsg = "" }

    // Auto-refresh
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: mediaController.refreshStreams()
    }

    function recalcBandwidth() {
        var streams = mediaController.channels
        var total = 0
        for (var i = 0; i < streams.length; i++) {
            total += (streams[i].bitrate || 0)
        }
        totalBitrate = total / 1000.0
        // Update history for chart
        bitrateHistory.push(totalBitrate)
        if (bitrateHistory.length > 60) bitrateHistory.shift()
        bitrateChart.requestPaint()
    }

    function toggleStreamSelect(channelId) {
        var idx = selectedStreams.indexOf(channelId)
        var copy = selectedStreams.slice()
        if (idx >= 0) copy.splice(idx, 1); else copy.push(channelId)
        selectedStreams = copy
    }

    function batchStop() {
        for (var i = 0; i < selectedStreams.length; i++)
            mediaController.stopStream(selectedStreams[i])
        selectedStreams = []
        statusMsg = "Batch stop completed"; statusTimer.start()
    }

    function copyToClipboard(text) {
        statusMsg = "Copied: " + text; statusTimer.start()
    }

    function formatDuration(seconds) {
        if (!seconds) return "-"
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        var s = Math.floor(seconds % 60)
        return (h > 0 ? h + "h " : "") + m + "m " + s + "s"
    }

    function bitrateColor(br) {
        if (br > 6000) return "#FF3D71"
        if (br > 4000) return "#FFB800"
        return "#00D4AA"
    }

    // ═══ Toolbar ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "Stream Mgmt"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: "Active: " + mediaController.channels.length; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
            Text { text: "BW: " + totalBitrate.toFixed(1) + "/" + maxBandwidth + " Mbps"; font.pixelSize: 12; color: "#8B8FA3" }
            Item { Layout.fillWidth: true }
            Text { text: statusMsg; font.pixelSize: 12; color: "#FFB800"; visible: statusMsg !== "" }

            Button {
                text: "Batch Stop (" + selectedStreams.length + ")"; font.pixelSize: 12
                enabled: selectedStreams.length > 0; onClicked: batchStop()
                background: Rectangle { color: selectedStreams.length > 0 ? "#FF3D71" : "#252830"; radius: 6; width: 120; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: selectedStreams.length > 0 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Refresh"; font.pixelSize: 12; onClicked: mediaController.refreshStreams()
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ═══ Tab Bar ═══
    Rectangle {
        id: tabBar
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 40; color: "#141720"

        Row {
            spacing: 4; anchors.fill: parent; anchors.margins: 4

            Repeater {
                model: ["Active Streams", "History"]
                delegate: Rectangle {
                    width: 130; height: 32; radius: 6
                    color: currentTab === index ? "#0D0F12" : "transparent"
                    border.color: currentTab === index ? "#3B82F6" : "transparent"; border.width: 1
                    Text { text: modelData; font.pixelSize: 12; color: currentTab === index ? "#3B82F6" : "#8B8FA3"; font.bold: currentTab === index; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; onClicked: currentTab = index }
                }
            }
        }
    }

    // ═══ Bandwidth bar ═══
    Rectangle {
        id: bwBar
        anchors.top: tabBar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 28; color: "#141720"; radius: 6

        Row {
            anchors.fill: parent; anchors.margins: 6; spacing: 8

            Text { text: "BW:"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                width: parent.width - 120; height: 14; radius: 3; color: "#0D0F12"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: Math.min(parent.width, parent.width * (totalBitrate / maxBandwidth))
                    height: 14; radius: 3
                    color: totalBitrate / maxBandwidth > 0.8 ? "#FF3D71" : totalBitrate / maxBandwidth > 0.5 ? "#FFB800" : "#00D4AA"
                    Behavior on width { NumberAnimation { duration: 500 } }
                }
            }
            Text { text: (totalBitrate / maxBandwidth * 100).toFixed(1) + "%"; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ═══ Main Content ═══
    RowLayout {
        anchors.top: bwBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── Left: Bitrate chart ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280; color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "Bitrate Monitor (Real-time)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    id: bitrateChart
                    width: parent.width - 24; height: 180

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                        // Grid
                        ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                        for (var i = 0; i <= 4; i++) { ctx.beginPath(); ctx.moveTo(0, h*i/4); ctx.lineTo(w, h*i/4); ctx.stroke() }

                        // Y axis labels
                        ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                        ctx.fillText(maxBandwidth + "Mbps", 2, 12)
                        ctx.fillText("0", 2, h - 4)

                        // Draw line
                        if (bitrateHistory.length > 1) {
                            ctx.strokeStyle = "#3B82F6"; ctx.lineWidth = 1.5
                            ctx.beginPath()
                            for (var i = 0; i < bitrateHistory.length; i++) {
                                var x = (i / 60) * w
                                var y = h - (bitrateHistory[i] / maxBandwidth) * h
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                        }
                    }
                }

                // Stats panel
                Rectangle { width: parent.width - 24; height: 140; color: "#0D0F12"; radius: 6
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Text { text: "Server Stats"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 8
                            Text { text: "Active streams:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: mediaController.channels.length; font.pixelSize: 12; color: "#00D4AA"; font.bold: true } }
                        Row { spacing: 8
                            Text { text: "Total bandwidth:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: totalBitrate.toFixed(1) + " Mbps"; font.pixelSize: 12; color: "#E8E8E8" } }
                        Row { spacing: 8
                            Text { text: "Avg bitrate:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: (mediaController.channels.length > 0 ? (totalBitrate / mediaController.channels.length).toFixed(1) : "0") + " Mbps"; font.pixelSize: 12; color: "#E8E8E8" } }
                        Row { spacing: 8
                            Text { text: "BW utilization:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: (totalBitrate / maxBandwidth * 100).toFixed(1) + "%"; font.pixelSize: 12; color: totalBitrate / maxBandwidth > 0.8 ? "#FF3D71" : "#00D4AA" } }
                    }
                }
            }
        }

        // ── Right: Stream list ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true; color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: currentTab === 0 ? "Active Streams" : "Stream History"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // Stream list
                ListView {
                    width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 4

                    model: currentTab === 0 ? mediaController.channels : []

                    delegate: Rectangle {
                        width: ListView.view.width; height: 64; color: "#141720"; radius: 6

                        property var streamData: modelData || model

                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 3

                            Row { spacing: 8; width: parent.width
                                // Checkbox
                                Rectangle {
                                    width: 14; height: 14; radius: 2; anchors.verticalCenter: parent.verticalCenter
                                    color: selectedStreams.indexOf(streamData.channelId || "") >= 0 ? "#3B82F6" : "transparent"
                                    border.color: selectedStreams.indexOf(streamData.channelId || "") >= 0 ? "#3B82F6" : "#4A4D58"; border.width: 1
                                    MouseArea { anchors.fill: parent; onClicked: toggleStreamSelect(streamData.channelId || "") }
                                }

                                Text { text: streamData.channelName || streamData.channelId || "-"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; width: 140; elide: Text.ElideMiddle }

                                Rectangle { width: 44; height: 14; radius: 3; color: "#1A2A3A"
                                    Text { text: streamData.protocol || "-"; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent } }
                                Rectangle { width: 32; height: 14; radius: 3; color: "#1A3A2A"
                                    Text { text: streamData.codec || "-"; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent } }

                                Text { text: streamData.resolution || "-"; font.pixelSize: 12; color: "#8B8FA3" }
                                Text { text: (streamData.bitrate || 0) + " Kbps"; font.pixelSize: 12; color: bitrateColor(streamData.bitrate || 0) }
                                Text { text: formatDuration(streamData.duration); font.pixelSize: 12; color: "#8B8FA3" }

                                Item { width: 10 }

                                Button { text: "Copy RTSP"; font.pixelSize: 12
                                    onClicked: copyToClipboard(streamData.rtspUrl || streamData.url || "")
                                    background: Rectangle { color: "#252830"; radius: 3; width: 56; height: 18 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Copy HLS"; font.pixelSize: 12
                                    onClicked: copyToClipboard(streamData.hlsUrl || "")
                                    background: Rectangle { color: "#252830"; radius: 3; width: 48; height: 18 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Stop"; font.pixelSize: 12
                                    onClicked: mediaController.stopStream(streamData.channelId || "")
                                    background: Rectangle { color: "#FF3D71"; radius: 3; width: 36; height: 18 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }

                            Text { text: streamData.url || streamData.rtspUrl || ""; font.pixelSize: 12; color: "#4A4D58"; elide: Text.ElideMiddle; width: parent.width }

                            // Bitrate bar per stream
                            Row { spacing: 4; width: parent.width
                                Rectangle { width: parent.width * 0.6; height: 4; radius: 2; color: "#0D0F12"
                                    Rectangle { width: Math.min(parent.width, parent.width * ((streamData.bitrate || 0) / 10000)); height: 4; radius: 2; color: bitrateColor(streamData.bitrate || 0) } }
                                Text { text: (streamData.bitrate || 0) + " Kbps"; font.pixelSize: 8; color: "#4A4D58" }
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentTab === 0 ? "No active streams" : "No history records"
                    font.pixelSize: 13; color: "#4A4D58"
                    visible: mediaController.channels.length === 0 && currentTab === 0
                }
            }
        }
    }

    // ═══ Stream Detail Dialog ═══
    property bool showStreamDetail: false
    property var detailStream: null

    function openStreamDetail(streamData) {
        detailStream = streamData
        showStreamDetail = true
    }

    Rectangle {
        visible: showStreamDetail; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showStreamDetail = false }
        Rectangle {
            width: 500; height: 380; color: "#141720"; radius: 12; anchors.centerIn: parent
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 10
                Row { spacing: 8; width: parent.width
                    Text { text: "Stream Detail"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Text { text: "X"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showStreamDetail = false } }
                }

                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "Channel:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.channelName || detailStream.channelId) : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Protocol:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.protocol || "-") : "-"; font.pixelSize: 12; color: "#3B82F6" }
                    Text { text: "Codec:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.codec || "-") : "-"; font.pixelSize: 12; color: "#00D4AA" }
                    Text { text: "Resolution:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.resolution || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Bitrate:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? ((detailStream.bitrate || 0) + " Kbps") : "-"; font.pixelSize: 12; color: "#FFB800" }
                    Text { text: "Duration:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: formatDuration(detailStream ? detailStream.duration : 0); font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Viewers:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.viewers || 0) : "0"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "RTSP URL:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.rtspUrl || detailStream.url || "-") : "-"; font.pixelSize: 12; color: "#3B82F6"; elide: Text.ElideMiddle; width: 280 }
                    Text { text: "HLS URL:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.hlsUrl || "-") : "-"; font.pixelSize: 12; color: "#3B82F6"; elide: Text.ElideMiddle; width: 280 }
                    Text { text: "FLV URL:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.flvUrl || "-") : "-"; font.pixelSize: 12; color: "#3B82F6"; elide: Text.ElideMiddle; width: 280 }
                    Text { text: "WebRTC:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailStream ? (detailStream.webrtcUrl || "-") : "-"; font.pixelSize: 12; color: "#3B82F6"; elide: Text.ElideMiddle; width: 280 }
                }

                Rectangle { height: 1; width: parent.width; color: "#252830" }

                Row { spacing: 8
                    Button { text: "Snapshot"; font.pixelSize: 12; onClicked: { if (detailStream) mediaController.snapshot(detailStream.channelId) }
                        background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Start Rec"; font.pixelSize: 12; onClicked: { if (detailStream) mediaController.startRecording(detailStream.channelId) }
                        background: Rectangle { color: "#FF3D71"; radius: 6; width: 80; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Stop Stream"; font.pixelSize: 12; onClicked: { if (detailStream) mediaController.stopStream(detailStream.channelId); showStreamDetail = false }
                        background: Rectangle { color: "#FF3D71"; radius: 6; width: 90; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }
}
