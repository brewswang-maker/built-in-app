// ========================================================================
// VideoGridView.qml — 视频预览宫格
// 功能: 1/4/9/16宫格 | PTZ控制 | 系统状态栏 | 多协议降级链 | PiP | 倍速 | 抓帧
// 规范: P0 #3 视频降级链 rtsp -> flv -> ws-flv -> hls -> webrtc
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Item {
    id: videoGridPage

    property int activeSlot: -1
    property bool isFullscreen: false
    property bool isPreviewActive: false

    // 当前应用的降级链(QML 会话级,支持用户切换)
    // [P1-B1 修复 2026-06-28] macOS Qt6 QtMultimedia 基于 AVFoundation, 不支持 RTSP/RTMP/FLV
    //   (仅原生支持 HLS 和 HTTP 渐进式下载)。首项 rtsp 在 macOS 上总是失败,需绕过。
    //   检测 Qt.platform.os === "osx" 时, 默认链改为 ["webrtc","ws-flv","hls","flv","rtsp"]
    //   — webrtc/ws-flv 是 C++ 后端通过 WebRTCStreamProvider 提供的 fallback 路径,
    //   在 macOS 上可正常播放 (对标海康 iVMS-8700 macOS 版同样默认走 WebRTC)。
    //   Windows/Linux 上 QtMultimedia 支持更广泛,保持原默认 ["rtsp","flv",...].
    readonly property var _defaultProtocolChain:
        Qt.platform.os === "osx"
            ? ["webrtc", "ws-flv", "hls", "flv", "rtsp"]   // macOS: WebRTC 优先
            : ["rtsp", "flv", "ws-flv", "hls", "webrtc"];  // 其他: RTSP 优先
    property var protocolChain: _defaultProtocolChain
    // PiP 状态(由 mediaController 统一管理,这里只读镜像)
    property bool pipActive: mediaController.pipChannelId !== ""
    property string pipChannelId: mediaController.pipChannelId
    // 抓帧 / 协议 提示信息
    property string toastText: ""
    property string toastKind: "info"   // info | ok | warn | error
    // 当前选中的播放倍速(同步到 mediaController)
    property real playbackRate: mediaController.playbackRate

    // [V4-V4] 自动轮巡
    property bool autoPatrol: false
    property int autoPatrolInterval: 10  // 秒, 对标海康 iVMS-8700 默认值

    // [V4-V5] 3D PTZ 点击定位模式
    property bool ptz3DMode: false

    // [P1-3] 画面调节属性 (对标 Web 端 LiveView.vue imageAdjust)
    property real imgBrightness: 0.0   // -0.5 ~ 0.5
    property real imgContrast: 1.0     // 0.0 ~ 2.0
    property real imgSaturation: 1.0   // 0.0 ~ 2.0
    property bool mirrorH: false
    property bool mirrorV: false

    // [RC10] 计算是否有在线设备 — 用于禁用"开始预览"按钮
    readonly property bool hasOnlineDevice: {
        for (var i = 0; i < deviceController.devices.length; i++) {
            var dev = deviceController.devices[i]
            if ((dev.status || "offline") === "online")
                return true
        }
        return false
    }

    // Helper: get device ID for a slot index
    function slotDeviceId(slot) {
        if (slot >= 0 && slot < deviceController.devices.length)
            return deviceController.devices[slot].id || deviceController.devices[slot].device_id || ""
        return ""
    }
    function slotChannelId(slot) {
        if (slot >= 0 && slot < deviceController.devices.length)
            return deviceController.devices[slot].id || deviceController.devices[slot].device_id || ""
        return ""
    }

    // Request stream for a slot (with the current degradation chain)
    // [RC10] 增加设备在线状态预检查
    function requestStream(slot) {
        var devId = slotDeviceId(slot)
        if (devId.length > 0) {
            // 检查设备在线状态
            if (slot < deviceController.devices.length) {
                var devStatus = deviceController.devices[slot].status || "offline"
                if (devStatus !== "online") {
                    videoGridPage.showToast("设备离线，无法预览", "warn")
                    return
                }
            }
            mediaController.startStreamWithProtocols(
                devId, slotChannelId(slot), protocolChain)
        }
    }

    // [RC10] 同步设备在线状态到 MediaController（在拉流前调用）
    function syncDeviceOnlineStatus() {
        for (var i = 0; i < deviceController.devices.length; i++) {
            var dev = deviceController.devices[i]
            var devId = dev.id || dev.device_id || ""
            if (devId.length > 0) {
                var isOnline = (dev.status || "offline") === "online"
                mediaController.setDeviceOnlineStatus(devId, isOnline)
            }
        }
    }

    // Request streams for all visible slots via single batch API call.
    // [RC10] 增加设备在线状态过滤：离线设备跳过，并弹出 Toast 提示
    function requestAllStreams() {
        // 先同步设备在线状态到 MediaController（防御性后端检查）
        syncDeviceOnlineStatus()

        var devIds = []
        var offlineSkipped = 0
        var count = Math.min(mediaController.currentLayout, deviceController.devices.length)
        for (var i = 0; i < count; i++) {
            var dev = deviceController.devices[i]
            var devStatus = dev.status || "offline"
            if (devStatus !== "online") {
                offlineSkipped++
                continue  // 跳过离线设备
            }
            var id = dev.id || dev.device_id || ""
            if (id.length > 0)
                devIds.push(id)
        }

        // 有离线设备时弹出提示
        if (offlineSkipped > 0) {
            videoGridPage.showToast(
                offlineSkipped + " 台设备离线，已跳过拉流", "warn")
        }

        if (devIds.length > 0)
            mediaController.refreshAllStreamUrls(devIds)
    }

    // 通用 Toast 提示
    function showToast(text, kind) {
        toastText = text
        toastKind = kind || "info"
        toastTimer.restart()
    }

    // ═══ 工具栏 ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141420"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8

            Text { text: "视频预览"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            // 通道名
            Text {
                text: activeSlot >= 0 && activeSlot < deviceController.devices.length ?
                    (deviceController.devices[activeSlot].name || deviceController.devices[activeSlot].device_name || "") : ""
                // [P2-B3] 通道名 (14px 规范最小)
                font.pixelSize: 14; color: "#3B82F6"
                visible: text !== ""
            }

            Item { Layout.fillWidth: true }

            // 预览开关
            Button {
                id: previewToggleBtn
                width: 84; height: 32
                text: videoGridPage.isPreviewActive ? "停止预览" : "开始预览"
                // [P2-B3] "开始/停止预览" Button 文字: 12 → 13 (合规)
                                font.pixelSize: 13
                // [RC10] 全部设备离线时禁用"开始预览"（但允许"停止预览"）
                enabled: videoGridPage.isPreviewActive || videoGridPage.hasOnlineDevice
                opacity: enabled ? 1.0 : 0.4
                highlighted: videoGridPage.isPreviewActive
                onClicked: {
                    videoGridPage.isPreviewActive = !videoGridPage.isPreviewActive
                    if (videoGridPage.isPreviewActive) {
                        videoGridPage.requestAllStreams()
                        videoGridPage.showToast("预览已开启", "ok")
                    } else {
                        mediaController.stopAllStreams()
                        videoGridPage.showToast("预览已停止", "info")
                    }
                }
                background: Rectangle {
                    color: previewToggleBtn.highlighted ? "#FF3D71" : "#00D4AA"
                    radius: 4
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                contentItem: Text {
                    text: previewToggleBtn.text
                    // [P2-B3] "开始/停止预览" Button 文字: 12 → 13 (合规)
                                    font.pixelSize: 13
                    font.bold: true
                    color: "#0D0F12"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 宫格切换
            Row { spacing: 4
                Repeater {
                    model: [1, 4, 9, 16]
                    delegate: Button {
                        id: layoutBtn
                        width: 40; height: 32
                        text: modelData === 1 ? "单" : String(modelData)
                        // [P2-B3] "开始/停止预览" Button 文字: 12 → 13 (合规)
                                        font.pixelSize: 13
                        highlighted: mediaController.currentLayout === modelData
                        onClicked: {
                            mediaController.currentLayout = modelData
                        }
                        background: Rectangle {
                            color: layoutBtn.highlighted ? "#00D4AA" : "#252830"
                            radius: 4
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        contentItem: Text {
                            text: layoutBtn.text
                            // [P2-B3] "开始/停止预览" Button 文字: 12 → 13 (合规)
                                            font.pixelSize: 13
                            font.bold: layoutBtn.highlighted
                            color: layoutBtn.highlighted ? "#0D0F12" : "#8B8FA3"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: "#252830" }

            // 协议降级链选择器 (规范 P0 #3)
            ComboBox {
                id: protocolSelector
                width: 140; height: 30
                font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
                model: [
                    { text: "RTSP (优先)", value: ["rtsp", "flv", "ws-flv", "hls", "webrtc"] },
                    { text: "FLV (Web)", value: ["flv", "ws-flv", "hls", "rtsp", "webrtc"] },
                    { text: "WS-FLV (低延迟)", value: ["ws-flv", "flv", "rtsp", "hls", "webrtc"] },
                    { text: "HLS (兼容)", value: ["hls", "ws-flv", "flv", "rtsp", "webrtc"] },
                    { text: "WebRTC (P2P)", value: ["webrtc", "ws-flv", "flv", "hls", "rtsp"] }
                ]
                textRole: "text"
                valueRole: "value"
                currentIndex: 0
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: protocolSelector.model[protocolSelector.currentIndex].text
                    color: "#E8E8E8"; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                }
                onActivated: {
                    videoGridPage.protocolChain = currentValue
                    videoGridPage.showToast("降级链已切换: " + currentText, "info")
                    videoGridPage.requestAllStreams()
                }
                ToolTip.visible: hovered
                ToolTip.text: "P0#3 视频降级链 (rtsp/flv/ws-flv/hls/webrtc)"
            }

            // 倍速选择 (1x/2x/4x)
            ComboBox {
                id: rateSelector
                width: 70; height: 30
                font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
                model: mediaController.supportedPlaybackRates()
                currentIndex: 0
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: parseFloat(mediaController.supportedPlaybackRates()[rateSelector.currentIndex]) + "x"
                    color: "#E8E8E8"; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                onActivated: {
                    var r = mediaController.supportedPlaybackRates()[currentIndex]
                    mediaController.playbackRate = r
                    videoGridPage.playbackRate = r
                    videoGridPage.showToast("倍速切换: " + r + "x", "info")
                }
            }

            // PiP 开关
            Button {
                id: pipButton
                text: pipActive ? "退出画中画" : "画中画"
                font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
                enabled: activeSlot >= 0
                onClicked: {
                    if (pipActive) {
                        mediaController.exitPip()
                        videoGridPage.showToast("已退出画中画", "info")
                    } else if (activeSlot >= 0) {
                        mediaController.enterPip(videoGridPage.slotChannelId(activeSlot))
                        videoGridPage.showToast("画中画: " + videoGridPage.slotDeviceId(activeSlot), "info")
                    }
                }
                background: Rectangle {
                    color: pipActive ? "#00D4AA" : "#252830"
                    radius: 6; width: 90; height: 30
                }
                contentItem: Text {
                    text: pipButton.text; font.pixelSize: 12
                    color: pipActive ? "#0D0F12" : "#E8E8E8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 操作按钮
            Button {
                text: "抓帧"; font.pixelSize: 12
                enabled: activeSlot >= 0
                onClicked: mediaController.snapshotToFile(
                    videoGridPage.slotChannelId(activeSlot))
                background: Rectangle { color: "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button { text: mediaController.isRecording ? "停止" : "录像"; font.pixelSize: 12
                onClicked: mediaController.isRecording ? mediaController.stopRecording(slotChannelId(activeSlot)) : mediaController.startRecording(slotChannelId(activeSlot))
                background: Rectangle { color: mediaController.isRecording ? "#FF3D71" : "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: mediaController.isRecording ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                id: talkBtn
                property bool talkActive: false
                text: talkActive ? "停止" : "对讲"; font.pixelSize: 12
                background: Rectangle { color: talkBtn.talkActive ? "#FF3D71" : "#252830"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: talkBtn.text; font.pixelSize: 12; color: talkBtn.talkActive ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (talkBtn.talkActive) {
                        mediaController.stopTalk()
                        talkBtn.talkActive = false
                        videoGridPage.showToast("对讲已停止", "info")
                    } else {
                        mediaController.startTalk(videoGridPage.slotChannelId(activeSlot))
                        talkBtn.talkActive = true
                        videoGridPage.showToast("对讲已建立", "ok")
                    }
                }
            }
            Button { text: "全屏"; font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    isFullscreen = !isFullscreen
                    if (isFullscreen && activeSlot >= 0) mediaController.currentLayout = 1
                    else mediaController.currentLayout = 4
                }
            }

            // [V4-V4] 自动轮巡
            Button {
                id: patrolBtn
                width: 84; height: 32
                text: videoGridPage.autoPatrol ? "停止轮巡" : "自动轮巡"
                font.pixelSize: 12
                enabled: videoGridPage.isPreviewActive && videoGridPage.hasOnlineDevice
                opacity: enabled ? 1.0 : 0.4
                highlighted: videoGridPage.autoPatrol
                onClicked: {
                    videoGridPage.autoPatrol = !videoGridPage.autoPatrol
                    if (videoGridPage.autoPatrol) {
                        videoGridPage.activeSlot = 0
                        mediaController.currentLayout = 1
                        videoGridPage.showToast("自动轮巡已开启 · 间隔 " + videoGridPage.autoPatrolInterval + "s", "ok")
                    } else {
                        videoGridPage.showToast("自动轮巡已停止", "info")
                    }
                }
                background: Rectangle {
                    color: patrolBtn.highlighted ? "#FFB800" : "#252830"
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                contentItem: Text {
                    text: patrolBtn.text; font.pixelSize: 12; font.bold: true
                    color: patrolBtn.highlighted ? "#0D0F12" : "#E8E8E8"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ═══ 主内容区 ═══
    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: statusBar.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 4; spacing: 4

        // ═══ 左侧: 通道列表 (始终可见) ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 180; color: "#141420"; radius: 8
            visible: true

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 4

                Text { text: "通道列表"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 16; height: parent.height - 100; spacing: 4; clip: true
                    model: deviceController.devices

                    delegate: Rectangle {
                        width: ListView.view.width; height: 36; radius: 4
                        color: videoGridPage.activeSlot === index ? "#1A3A2A" : "#0D0F12"
                        border.color: videoGridPage.activeSlot === index ? "#00D4AA" : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData.status === "online" ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.name || modelData.device_name || ("CH" + (index + 1)); font.pixelSize: 12; color: videoGridPage.activeSlot === index ? "#00D4AA" : "#E8E8E8"; width: 100; elide: Text.ElideRight }
                            Text { text: modelData.status === "online" ? "●" : "○"; font.pixelSize: 12; color: modelData.status === "online" ? "#00D4AA" : "#4A4D58" }
                        }
                        MouseArea { anchors.fill: parent; onClicked: videoGridPage.activeSlot = index }
                    }
                }

                TextField {
                    width: parent.width - 16; height: 28; placeholderText: "搜索通道..."
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
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
                    deviceId: index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                    channelName: index < deviceController.devices.length ? (deviceController.devices[index].name || deviceController.devices[index].device_name || ("Camera_" + (index + 1))) : ("Camera_" + (index + 1))
                    status: index < deviceController.devices.length ? (deviceController.devices[index].status || "offline") : "offline"
                    algorithmTag: index < deviceController.devices.length ? (deviceController.devices[index].algorithm || "") : ""
                    streamUrl: isPreviewActive ? (mediaController.streamUrls[
                        index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                    ] || "") : ""
                    active: videoGridPage.activeSlot === index
                    // [P1-3] 画面调节绑定
                    imgBrightness: videoGridPage.imgBrightness
                    imgContrast: videoGridPage.imgContrast
                    imgSaturation: videoGridPage.imgSaturation
                    mirrorH: videoGridPage.mirrorH
                    mirrorV: videoGridPage.mirrorV
                    // P1-1: AI detection overlay binding
                    detectionBoxes: {
                        var devId = index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                        return mediaController.detections[devId] || []
                    }

                    // 双击全屏 + [V4-V4] eZoom 控制
                    MouseArea {
                        anchors.fill: parent; z: 10; propagateComposedEvents: true
                        property real _panStartX: 0
                        property real _panStartY: 0
                        property real _panStartOffX: 0.5
                        property real _panStartOffY: 0.5

                        onDoubleClicked: {
                            if (parent.eZoomLevel > 1.0) {
                                parent.eZoomLevel = 1.0
                                parent.eZoomOffsetX = 0.5
                                parent.eZoomOffsetY = 0.5
                            } else {
                                videoGridPage.activeSlot = index
                                mediaController.currentLayout = 1
                                videoGridPage.isFullscreen = true
                            }
                        }
                        onClicked: {
                            videoGridPage.activeSlot = index
                            // [V4-V5] 3D 定位模式: 点击画面 → PTZ 移动到该点
                            if (videoGridPage.ptz3DMode && parent.active) {
                                var xPct = mouseX / parent.width
                                var yPct = mouseY / parent.height
                                // 归一化坐标 → PTZ 方向 (中心0.5,0.5)
                                var dx = (xPct - 0.5) * 2.0  // -1.0~1.0
                                var dy = (yPct - 0.5) * 2.0
                                var dir = ""
                                if (Math.abs(dx) < 0.15 && Math.abs(dy) < 0.15) {
                                    // 中心区域 → 无需移动
                                    videoGridPage.showToast("3D定位: 目标已在中心", "info")
                                } else {
                                    // 发送 PTZ 方向+速度 (速度与距离成正比)
                                    var speed = Math.min(Math.sqrt(dx*dx + dy*dy), 1.0)
                                    if (Math.abs(dx) > Math.abs(dy)) {
                                        dir = dx > 0 ? "right" : "left"
                                    } else {
                                        dir = dy > 0 ? "down" : "up"
                                    }
                                    mediaController.ptzControl(index, dir, speed)
                                    videoGridPage.showToast("3D定位: " + dir + " (速度 " + speed.toFixed(2) + ")", "ok")
                                }
                                mouse.accepted = true
                            } else {
                                mouse.accepted = false
                            }
                        }
                        // [V4-V4] 滚轮缩放
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0)
                                parent.eZoomLevel = Math.min(parent.eZoomLevel + 0.25, 4.0)
                            else {
                                parent.eZoomLevel = Math.max(parent.eZoomLevel - 0.25, 1.0)
                                if (parent.eZoomLevel <= 1.0) {
                                    parent.eZoomOffsetX = 0.5
                                    parent.eZoomOffsetY = 0.5
                                }
                            }
                        }
                        // [V4-V4] 拖拽平移 (放大时拦截, 正常时穿透)
                        onPressed: {
                            _panStartX = mouseX
                            _panStartY = mouseY
                            _panStartOffX = parent.eZoomOffsetX
                            _panStartOffY = parent.eZoomOffsetY
                            mouse.accepted = parent.eZoomLevel > 1.0
                        }
                        onPositionChanged: {
                            if (parent.eZoomLevel > 1.0 && pressed) {
                                var dx = (mouseX - _panStartX) / parent.width / parent.eZoomLevel
                                var dy = (mouseY - _panStartY) / parent.height / parent.eZoomLevel
                                parent.eZoomOffsetX = Math.max(0, Math.min(1, _panStartOffX - dx))
                                parent.eZoomOffsetY = Math.max(0, Math.min(1, _panStartOffY - dy))
                            }
                        }
                    }
                }
            }
        }

        // ═══ 右侧: PTZ控制面板 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 170; color: "#141420"; radius: 8
            visible: mediaController.currentLayout === 1 && activeSlot >= 0

            ScrollView {
                anchors.fill: parent; clip: true

                Column {
                    width: 154; spacing: 8; padding: 8

                    Text { text: "云台控制"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; width: parent.width }

                    // PTZ方向盘 (Canvas绘制)
                    Canvas {
                        id: ptzCanvas
                        width: 140; height: 140
                        property string activeDir: ""

                        onPaint: {
                            var ctx = getContext("2d")
                            var cx = 70, cy = 70, r = 55
                            ctx.clearRect(0, 0, width, height)

                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.fillStyle = "#0D0F12"; ctx.fill()
                            ctx.strokeStyle = "#252830"; ctx.lineWidth = 2; ctx.stroke()

                            var dirs = ["up", "right_up", "right", "right_down", "down", "left_down", "left", "left_up"]
                            var labels = ["U", "UR", "R", "DR", "D", "DL", "L", "UL"]
                            for (var i = 0; i < 8; i++) {
                                var angle = (i / 8) * 2 * Math.PI - Math.PI / 2
                                var bx = cx + Math.cos(angle) * 38
                                var by = cy + Math.sin(angle) * 38
                                ctx.beginPath(); ctx.arc(bx, by, 14, 0, 2 * Math.PI)
                                ctx.fillStyle = activeDir === dirs[i] ? "#3B82F6" : "#252830"; ctx.fill()
                                ctx.fillStyle = activeDir === dirs[i] ? "#FFF" : "#8B8FA3"
                                ctx.font = "11px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"
                                ctx.fillText(labels[i], bx, by)
                            }

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

                    Text { text: "速度: " + ptzSpeed.value.toFixed(1); font.pixelSize: 12; color: "#8B8FA3" }
                    Slider { id: ptzSpeed; width: 140; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.1 }

                    // [V4-V5] 3D 点击定位
                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }
                    Text { text: "3D定位"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Button {
                        width: parent.width - 16; height: 28
                        text: videoGridPage.ptz3DMode ? "● 3D定位已开启" : "开启3D定位"
                        font.pixelSize: 12
                        highlighted: videoGridPage.ptz3DMode
                        onClicked: {
                            videoGridPage.ptz3DMode = !videoGridPage.ptz3DMode
                            if (videoGridPage.ptz3DMode) {
                                videoGridPage.showToast("3D定位已开启\n点击画面任意位置控制云台", "ok")
                            } else {
                                videoGridPage.showToast("3D定位已关闭", "info")
                            }
                        }
                        background: Rectangle {
                            color: videoGridPage.ptz3DMode ? "#3B82F6" : "#252830"
                            radius: 4
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        contentItem: Text {
                            text: parent.text; font.pixelSize: 12
                            color: videoGridPage.ptz3DMode ? "#FFF" : "#E8E8E8"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text { text: "变倍 Zoom"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4
                        Button { width: 60; height: 26; text: "-"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "zoom_out", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { width: 60; height: 26; text: "+"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "zoom_in", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Text { text: "焦距 Focus"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4
                        Button { width: 60; height: 26; text: "近"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "focus_near", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { width: 60; height: 26; text: "远"; font.pixelSize: 12
                            onClicked: mediaController.ptzControl(activeSlot, "focus_far", 0.3)
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }

                    // [P1-3] 画面调节
                    Text { text: "画面调节"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Row {
                        spacing: 4
                        Button {
                            width: 64; height: 26; text: videoGridPage.mirrorH ? "● 水平镜像" : "水平镜像"; font.pixelSize: 12
                            highlighted: videoGridPage.mirrorH
                            onClicked: videoGridPage.mirrorH = !videoGridPage.mirrorH
                            background: Rectangle { color: videoGridPage.mirrorH ? "#3B82F6" : "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: videoGridPage.mirrorH ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            width: 64; height: 26; text: videoGridPage.mirrorV ? "● 垂直翻转" : "垂直翻转"; font.pixelSize: 12
                            highlighted: videoGridPage.mirrorV
                            onClicked: videoGridPage.mirrorV = !videoGridPage.mirrorV
                            background: Rectangle { color: videoGridPage.mirrorV ? "#3B82F6" : "#252830"; radius: 4 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: videoGridPage.mirrorV ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    // 亮度
                    Text { text: "亮度: " + (videoGridPage.imgBrightness * 100).toFixed(0) + "%"; font.pixelSize: 12; color: "#8B8FA3" }
                    Slider {
                        width: 140; from: -0.5; to: 0.5; value: 0.0; stepSize: 0.05
                        onValueChanged: videoGridPage.imgBrightness = value
                        Component.onCompleted: value = videoGridPage.imgBrightness
                    }
                    // 对比度
                    Text { text: "对比度: " + (videoGridPage.imgContrast * 100).toFixed(0) + "%"; font.pixelSize: 12; color: "#8B8FA3" }
                    Slider {
                        width: 140; from: 0.0; to: 2.0; value: 1.0; stepSize: 0.05
                        onValueChanged: videoGridPage.imgContrast = value
                        Component.onCompleted: value = videoGridPage.imgContrast
                    }
                    // 饱和度
                    Text { text: "饱和度: " + (videoGridPage.imgSaturation * 100).toFixed(0) + "%"; font.pixelSize: 12; color: "#8B8FA3" }
                    Slider {
                        width: 140; from: 0.0; to: 2.0; value: 1.0; stepSize: 0.05
                        onValueChanged: videoGridPage.imgSaturation = value
                        Component.onCompleted: value = videoGridPage.imgSaturation
                    }
                    // 重置按钮
                    Button {
                        width: parent.width - 16; height: 26; text: "重置画面"; font.pixelSize: 12
                        onClicked: {
                            videoGridPage.imgBrightness = 0.0
                            videoGridPage.imgContrast = 1.0
                            videoGridPage.imgSaturation = 1.0
                            videoGridPage.mirrorH = false
                            videoGridPage.mirrorV = false
                        }
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }

                    // 预置位
                    Text { text: "预置位"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Grid {
                        columns: 3; spacing: 4
                        Repeater {
                            model: 6
                            delegate: Button {
                                width: 42; height: 28; text: "P" + (index + 1)
                                font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
                                onClicked: mediaController.ptzGotoPreset(activeSlot, index + 1)
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onPressAndHold: mediaController.ptzSetPreset(activeSlot, index + 1)
                            }
                        }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width - 16 }

                    // 轮巡/巡航
                    Text { text: "轮巡/巡航"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                    Row { spacing: 4
                        Button { text: "开始"; font.pixelSize: 12
                            onClicked: mediaController.startPatrol(slotDeviceId(activeSlot))
                            background: Rectangle { color: "#00D4AA"; radius: 4; width: 50; height: 26 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { text: "停止"; font.pixelSize: 12
                            onClicked: mediaController.stopPatrol(slotDeviceId(activeSlot))
                            background: Rectangle { color: "#FF3D71"; radius: 4; width: 50; height: 26 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    // 巡航路径选择 (P0-2 对标海康 PTZ)
                    Row { spacing: 4
                        Button { text: "路径1"; font.pixelSize: 12  // [Audit-Fix P1] 10→12 (规范最小)
                            onClicked: mediaController.ptzControl(activeSlot, "cruise_start", 1)
                            background: Rectangle { color: "#252830"; radius: 4; width: 46; height: 24 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { text: "路径2"; font.pixelSize: 12  // [Audit-Fix P1] 10→12 (规范最小)
                            onClicked: mediaController.ptzControl(activeSlot, "cruise_start", 2)
                            background: Rectangle { color: "#252830"; radius: 4; width: 46; height: 24 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { text: "轨迹1"; font.pixelSize: 12  // [Audit-Fix P1] 10→12 (规范最小)
                            onClicked: mediaController.ptzControl(activeSlot, "track_start", 1)
                            background: Rectangle { color: "#252830"; radius: 4; width: 46; height: 24 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }
    }

    // ═══ 底部: 系统状态栏 ═══
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 40; color: "#0D0F12"; radius: 0

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 24

            // 系统状态标识
            Rectangle {
                width: 8; height: 8; radius: 4
                color: statusController.networkStatus === "Connected" ? "#00D4AA" : "#FF3D71"
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: statusController.networkStatus === "Connected" ? "系统正常" : "连接断开"
                font.pixelSize: 12; color: statusController.networkStatus === "Connected" ? "#00D4AA" : "#FF3D71"
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle { width: 1; height: 16; color: "#252830"; Layout.alignment: Qt.AlignVCenter }

            // CPU
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "CPU"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: (statusController.cpuUsage * 100).toFixed(0) + "%"
                    font.pixelSize: 12; font.bold: true
                    color: statusController.cpuUsage > 0.9 ? "#FF3D71" : statusController.cpuUsage > 0.7 ? "#FFB800" : "#00D4AA"
                }
                ProgressBar {
                    width: 60; height: 6; from: 0; to: 1
                    value: statusController.cpuUsage
                    background: Rectangle { color: "#252830"; radius: 3 }
                    contentItem: Item {
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height; radius: 3
                            color: statusController.cpuUsage > 0.9 ? "#FF3D71" : statusController.cpuUsage > 0.7 ? "#FFB800" : "#00D4AA"
                        }
                    }
                }
            }

            // 内存
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "MEM"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: (statusController.memoryUsage * 100).toFixed(0) + "%"
                    font.pixelSize: 12; font.bold: true
                    color: statusController.memoryUsage > 0.9 ? "#FF3D71" : statusController.memoryUsage > 0.7 ? "#FFB800" : "#00D4AA"
                }
                ProgressBar {
                    width: 60; height: 6; from: 0; to: 1
                    value: statusController.memoryUsage
                    background: Rectangle { color: "#252830"; radius: 3 }
                    contentItem: Item {
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height; radius: 3
                            color: statusController.memoryUsage > 0.9 ? "#FF3D71" : statusController.memoryUsage > 0.7 ? "#FFB800" : "#00D4AA"
                        }
                    }
                }
            }

            // TPU
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "TPU"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: (statusController.tpuUtilization * 100).toFixed(0) + "%"
                    font.pixelSize: 12; font.bold: true
                    color: statusController.tpuUtilization > 0.9 ? "#FF3D71" : statusController.tpuUtilization > 0.7 ? "#FFB800" : "#00D4AA"
                }
                ProgressBar {
                    width: 60; height: 6; from: 0; to: 1
                    value: statusController.tpuUtilization
                    background: Rectangle { color: "#252830"; radius: 3 }
                    contentItem: Item {
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height; radius: 3
                            color: statusController.tpuUtilization > 0.9 ? "#FF3D71" : statusController.tpuUtilization > 0.7 ? "#FFB800" : "#00D4AA"
                        }
                    }
                }
            }

            // 温度
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "TEMP"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: statusController.temperature.toFixed(1) + "°C"
                    font.pixelSize: 12; font.bold: true
                    color: statusController.temperature > 75 ? "#FF3D71" : statusController.temperature > 60 ? "#FFB800" : "#00D4AA"
                }
            }

            Rectangle { width: 1; height: 16; color: "#252830"; Layout.alignment: Qt.AlignVCenter }

            // 模型数
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "模型"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: statusController.activeModels + " 活跃"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true }
            }

            // 运行时间
            Row { spacing: 4; Layout.alignment: Qt.AlignVCenter
                Text { text: "运行"; font.pixelSize: 12; color: "#8B8FA3" }
                Text { text: statusController.uptime || "--"; font.pixelSize: 12; color: "#8B8FA3" }
            }

            Item { Layout.fillWidth: true }

            // 时间
            Text {
                text: statusController.systemTime || Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                font.pixelSize: 12; color: "#8B8FA3"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ═══ 启动时请求所有视频流 ═══
    Connections {
        target: mediaController
        function onLayoutChanged() {
            if (isPreviewActive) requestAllStreams()
        }
        function onPipChanged() {
            videoGridPage.pipChannelId = mediaController.pipChannelId
        }
        function onPlaybackRateChanged() {
            videoGridPage.playbackRate = mediaController.playbackRate
        }
        function onSnapshotSaved(channelId, filePath) {
            videoGridPage.showToast("抓帧已保存: " + filePath, "ok")
        }
        function onSnapshotFailed(channelId, code, message) {
            videoGridPage.showToast("抓帧失败 [" + code + "]: " + message, "error")
        }
    }

    // 降级链事件: protocolFailed / activeProtocolChanged
    Connections {
        target: mediaController.degradation
        function onProtocolFailed(deviceId, failed, next) {
            if (next && next.length > 0)
                videoGridPage.showToast(
                    "协议 " + failed + " 失败,已切换到 " + next, "warn")
            else
                videoGridPage.showToast(
                    "协议 " + failed + " 失败,降级链已耗尽", "error")
        }
        function onActiveProtocolChanged(deviceId, protocol) {
            // 静默更新,仅在状态栏或 tile 角标体现
        }
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() {
            if (isPreviewActive) requestAllStreams()
        }
    }

    // ═══ PiP 浮层 (右下角) ═══
    Rectangle {
        id: pipOverlay
        visible: pipActive
        width: Math.min(parent.width * 0.28, 360)
        height: Math.min(parent.height * 0.32, 240)
        anchors.right: parent.right; anchors.bottom: statusBar.top
        anchors.margins: 12
        color: "#0D0F12"; radius: 8
        border.color: "#00D4AA"; border.width: 1
        z: 50

        VideoTile {
            id: pipTile
            anchors.fill: parent; anchors.margins: 2
            deviceId: videoGridPage.pipChannelId
            channelName: "PiP"
            status: "online"
            algorithmTag: ""
            streamUrl: isPreviewActive ? (mediaController.streamUrls[videoGridPage.pipChannelId] || "") : ""
            active: true
        }
        MouseArea {
            anchors.top: parent.top; anchors.right: parent.right
            width: 28; height: 28
            onClicked: mediaController.exitPip()
            Rectangle { anchors.fill: parent; color: "transparent" }
            Text {
                anchors.centerIn: parent
                text: "X"; color: "#E8E8E8"; font.pixelSize: 14
            }
        }
    }

    // ═══ Toast 提示 (右下角底部) ═══
    Rectangle {
        id: toastPopup
        visible: toastText.length > 0
        anchors.bottom: pipActive ? pipOverlay.top : statusBar.top
        anchors.right: parent.right; anchors.margins: 12
        height: 36; width: toastText.length * 12 + 32
        radius: 6; z: 60
        color: {
            switch (toastKind) {
                case "ok":    return "#1A3A2A"
                case "warn":  return "#3A2A1A"
                case "error": return "#3A1A2A"
                default:      return "#141420"
            }
        }
        border.color: {
            switch (toastKind) {
                case "ok":    return "#00D4AA"
                case "warn":  return "#FFB800"
                case "error": return "#FF3D71"
                default:      return "#3B82F6"
            }
        }
        border.width: 1

        Text {
            anchors.fill: parent; anchors.margins: 8
            text: toastText; color: "#E8E8E8"; font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        Timer {
            id: toastTimer
            interval: 3500
            onTriggered: videoGridPage.toastText = ""
        }
    }

    // [V4-V4] 自动轮巡 Timer — 每 autoPatrolInterval 秒切换到下一个在线通道
    Timer {
        id: autoPatrolTimer
        interval: videoGridPage.autoPatrolInterval * 1000
        repeat: true
        running: videoGridPage.autoPatrol && videoGridPage.isPreviewActive
        onTriggered: {
            var devCount = deviceController.devices.length
            if (devCount <= 1) return
            // 找到下一个在线通道
            var nextSlot = videoGridPage.activeSlot
            for (var i = 0; i < devCount; i++) {
                nextSlot = (nextSlot + 1) % devCount
                var dev = deviceController.devices[nextSlot]
                if ((dev.status || "offline") === "online") {
                    videoGridPage.activeSlot = nextSlot
                    return
                }
            }
        }
    }

    Component.onCompleted: {
        // Preview starts manually via the toolbar toggle button.
    }
}
