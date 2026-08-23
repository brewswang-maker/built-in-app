// ========================================================================
// VideoGridView.qml — 实时视频 (v7.7 1:1 对齐 Web LiveView 截图)
//
// 布局 (对齐 Web live-page):
//   左侧 3/4: 视频卡片 — 工具栏(通道名|播放格式|分屏|截图|录像|码流|图像|轮巡|全屏)
//             + N分屏网格 (空格: 摄像机图标+"拖拽通道到此处")
//   右侧 1/4: 通道列表卡片(搜索+通道项+状态标签) + PTZ 云台卡片
//             (方向盘|变倍|聚焦|光圈|雨刷灯光加热|速度|预置位|巡航|轨迹|3D提示)
//
// 数据源: deviceController(通道) + mediaController(拉流/PTZ/录像/抓帧)
//   协议降级链保持 P0#3 规范; 无能力项(子码流/统计面板)如实提示不造假
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: videoGridPage

    property int activeSlot: -1
    property bool isFullscreen: false
    property bool isPreviewActive: false

    // 降级链 (P0#3): 会话级, 随播放格式切换
    readonly property var _defaultProtocolChain:
        Qt.platform.os === "osx"
            ? ["webrtc", "ws-flv", "hls", "flv", "rtsp"]
            : ["flv", "ws-flv", "hls", "rtsp", "webrtc"]  // 对齐截图默认 HTTP-FLV
    property var protocolChain: _defaultProtocolChain

    property string toastText: ""
    property string toastKind: "info"   // info | ok | warn | error
    property string chSearch: ""

    // 巡航/轨迹状态 (对齐 Web isCruising / isTracking)
    property bool isCruising: false
    property bool isTracking: false

    // [V4-V4] 自动轮巡
    property bool autoPatrol: false
    property int autoPatrolInterval: 10

    // [V4-V5] 3D PTZ 点击定位模式
    property bool ptz3DMode: false

    // [P1-3] 画面调节 (图像弹窗绑定)
    property real imgBrightness: 0.0
    property real imgContrast: 1.0
    property real imgSaturation: 1.0
    property bool mirrorH: false
    property bool mirrorV: false

    readonly property bool hasOnlineDevice: {
        for (var i = 0; i < deviceController.devices.length; i++) {
            if ((deviceController.devices[i].status || "offline") === "online")
                return true
        }
        return false
    }

    // 当前选中通道名 (对齐 Web activeChannelName)
    readonly property string activeChannelName:
        activeSlot >= 0 && activeSlot < deviceController.devices.length
        ? (deviceController.devices[activeSlot].name || deviceController.devices[activeSlot].device_name || ("CH" + (activeSlot + 1)))
        : "未选择通道"

    function slotDeviceId(slot) {
        if (slot >= 0 && slot < deviceController.devices.length)
            return deviceController.devices[slot].id || deviceController.devices[slot].device_id || ""
        return ""
    }
    function slotChannelId(slot) { return slotDeviceId(slot) }
    function activeDeviceId() { return slotDeviceId(activeSlot) }

    // 过滤后的通道列表 (搜索框)
    function filteredDevices() {
        var devs = deviceController.devices || []
        if (chSearch === "") return devs
        var out = []
        for (var i = 0; i < devs.length; i++) {
            var nm = String(devs[i].name || devs[i].device_name || "")
            if (nm.indexOf(chSearch) >= 0) out.push(devs[i])
        }
        return out
    }

    function syncDeviceOnlineStatus() {
        for (var i = 0; i < deviceController.devices.length; i++) {
            var dev = deviceController.devices[i]
            var devId = dev.id || dev.device_id || ""
            if (devId.length > 0)
                mediaController.setDeviceOnlineStatus(devId, (dev.status || "offline") === "online")
        }
    }

    function requestAllStreams() {
        syncDeviceOnlineStatus()
        var devIds = []
        var offlineSkipped = 0
        var count = Math.min(mediaController.currentLayout, deviceController.devices.length)
        for (var i = 0; i < count; i++) {
            var dev = deviceController.devices[i]
            if ((dev.status || "offline") !== "online") { offlineSkipped++; continue }
            var id = dev.id || dev.device_id || ""
            if (id.length > 0) devIds.push(id)
        }
        if (offlineSkipped > 0)
            videoGridPage.showToast(offlineSkipped + " 台设备离线，已跳过拉流", "warn")
        if (devIds.length > 0)
            mediaController.refreshAllStreamUrls(devIds)
    }

    function showToast(text, kind) {
        toastText = text
        toastKind = kind || "info"
        toastTimer.restart()
    }

    // PTZ 指令 (对齐 Web ptzStart/ptzStop: press 启动 / release 停止)
    function ptzStart(cmd) { mediaController.ptzControl(activeDeviceId(), cmd, ptzSpeedSlider.value) }
    function ptzStop(cmd)  { mediaController.ptzControl(activeDeviceId(), "stop", 0) }

    // ═══════════════ 页面布局 ═══════════════
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    RowLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 12

        // ════ 左侧: 视频卡片 (对齐 Web video-card) ════
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"; clip: true

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                // ── 视频工具栏 (对齐 Web video-toolbar) ──
                Rectangle {
                    Layout.fillWidth: true; height: 44; color: "#FFFFFF"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                        // 通道名 (对齐 toolbar-title: 摄像机图标 + 名称)
                        AppIcon { name: "camera"; size: 16; iconColor: "#409EFF" }
                        Text {
                            text: videoGridPage.activeChannelName
                            font.pixelSize: 14; font.bold: true; color: "#303133"
                            elide: Text.ElideRight; Layout.maximumWidth: 140
                        }

                        Text { text: "播放格式:"; font.pixelSize: 12; color: "#909399" }
                        ComboBox {
                            id: formatCombo
                            width: 110; height: 28
                            model: ["RTSP", "HTTP-FLV", "WS-FLV", "HLS", "WebRTC"]
                            currentIndex: 1
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                            contentItem: Text { text: formatCombo.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                            onActivated: {
                                var chains = {
                                    "RTSP":     ["rtsp", "flv", "ws-flv", "hls", "webrtc"],
                                    "HTTP-FLV": ["flv", "ws-flv", "hls", "rtsp", "webrtc"],
                                    "WS-FLV":   ["ws-flv", "flv", "rtsp", "hls", "webrtc"],
                                    "HLS":      ["hls", "ws-flv", "flv", "rtsp", "webrtc"],
                                    "WebRTC":   ["webrtc", "ws-flv", "flv", "hls", "rtsp"]
                                }
                                videoGridPage.protocolChain = chains[currentText] || videoGridPage._defaultProtocolChain
                                videoGridPage.showToast("播放格式已切换: " + currentText, "info")
                                if (videoGridPage.isPreviewActive) videoGridPage.requestAllStreams()
                            }
                        }

                        Text { text: "分屏:"; font.pixelSize: 12; color: "#909399" }
                        ComboBox {
                            id: layoutCombo
                            width: 90; height: 28
                            model: ["1 分屏", "4 分屏", "9 分屏", "16 分屏"]
                            currentIndex: mediaController.currentLayout <= 1 ? 0 : mediaController.currentLayout <= 4 ? 1 : mediaController.currentLayout <= 9 ? 2 : 3
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                            contentItem: Text { text: layoutCombo.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                            onActivated: {
                                mediaController.currentLayout = [1, 4, 9, 16][currentIndex]
                                if (videoGridPage.isPreviewActive) videoGridPage.requestAllStreams()
                            }
                        }

                        // 截图 (对齐 Web 截图按钮)
                        LightBtn {
                            text: "截图"; enabled: videoGridPage.activeSlot >= 0
                            onClicked: {
                                mediaController.snapshotToFile(videoGridPage.slotChannelId(videoGridPage.activeSlot))
                            }
                        }
                        // 录像
                        LightBtn {
                            text: mediaController.isRecording ? "停止录像" : "录像"
                            enabled: videoGridPage.activeSlot >= 0
                            danger: mediaController.isRecording
                            onClicked: {
                                if (mediaController.isRecording) {
                                    mediaController.stopRecording(videoGridPage.slotChannelId(videoGridPage.activeSlot))
                                    videoGridPage.showToast("录像已停止", "info")
                                } else {
                                    mediaController.startRecording(videoGridPage.slotChannelId(videoGridPage.activeSlot))
                                    videoGridPage.showToast("录像已开始", "ok")
                                }
                            }
                        }
                        // 主/子码流 (内置端仅支持主码流, 切换如实提示)
                        ComboBox {
                            id: qualityCombo
                            width: 90; height: 28
                            model: ["主码流", "子码流"]
                            currentIndex: 0
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                            contentItem: Text { text: qualityCombo.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                            onActivated: {
                                if (currentIndex === 1) {
                                    showToast("本设备暂不支持子码流", "warn")
                                    currentIndex = 0
                                }
                            }
                        }
                        // 图像调节
                        LightBtn {
                            text: "图像"; enabled: videoGridPage.activeSlot >= 0
                            onClicked: imageDialog.open()
                        }

                        Item { Layout.fillWidth: true }

                        // 自动轮巡 (对齐 Web patrol 按钮)
                        LightBtn {
                            text: videoGridPage.autoPatrol ? "停止轮巡" : "自动轮巡"
                            success: videoGridPage.autoPatrol
                            enabled: videoGridPage.hasOnlineDevice
                            onClicked: {
                                videoGridPage.autoPatrol = !videoGridPage.autoPatrol
                                if (videoGridPage.autoPatrol) {
                                    videoGridPage.activeSlot = 0
                                    mediaController.currentLayout = 1
                                    layoutCombo.currentIndex = 0
                                    showToast("自动轮巡已开启 · 间隔 " + videoGridPage.autoPatrolInterval + "s", "ok")
                                } else {
                                    showToast("自动轮巡已停止", "info")
                                }
                            }
                        }
                        // 全屏
                        LightBtn {
                            text: "全屏"
                            onClicked: {
                                isFullscreen = !isFullscreen
                                if (isFullscreen && activeSlot >= 0) mediaController.currentLayout = 1
                                else mediaController.currentLayout = 4
                            }
                        }
                    }
                }

                // ── 视频网格 (对齐 Web video-grid) ──
                // [FIX 2026-08-22] 用 GridLayout 替代 Grid (后者不响应 Layout.fillHeight)
                GridLayout {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    columns: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
                    rowSpacing: 2
                    columnSpacing: 2
                    property int cols: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
                    property int rows: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4

                    Repeater {
                        model: mediaController.currentLayout

                        VideoTile {
                            Layout.preferredWidth: (grid.width - (grid.cols - 1) * 2) / grid.cols
                            Layout.preferredHeight: (grid.height - (grid.rows - 1) * 2) / grid.rows
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            deviceId: index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                            channelName: index < deviceController.devices.length ? (deviceController.devices[index].name || deviceController.devices[index].device_name || ("Camera_" + (index + 1))) : ("Camera_" + (index + 1))
                            status: index < deviceController.devices.length ? (deviceController.devices[index].status || "offline") : "offline"
                            algorithmTag: index < deviceController.devices.length ? (deviceController.devices[index].algorithm || "") : ""
                            streamUrl: isPreviewActive ? (mediaController.streamUrls[
                                index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                            ] || "") : ""
                            active: videoGridPage.activeSlot === index
                            imgBrightness: videoGridPage.imgBrightness
                            imgContrast: videoGridPage.imgContrast
                            imgSaturation: videoGridPage.imgSaturation
                            mirrorH: videoGridPage.mirrorH
                            mirrorV: videoGridPage.mirrorV
                            detectionBoxes: {
                                var devId = index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                                return mediaController.detections[devId] || []
                            }

                            // 双击全屏 + 滚轮 eZoom + 3D 定位点击
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
                                        layoutCombo.currentIndex = 0
                                        videoGridPage.isFullscreen = true
                                    }
                                }
                                onClicked: {
                                    videoGridPage.activeSlot = index
                                    if (videoGridPage.ptz3DMode && parent.active) {
                                        var dx = (mouseX / parent.width - 0.5) * 2.0
                                        var dy = (mouseY / parent.height - 0.5) * 2.0
                                        if (Math.abs(dx) < 0.15 && Math.abs(dy) < 0.15) {
                                            videoGridPage.showToast("3D定位: 目标已在中心", "info")
                                        } else {
                                            var speed = Math.min(Math.sqrt(dx * dx + dy * dy), 1.0)
                                            var dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up")
                                            mediaController.ptzControl(videoGridPage.slotDeviceId(index), dir, speed)
                                            videoGridPage.showToast("3D定位: " + dir, "ok")
                                        }
                                        mouse.accepted = true
                                    } else {
                                        mouse.accepted = false
                                    }
                                }
                                onWheel: function(wheel) {
                                    if (wheel.angleDelta.y > 0)
                                        parent.eZoomLevel = Math.min(parent.eZoomLevel + 0.25, 4.0)
                                    else {
                                        parent.eZoomLevel = Math.max(parent.eZoomLevel - 0.25, 1.0)
                                        if (parent.eZoomLevel <= 1.0) { parent.eZoomOffsetX = 0.5; parent.eZoomOffsetY = 0.5 }
                                    }
                                }
                                onPressed: {
                                    _panStartX = mouseX; _panStartY = mouseY
                                    _panStartOffX = parent.eZoomOffsetX; _panStartOffY = parent.eZoomOffsetY
                                    mouse.accepted = parent.eZoomLevel > 1.0
                                }
                                onPositionChanged: {
                                    if (parent.eZoomLevel > 1.0 && pressed) {
                                        var ddx = (mouseX - _panStartX) / parent.width / parent.eZoomLevel
                                        var ddy = (mouseY - _panStartY) / parent.height / parent.eZoomLevel
                                        parent.eZoomOffsetX = Math.max(0, Math.min(1, _panStartOffX - ddx))
                                        parent.eZoomOffsetY = Math.max(0, Math.min(1, _panStartOffY - ddy))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════ 右侧: 通道列表 + PTZ (对齐 Web live-side-column) ════
        ColumnLayout {
            Layout.preferredWidth: 280; Layout.fillHeight: true; spacing: 12

            // ── 通道列表卡片 ──
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"; clip: true

                ColumnLayout {
                    anchors.fill: parent; spacing: 0

                    // 头部: 通道列表 + 搜索 (对齐 Web channel-card header)
                    Rectangle {
                        Layout.fillWidth: true; height: 44; color: "#FFFFFF"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { text: "通道列表"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                            Item { Layout.fillWidth: true }
                            TextField {
                                id: chSearchField
                                width: 130; height: 26
                                placeholderText: "搜索..."; placeholderTextColor: "#C0C4CC"
                                color: "#606266"; font.pixelSize: 12
                                background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                                onTextChanged: videoGridPage.chSearch = text
                            }
                        }
                    }

                    // 通道项列表
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 0
                        model: videoGridPage.filteredDevices()

                        delegate: Rectangle {
                            width: ListView.view.width; height: 56
                            color: chMouse.containsMouse ? "#F5F7FA" : "#FFFFFF"
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                                // 摄像机图标 (状态着色, 对齐 Web ch-icon)
                                Rectangle {
                                    width: 30; height: 30; radius: 4
                                    color: (modelData.status || "offline") === "online" ? "#F0F9EB" : "#F4F4F5"
                                    AppIcon { anchors.centerIn: parent; name: "camera"; size: 16
                                        iconColor: (modelData.status || "offline") === "online" ? "#67C23A" : "#909399" }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: modelData.name || modelData.device_name || ("CH" + (index + 1))
                                        font.pixelSize: 13; color: "#303133"; elide: Text.ElideRight
                                    }
                                    Text {
                                        text: (modelData.algorithm || modelData.algoPlugin || "无算法")
                                              + " · " + (modelData.fps !== undefined ? modelData.fps : 0) + "fps"
                                        font.pixelSize: 12; color: "#909399"; elide: Text.ElideRight
                                    }
                                }
                                // 状态标签 (对齐 Web el-tag: 推流绿/在线蓝/离线灰)
                                Rectangle {
                                    width: stTagText.implicitWidth + 14; height: 20; radius: 3
                                    color: (modelData.status || "offline") === "online" ? "#ECF5FF" : "#F4F4F5"
                                    border.color: (modelData.status || "offline") === "online" ? "#D9ECFF" : "#E9E9EB"
                                    Text {
                                        id: stTagText
                                        anchors.centerIn: parent
                                        text: (modelData.status || "offline") === "online" ? "在线" : "离线"
                                        font.pixelSize: 12
                                        color: (modelData.status || "offline") === "online" ? "#409EFF" : "#909399"
                                    }
                                }
                            }

                            MouseArea {
                                id: chMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    // 点击通道 → 选中并拉流 (内置端无拖拽, 点击分配到当前选中格)
                                    videoGridPage.activeSlot = index
                                    var devId = modelData.id || modelData.device_id || ""
                                    if ((modelData.status || "offline") !== "online") {
                                        videoGridPage.showToast("设备离线，无法预览", "warn")
                                        return
                                    }
                                    videoGridPage.isPreviewActive = true
                                    videoGridPage.syncDeviceOnlineStatus()
                                    mediaController.startStreamWithProtocols(devId, devId, videoGridPage.protocolChain)
                                }
                            }
                        }

                        // 空态 (对齐 Web el-empty "暂无通道")
                        Text {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: "暂无通道"; font.pixelSize: 13; color: "#909399"
                        }
                    }
                }
            }

            // ── PTZ 云台卡片 (对齐 Web ptz-card; 选中通道时显示) ──
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 396
                visible: videoGridPage.activeSlot >= 0
                color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5"; clip: true

                Flickable {
                    anchors.fill: parent
                    contentWidth: width; contentHeight: ptzCol.height + 20
                    clip: true; boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: ptzCol
                        width: parent.width - 24; x: 12; y: 10; spacing: 8

                        // 标题 (对齐 ptz-card-title: 定位图标 + PTZ 云台 + 通道名)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            AppIcon { name: "locate"; size: 14; iconColor: "#409EFF" }
                            Text { text: "PTZ 云台"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                            Text {
                                text: "— " + videoGridPage.activeChannelName
                                font.pixelSize: 12; color: "#909399"; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // 方向盘 (3x3: up / left,home,right / down)
                        Grid {
                            Layout.alignment: Qt.AlignHCenter
                            columns: 3; spacing: 4
                            Item { width: 36; height: 32 }
                            PtzDirBtn { text: "▲"; cmd: "up" }
                            Item { width: 36; height: 32 }
                            PtzDirBtn { text: "◀"; cmd: "left" }
                            Button {
                                width: 36; height: 32
                                background: Rectangle { color: "#409EFF"; radius: 16 }
                                contentItem: Text { text: "●"; color: "#FFFFFF"; font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "home", 0.5)
                            }
                            PtzDirBtn { text: "▶"; cmd: "right" }
                            Item { width: 36; height: 32 }
                            PtzDirBtn { text: "▼"; cmd: "down" }
                            Item { width: 36; height: 32 }
                        }

                        // 变倍 (对齐 Web ptz-zoom-row)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            PtzHoldBtn { text: "变倍 +"; cmd: "zoom_in" }
                            PtzHoldBtn { text: "变倍 -"; cmd: "zoom_out" }
                        }
                        // 聚焦 / 光圈
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            PtzHoldBtn { text: "聚焦 +"; cmd: "focus_near" }
                            PtzHoldBtn { text: "聚焦 -"; cmd: "focus_far" }
                            PtzHoldBtn { text: "光圈 +"; cmd: "iris_open" }
                            PtzHoldBtn { text: "光圈 -"; cmd: "iris_close" }
                        }
                        // 辅助开关 (雨刷/灯光/加热)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            LightBtn { text: "雨刷"; Layout.fillWidth: true
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "wiper", 0.5) }
                            LightBtn { text: "灯光"; Layout.fillWidth: true
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "light", 0.5) }
                            LightBtn { text: "加热"; Layout.fillWidth: true
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "heater", 0.5) }
                        }

                        // 速度滑块 (对齐 Web ptz-speed 1~255 → 归一化 0.1~1.0)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "速度"; font.pixelSize: 12; color: "#606266" }
                            Slider {
                                id: ptzSpeedSlider
                                Layout.fillWidth: true
                                from: 0.1; to: 1.0; value: 0.6; stepSize: 0.05
                                background: Rectangle {
                                    x: ptzSpeedSlider.leftPadding; y: ptzSpeedSlider.topPadding + ptzSpeedSlider.availableHeight / 2 - 2
                                    width: ptzSpeedSlider.availableWidth; height: 4; radius: 2; color: "#E4E7ED"
                                    Rectangle { width: ptzSpeedSlider.visualPosition * parent.width; height: 4; radius: 2; color: "#409EFF" }
                                }
                                handle: Rectangle {
                                    x: ptzSpeedSlider.leftPadding + ptzSpeedSlider.visualPosition * (ptzSpeedSlider.availableWidth - 12)
                                    y: ptzSpeedSlider.topPadding + ptzSpeedSlider.availableHeight / 2 - 6
                                    width: 12; height: 12; radius: 6; color: "#FFFFFF"; border.color: "#409EFF"
                                }
                            }
                        }

                        // 预置位 P1-P4 (点击调用, 长按设置)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "预置位"; font.pixelSize: 12; color: "#606266" }
                            Repeater {
                                model: 4
                                delegate: Button {
                                    Layout.fillWidth: true; height: 26
                                    background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                                    contentItem: Text { text: "P" + (index + 1); font.pixelSize: 12; color: "#606266"
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: mediaController.ptzGotoPreset(videoGridPage.activeDeviceId(), index + 1)
                                    onPressAndHold: {
                                        mediaController.ptzSetPreset(videoGridPage.activeDeviceId(), index + 1)
                                        videoGridPage.showToast("预置位 P" + (index + 1) + " 已保存", "ok")
                                    }
                                }
                            }
                        }

                        // 巡航 (启动/停止 + C1/C2 路径)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "巡航"; font.pixelSize: 12; color: "#606266" }
                            Button {
                                Layout.fillWidth: true; height: 26
                                background: Rectangle {
                                    radius: 3
                                    color: videoGridPage.isCruising ? "#FDF6EC" : "#FFFFFF"
                                    border.color: videoGridPage.isCruising ? "#FAECD8" : "#DCDFE6"
                                }
                                contentItem: Text { text: videoGridPage.isCruising ? "停止巡航" : "启动巡航"; font.pixelSize: 12
                                    color: videoGridPage.isCruising ? "#E6A23C" : "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    videoGridPage.isCruising = !videoGridPage.isCruising
                                    if (videoGridPage.isCruising) mediaController.startPatrol(videoGridPage.activeDeviceId())
                                    else mediaController.stopPatrol(videoGridPage.activeDeviceId())
                                }
                            }
                            Button {
                                width: 40; height: 26
                                background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                                contentItem: Text { text: "C1"; font.pixelSize: 12; color: "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "cruise_start", 1)
                            }
                            Button {
                                width: 40; height: 26
                                background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                                contentItem: Text { text: "C2"; font.pixelSize: 12; color: "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "cruise_start", 2)
                            }
                        }

                        // 轨迹 (启动/停止 + T1/T2)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "轨迹"; font.pixelSize: 12; color: "#606266" }
                            Button {
                                Layout.fillWidth: true; height: 26
                                background: Rectangle {
                                    radius: 3
                                    color: videoGridPage.isTracking ? "#FDF6EC" : "#FFFFFF"
                                    border.color: videoGridPage.isTracking ? "#FAECD8" : "#DCDFE6"
                                }
                                contentItem: Text { text: videoGridPage.isTracking ? "停止跟踪" : "启动跟踪"; font.pixelSize: 12
                                    color: videoGridPage.isTracking ? "#E6A23C" : "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    videoGridPage.isTracking = !videoGridPage.isTracking
                                    mediaController.ptzControl(videoGridPage.activeDeviceId(),
                                        videoGridPage.isTracking ? "track_start" : "track_stop", 1)
                                }
                            }
                            Button {
                                width: 40; height: 26
                                background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                                contentItem: Text { text: "T1"; font.pixelSize: 12; color: "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "track_start", 1)
                            }
                            Button {
                                width: 40; height: 26
                                background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                                contentItem: Text { text: "T2"; font.pixelSize: 12; color: "#606266"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.ptzControl(videoGridPage.activeDeviceId(), "track_start", 2)
                            }
                        }

                        // 3D 定位提示 (对齐 Web ptz-3d-hint)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: "◎"; font.pixelSize: 11; color: "#909399" }
                            Text { text: "双击画面可 3D 放大定位"; font.pixelSize: 12; color: "#909399" }
                        }
                    }
                }
            }
        }
    }

    // ═══ 内联组件: 浅色按钮 (Element default/success/danger plain) ═══
    component LightBtn: Button {
        property bool success: false
        property bool danger: false
        height: 28
        background: Rectangle {
            radius: 4
            color: success ? "#F0F9EB" : danger ? "#FEF0F0" : "#FFFFFF"
            border.color: success ? "#E1F3D8" : danger ? "#FDE2E2" : "#DCDFE6"
            opacity: parent.enabled ? 1.0 : 0.55
        }
        contentItem: Text {
            text: parent.text; font.pixelSize: 12
            color: success ? "#67C23A" : danger ? "#F56C6C" : "#606266"
            leftPadding: 10; rightPadding: 10
            opacity: parent.enabled ? 1.0 : 0.55
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }

    // PTZ 方向键 (按住移动, 松开停止)
    component PtzDirBtn: Button {
        property string cmd: ""
        width: 36; height: 32
        background: Rectangle { color: "#FFFFFF"; radius: 16; border.color: "#DCDFE6" }
        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        onPressed: videoGridPage.ptzStart(cmd)
        onReleased: videoGridPage.ptzStop(cmd)
    }

    // PTZ 变倍/聚焦/光圈长按键
    component PtzHoldBtn: Button {
        property string cmd: ""
        Layout.fillWidth: true; height: 26
        background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        onPressed: videoGridPage.ptzStart(cmd)
        onReleased: videoGridPage.ptzStop(cmd)
    }

    // ═══ 图像调节弹窗 (对齐 Web imageDialog) ═══
    Dialog {
        id: imageDialog
        title: "图像调节"
        modal: true; width: 400
        anchors.centerIn: parent
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.color: "#EBEEF5" }
        header: Text { text: "图像调节"; font.pixelSize: 15; font.bold: true; color: "#303133"; padding: 14 }

        ColumnLayout {
            width: parent.width; spacing: 10
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "亮度"; width: 50; font.pixelSize: 13; color: "#606266" }
                Slider { Layout.fillWidth: true; from: -0.5; to: 0.5; stepSize: 0.05
                    value: videoGridPage.imgBrightness
                    onMoved: videoGridPage.imgBrightness = value }
                Text { text: Math.round(videoGridPage.imgBrightness * 100); width: 34; font.pixelSize: 12; color: "#909399" }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "对比度"; width: 50; font.pixelSize: 13; color: "#606266" }
                Slider { Layout.fillWidth: true; from: 0.0; to: 2.0; stepSize: 0.05
                    value: videoGridPage.imgContrast
                    onMoved: videoGridPage.imgContrast = value }
                Text { text: Math.round(videoGridPage.imgContrast * 100) + "%"; width: 34; font.pixelSize: 12; color: "#909399" }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "饱和度"; width: 50; font.pixelSize: 13; color: "#606266" }
                Slider { Layout.fillWidth: true; from: 0.0; to: 2.0; stepSize: 0.05
                    value: videoGridPage.imgSaturation
                    onMoved: videoGridPage.imgSaturation = value }
                Text { text: Math.round(videoGridPage.imgSaturation * 100) + "%"; width: 34; font.pixelSize: 12; color: "#909399" }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { width: 50 }
                LightBtn {
                    text: videoGridPage.mirrorH ? "● 水平镜像" : "水平镜像"
                    success: videoGridPage.mirrorH
                    onClicked: videoGridPage.mirrorH = !videoGridPage.mirrorH
                }
                LightBtn {
                    text: videoGridPage.mirrorV ? "● 垂直翻转" : "垂直翻转"
                    success: videoGridPage.mirrorV
                    onClicked: videoGridPage.mirrorV = !videoGridPage.mirrorV
                }
                LightBtn {
                    text: "重置"
                    onClicked: {
                        videoGridPage.imgBrightness = 0.0
                        videoGridPage.imgContrast = 1.0
                        videoGridPage.imgSaturation = 1.0
                        videoGridPage.mirrorH = false
                        videoGridPage.mirrorV = false
                    }
                }
            }
        }
    }

    // ═══ Toast 提示 (浅色风格) ═══
    Rectangle {
        id: toastPopup
        visible: toastText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        height: 36; width: toastTextElided.implicitWidth + 36
        radius: 4; z: 60
        color: { switch (toastKind) {
            case "ok": return "#F0F9EB"; case "warn": return "#FDF6EC"
            case "error": return "#FEF0F0"; default: return "#ECF5FF" } }
        border.color: { switch (toastKind) {
            case "ok": return "#E1F3D8"; case "warn": return "#FAECD8"
            case "error": return "#FDE2E2"; default: return "#D9ECFF" } }
        border.width: 1
        Text {
            id: toastTextElided
            anchors.centerIn: parent
            text: toastText; font.pixelSize: 13
            color: { switch (toastKind) {
                case "ok": return "#67C23A"; case "warn": return "#E6A23C"
                case "error": return "#F56C6C"; default: return "#409EFF" } }
        }
        Timer { id: toastTimer; interval: 3500; onTriggered: videoGridPage.toastText = "" }
    }

    // ═══ 控制器事件 ═══
    Connections {
        target: mediaController
        function onLayoutChanged() {
            layoutCombo.currentIndex = mediaController.currentLayout <= 1 ? 0 : mediaController.currentLayout <= 4 ? 1 : mediaController.currentLayout <= 9 ? 2 : 3
            if (isPreviewActive) requestAllStreams()
        }
        function onSnapshotSaved(channelId, filePath) {
            videoGridPage.showToast("截图已保存: " + filePath, "ok")
        }
        function onSnapshotFailed(channelId, code, message) {
            videoGridPage.showToast("截图失败 [" + code + "]: " + message, "error")
        }
    }

    Connections {
        target: mediaController.degradation
        function onProtocolFailed(deviceId, failed, next) {
            if (next && next.length > 0)
                videoGridPage.showToast("协议 " + failed + " 失败,已切换到 " + next, "warn")
            else
                videoGridPage.showToast("协议 " + failed + " 失败,降级链已耗尽", "error")
        }
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() {
            if (!videoGridPage.isPreviewActive && deviceController.devices.length > 0) {
                // 首次设备就绪 → 自动开始预览 (对齐 Web 进页即拉流)
                videoGridPage.isPreviewActive = true
                videoGridPage.requestAllStreams()
            } else if (videoGridPage.isPreviewActive) {
                videoGridPage.requestAllStreams()
            }
        }
    }

    // [V4-V4] 自动轮巡 Timer
    Timer {
        id: autoPatrolTimer
        interval: videoGridPage.autoPatrolInterval * 1000
        repeat: true
        running: videoGridPage.autoPatrol && videoGridPage.isPreviewActive
        onTriggered: {
            var devCount = deviceController.devices.length
            if (devCount <= 1) return
            var nextSlot = videoGridPage.activeSlot
            for (var i = 0; i < devCount; i++) {
                nextSlot = (nextSlot + 1) % devCount
                if ((deviceController.devices[nextSlot].status || "offline") === "online") {
                    videoGridPage.activeSlot = nextSlot
                    return
                }
            }
        }
    }

    Component.onCompleted: deviceController.refreshDevices()
}
