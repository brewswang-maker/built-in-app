// ========================================================================
// VideoPatrolPanel.qml — 视频监控轮巡面板 [P1-#2]
// 1:1 对齐 Web 端 SituationScreen.vue 的"视频监控"视图:
//   - 通道列表: GET /api/v1/channels?pageSize=100 (Web: channelApi.getList)
//   - 拉流复用: GET /api/v1/streams/{id}/multi-urls → POST /api/v1/streams/{id}/start
//   - 轮巡间隔: 30 秒 (对齐 Web videoPollIntervalSec=30)
//   - 1分屏 / 4分屏 切换 (对齐 Web videoLayout=1|4)
//   - loading / empty / playing 三态 (对齐 Web slot.loading/playing)
//   - 通道名高亮 (对齐 Web 当前播放高亮)
// 数据契约严格遵循 Web 端 SituationApi/SituationScreen.vue, 无本地 mock.
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Item {
    id: videoPatrolPanel

    // ── 视图状态 (对齐 Web videoLayout) ──
    property int layout: 4               // 1 | 4
    property bool pollingActive: true    // Web videoPollingActive
    property int pollIntervalSec: 30     // 对齐 Web videoPollIntervalSec=30
    // 轮巡偏移: 当前展示的是 channels[offset..offset+layout-1]
    property int pollOffset: 0

    // ── 槽位模型 (对齐 Web VideoSlot) ──
    // 槽位数量固定为 4 (1分屏时只显示 slot[0]), 与 Web videoSlots 长度一致
    readonly property int slotCount: 4

    // 当前槽位对应的通道索引 (与 channel 在 channels 数组中的下标)
    property var slotChannelIdx: [0, 1, 2, 3]

    // ── 派生: 当前实际显示的槽位 (1分屏只显示 slot[0]) ──
    readonly property int visibleSlotCount: layout === 1 ? 1 : 4

    // 通道总数
    readonly property int channelTotal: situationController.channels.length

    // ── 工具: 根据通道索引解析字段 ──
    function channelAt(idx) {
        var arr = situationController.channels
        if (idx < 0 || idx >= arr.length) return null
        return arr[idx]
    }

    function channelIdOf(idx) {
        var c = channelAt(idx)
        if (!c) return ""
        return c.channelId || c.channel_id || c.id || ""
    }

    function channelDeviceIdOf(idx) {
        var c = channelAt(idx)
        if (!c) return ""
        return c.deviceId || c.device_id || ""
    }

    function channelNameOf(idx) {
        var c = channelAt(idx)
        if (!c) return ""
        return c.name || c.channel_name || c.deviceName || "未命名通道"
    }

    function channelCodecOf(idx) {
        var c = channelAt(idx)
        if (!c) return ""
        return c.codec || ""
    }

    // ── 槽位是否处于播放态 ──
    function slotPlaying(slotIdx) {
        var devId = channelDeviceIdOf(slotChannelIdx[slotIdx])
        if (!devId) return false
        var url = mediaController.streamUrls[devId] || ""
        return url !== "" && url !== undefined
    }

    function slotStreamUrl(slotIdx) {
        var devId = channelDeviceIdOf(slotChannelIdx[slotIdx])
        if (!devId) return ""
        return mediaController.streamUrls[devId] || ""
    }

    function slotLoading(slotIdx) {
        // 通道存在但 URL 还没返回 → loading
        var c = channelAt(slotChannelIdx[slotIdx])
        if (!c) return false
        return !slotPlaying(slotIdx)
    }

    // ── 轮巡控制 ──
    function startPolling() {
        if (!pollingActive) return
        // 立即触发一次刷新
        refreshCurrentSlots()
        pollTimer.interval = pollIntervalSec * 1000
        pollTimer.start()
    }

    function stopPolling() {
        pollTimer.stop()
    }

    function togglePolling() {
        pollingActive = !pollingActive
        if (pollingActive) startPolling()
        else stopPolling()
    }

    function refreshCurrentSlots() {
        var n = visibleSlotCount
        for (var i = 0; i < n; i++) {
            var idx = slotChannelIdx[i]
            var devId = channelDeviceIdOf(idx)
            var chId = channelIdOf(idx)
            if (devId && chId) {
                // 复用现有 startStream: 内部触发 multi-urls + start + 轮询 ZLM
                mediaController.startStream(devId, chId)
            }
        }
        // 切到下一批通道 (用于轮巡节奏)
        if (channelTotal > 0) {
            pollOffset = (pollOffset + visibleSlotCount) % channelTotal
            advanceSlots()
        }
    }

    function advanceSlots() {
        // 计算下一批可视通道索引, 写入 slotChannelIdx
        var ids = []
        for (var i = 0; i < slotCount; i++) {
            ids.push((pollOffset + i) % Math.max(1, channelTotal))
        }
        slotChannelIdx = ids
    }

    function setLayout(newLayout) {
        if (newLayout !== 1 && newLayout !== 4) return
        var wasLayout = layout
        layout = newLayout
        if (newLayout !== wasLayout) {
            // 切换分屏后立即刷新可见槽位
            advanceSlots()
            refreshCurrentSlots()
        }
    }

    // ── Timer: 30 秒轮巡 (对齐 Web videoPollIntervalSec) ──
    Timer {
        id: pollTimer
        interval: videoPatrolPanel.pollIntervalSec * 1000
        repeat: true
        onTriggered: videoPatrolPanel.refreshCurrentSlots()
    }

    // ── 启动: 进入面板即拉通道列表 + 启动轮巡 ──
    Component.onCompleted: {
        // 拉通道列表 (对齐 Web loadVideoDeviceList)
        situationController.refreshChannels(100)
    }

    // ── 监听 situationController 通道更新 (对齐 Web: loadVideoDeviceList → startVideoPolling) ──
    Connections {
        target: situationController
        function onChannelsUpdated() {
            if (videoPatrolPanel.pollingActive && videoPatrolPanel.channelTotal > 0) {
                videoPatrolPanel.advanceSlots()
                videoPatrolPanel.refreshCurrentSlots()
            }
        }
    }

    // ── 卸载: 停止所有推流, 释放 SIP 会话 ──
    Component.onDestruction: {
        pollTimer.stop()
        // 释放当前正在播放的通道
        for (var i = 0; i < videoPatrolPanel.slotCount; i++) {
            var chId = videoPatrolPanel.channelIdOf(videoPatrolPanel.slotChannelIdx[i])
            if (chId) mediaController.stopStream(chId)
        }
    }

    // ═══ 主视图: 视频宫格 ═══
    Grid {
        id: grid
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        columns: videoPatrolPanel.layout === 1 ? 1 : 2
        rows: videoPatrolPanel.layout === 1 ? 1 : 2

        Repeater {
            model: videoPatrolPanel.visibleSlotCount

            delegate: Rectangle {
                id: cell
                width: grid.width / grid.columns - grid.spacing
                height: grid.height / grid.rows - grid.spacing
                color: "#040C2B"
                border.color: videoPatrolPanel.slotPlaying(index) ? "#00B4FF" : "#05357C"
                border.width: videoPatrolPanel.slotPlaying(index) ? 2 : 1

                property int slotIdx: index
                property int channelIdx: videoPatrolPanel.slotChannelIdx[index]
                property bool isPlaying: videoPatrolPanel.slotPlaying(index)
                property bool isLoading: !isPlaying && videoPatrolPanel.channelAt(channelIdx) !== null
                property string chName: videoPatrolPanel.channelNameOf(channelIdx)
                property string chCodec: videoPatrolPanel.channelCodecOf(channelIdx)
                property string streamUrl: videoPatrolPanel.slotStreamUrl(index)

                // ── 视频输出 (Qt6: MediaPlayer.videoOutput 关联 VideoOutput, 不再是 VideoOutput.source) ──
                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    visible: cell.isPlaying
                }
                MediaPlayer {
                    id: mediaPlayer
                    videoOutput: videoOut
                    source: cell.streamUrl
                    audioOutput: AudioOutput { muted: true; volume: 0 }
                    onErrorOccurred: function (error, str) {
                        console.warn("[VideoPatrolPanel] media error", cell.chName, error, str)
                    }
                    onMediaStatusChanged: {
                        if (mediaStatus === MediaPlayer.LoadedMedia && cell.isPlaying) play()
                    }
                    Component.onCompleted: {
                        if (cell.streamUrl !== "") play()
                    }
                }

                // ── Loading 态 (对齐 Web vm-loading) ──
                Rectangle {
                    anchors.fill: parent
                    visible: cell.isLoading
                    color: "#040C2B"
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        BusyIndicator {
                            running: cell.isLoading
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32; height: 32
                        }
                        Text {
                            text: "连接中..."
                            color: "#00B4FF"
                            font.pixelSize: 13
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // ── Empty 态 (对齐 Web vm-empty) ──
                Rectangle {
                    anchors.fill: parent
                    visible: !cell.isPlaying && !cell.isLoading
                    color: "#040C2B"
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon {
                            name: "camera"
                            size: 32
                            iconColor: "#12305E"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: videoPatrolPanel.channelTotal > 0 ? "等待轮巡" : "无可用通道"
                            color: "#12305E"
                            font.pixelSize: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // ── 标签: 通道名 + codec (对齐 Web vm-label) ──
                Rectangle {
                    visible: cell.isPlaying
                    anchors.left: parent.left; anchors.bottom: parent.bottom
                    anchors.leftMargin: 6; anchors.bottomMargin: 6
                    height: 22; width: nameText.width + 16
                    color: Qt.rgba(0, 0, 0, 0.65)
                    radius: 3
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            id: nameText
                            text: cell.chName
                            color: "#FFFFFF"
                            font.pixelSize: 12
                        }
                        Rectangle {
                            visible: cell.chCodec !== ""
                            width: 32; height: 14; radius: 2
                            color: cell.chCodec.toUpperCase().indexOf("H265") >= 0 ||
                                   cell.chCodec.toUpperCase().indexOf("HEVC") >= 0 ? "#E85720" : "#1676D2"
                            Text {
                                anchors.centerIn: parent
                                text: cell.chCodec.toUpperCase().indexOf("H265") >= 0 ||
                                      cell.chCodec.toUpperCase().indexOf("HEVC") >= 0 ? "H265" : "H264"
                                color: "#FFFFFF"; font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 错误/空态覆盖层 (与 Web empty-state error 对齐) ═══
    Rectangle {
        anchors.fill: parent
        visible: situationController.channelsFailed && videoPatrolPanel.channelTotal === 0
        color: "transparent"
        Column {
            anchors.centerIn: parent
            spacing: 12
            Text {
                text: "通道列表加载失败"
                color: "#FC4F55"
                font.pixelSize: 15
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Button {
                text: "重试"
                width: 80; height: 28
                anchors.horizontalCenter: parent.horizontalCenter
                background: Rectangle { color: "#00B4FF"; radius: 4 }
                contentItem: Text {
                    text: parent.text
                    color: "#040C2B"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: situationController.refreshChannels(100)
            }
        }
    }
}