// ========================================================================
// ChannelView.qml — 通道管理 (设备-通道树 + 码流配置 + 通道映射 + 多画面轮巡 + 批量配置)
// 接入 deviceController + mediaController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: channelView

    // ── 内部状态 ──
    property string searchText: ""
    property var channelTree: []
    property var selectedChannel: null
    property var patrolPlans: []
    property bool showBatchDialog: false
    property bool showAlgoDialog: false
    property bool showPatrolDialog: false
    property string editingPatrolName: ""

    // 配置表单
    property string cfgName: ""
    property string cfgStreamType: "主码流"
    property string cfgCodec: "H.265"
    property string cfgResolution: "3840x2160"
    property int cfgFps: 25
    property int cfgBitrate: 6144
    property bool cfgEnabled: true

    // 算法表单
    property string algoPlugin: "无"
    property int algoSensitivity: 5
    property int algoInterval: 5

    // 批量配置
    property string batchCodec: "H.265"
    property string batchResolution: "1920x1080"
    property int batchFps: 25
    property int batchBitrate: 4096

    // ── 生命周期 ──
    Component.onCompleted: {
        deviceController.refreshDevices()
        mediaController.refreshStreams()
    }

    // ── 监听 Controller 信号 ──
    Connections {
        target: deviceController
        function onDevicesUpdated() { buildChannelTree() }
    }

    Connections {
        target: mediaController
        function onChannelsUpdated() { buildChannelTree() }
        function onStreamStarted(deviceId, url) {
            statusText.text = "✅ 流已启动: " + url
            statusText.color = "#00D4AA"
            statusTimer.start()
        }
        function onStreamStopped(sessionId) {
            statusText.text = "⏹ 流已停止: " + sessionId
            statusText.color = "#FFB800"
            statusTimer.start()
        }
        function onErrorOccurred(code, message) {
            statusText.text = "❌ 错误: " + message
            statusText.color = "#FF3D71"
            statusTimer.start()
        }
    }

    Timer { id: statusTimer; interval: 4000; onTriggered: statusText.text = "" }

    // ── 构建设备-通道树 ──
    function buildChannelTree() {
        var devices = deviceController.devices
        var channels = mediaController.channels
        var tree = []
        for (var i = 0; i < devices.length; i++) {
            var dev = devices[i]
            var devNode = {
                name: dev.name || dev.deviceName || "未知设备",
                deviceId: dev.deviceId || dev.id || "",
                ip: dev.ip || dev.ipAddress || "",
                status: dev.status || "offline",
                isDevice: true, indent: 0, channels: []
            }
            var chCount = dev.channelCount || 0
            for (var j = 0; j < chCount; j++) {
                var chData = null
                for (var k = 0; k < channels.length; k++) {
                    if (channels[k].deviceId === devNode.deviceId && channels[k].channelNo === (j + 1)) {
                        chData = channels[k]; break
                    }
                }
                devNode.channels.push({
                    name: chData ? chData.name : ("CH" + (j + 1)),
                    channelNo: j + 1,
                    deviceId: devNode.deviceId,
                    isDevice: false, indent: 1,
                    online: dev.status === "online",
                    streamType: chData ? (chData.streamType || "主码流") : "主码流",
                    codec: chData ? (chData.codec || "H.265") : "H.265",
                    resolution: chData ? (chData.resolution || "3840x2160") : "3840x2160",
                    fps: chData ? (chData.fps || 25) : 25,
                    bitrate: chData ? (chData.bitrate || 6144) : 6144,
                    enabled: chData ? (chData.enabled !== false) : true,
                    status: chData ? (chData.status || "idle") : "idle",
                    algoPlugin: chData ? (chData.algoPlugin || "无") : "无"
                })
            }
            tree.push(devNode)
        }
        channelTree = tree
    }

    function buildFlatTree() {
        var result = []
        for (var i = 0; i < channelTree.length; i++) {
            var dev = channelTree[i]
            if (searchText) {
                var match = dev.name.toLowerCase().indexOf(searchText.toLowerCase()) >= 0
                var chMatch = false
                for (var j = 0; j < dev.channels.length; j++) {
                    if (dev.channels[j].name.toLowerCase().indexOf(searchText.toLowerCase()) >= 0) chMatch = true
                }
                if (!match && !chMatch) continue
            }
            result.push(dev)
            for (var j = 0; j < dev.channels.length; j++) {
                if (searchText && dev.channels[j].name.toLowerCase().indexOf(searchText.toLowerCase()) < 0) continue
                result.push(dev.channels[j])
            }
        }
        return result
    }

    function loadChannelConfig(ch) {
        cfgName = ch.name || ""
        cfgStreamType = ch.streamType || "主码流"
        cfgCodec = ch.codec || "H.265"
        cfgResolution = ch.resolution || "3840x2160"
        cfgFps = ch.fps || 25
        cfgBitrate = ch.bitrate || 6144
        cfgEnabled = ch.enabled !== false
    }

    function saveChannelConfig() {
        if (!selectedChannel) return
        var chId = selectedChannel.deviceId + "_" + selectedChannel.channelNo
        configController.saveConfig("channel_" + chId, {
            name: cfgName, streamType: cfgStreamType, codec: cfgCodec,
            resolution: cfgResolution, fps: cfgFps, bitrate: cfgBitrate, enabled: cfgEnabled
        })
        statusText.text = "✅ 通道配置已保存"
        statusText.color = "#00D4AA"
        statusTimer.start()
    }

    function togglePatrol(idx) {
        var plans = patrolPlans.slice()
        plans[idx].active = !plans[idx].active
        patrolPlans = plans
    }

    function removePatrol(idx) {
        var plans = patrolPlans.slice()
        plans.splice(idx, 1)
        patrolPlans = plans
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
            Text { text: "📡 通道管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            TextField {
                width: 180; height: 32
                placeholderText: "搜索通道..."; placeholderTextColor: "#4A4D58"
                color: "#E8E8E8"; font.pixelSize: 12
                onTextChanged: searchText = text
                background: Rectangle { color: "#252830"; radius: 6 }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "➕ 新建轮巡"; font.pixelSize: 12
                onClicked: { showPatrolDialog = true; editingPatrolName = "" }
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "⚙️ 批量配置"; font.pixelSize: 12
                onClicked: showBatchDialog = true
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "🔄 刷新"; font.pixelSize: 12
                onClicked: { deviceController.refreshDevices(); mediaController.refreshStreams() }
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 设备-通道树 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "设备通道树"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    id: treeView
                    width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 1
                    model: buildFlatTree()

                    delegate: Rectangle {
                        width: ListView.view.width; height: 30
                        color: chMouse.containsMouse ? "#1A1D23" : "transparent"
                        radius: 3

                        Row {
                            x: (modelData.indent || 0) * 20 + 4; spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.isDevice ? "📹" : "•"
                                font.pixelSize: modelData.isDevice ? 12 : 8
                                color: modelData.online !== false ? "#00D4AA" : "#FF3D71"
                            }
                            Text {
                                text: modelData.name
                                font.pixelSize: modelData.isDevice ? 12 : 11
                                color: modelData.online !== false ? "#E8E8E8" : "#4A4D58"
                                font.bold: modelData.isDevice
                                elide: Text.ElideRight
                                width: treeView.width - (modelData.indent || 0) * 20 - 40
                            }
                            Rectangle {
                                visible: !modelData.isDevice
                                width: 24; height: 14; radius: 3
                                color: modelData.status === "streaming" ? "#0A2A1A" :
                                       modelData.status === "error" ? "#2A1A1A" : "#1A1D23"
                                Text {
                                    text: modelData.status === "streaming" ? "推" :
                                          modelData.status === "error" ? "误" : "闲"
                                    font.pixelSize: 8; color: "#8B8FA3"; anchors.centerIn: parent
                                }
                            }
                        }
                        MouseArea {
                            id: chMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (!modelData.isDevice) {
                                    selectedChannel = modelData
                                    loadChannelConfig(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 右侧: 通道配置 + 轮巡 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Row {
                    spacing: 8; width: parent.width
                    Text { text: "通道配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Rectangle {
                        visible: selectedChannel !== null
                        width: 60; height: 18; radius: 4; color: "#1A2A3A"
                        Text { text: selectedChannel ? selectedChannel.name : ""; font.pixelSize: 10; color: "#3B82F6"; anchors.centerIn: parent }
                    }
                }

                // 通道配置表单
                Rectangle {
                    width: parent.width - 24; height: 240; color: "#141720"; radius: 8
                    visible: selectedChannel !== null

                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8

                        Grid {
                            columns: 4; spacing: 12; rowSpacing: 10; width: parent.width
                            Text { text: "通道名称:"; font.pixelSize: 12; color: "#8B8FA3" }
                            TextField {
                                text: cfgName; onTextChanged: cfgName = text
                                width: 200; font.pixelSize: 12; color: "#E8E8E8"
                                background: Rectangle { color: "#252830"; radius: 4 }
                            }
                            Text { text: "启用:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Switch { checked: cfgEnabled; onCheckedChanged: cfgEnabled = checked }

                            Text { text: "码流类型:"; font.pixelSize: 12; color: "#8B8FA3" }
                            ComboBox {
                                width: 160; model: ["主码流", "子码流", "三码流"]
                                currentIndex: model.indexOf(cfgStreamType)
                                onActivated: cfgStreamType = model[currentIndex]
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                            }
                            Text { text: "编码格式:"; font.pixelSize: 12; color: "#8B8FA3" }
                            ComboBox {
                                width: 160; model: ["H.265", "H.264", "MJPEG"]
                                currentIndex: model.indexOf(cfgCodec)
                                onActivated: cfgCodec = model[currentIndex]
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                            }
                            Text { text: "分辨率:"; font.pixelSize: 12; color: "#8B8FA3" }
                            ComboBox {
                                width: 160; model: ["3840x2160", "2560x1440", "1920x1080", "1280x720", "704x576"]
                                currentIndex: model.indexOf(cfgResolution)
                                onActivated: cfgResolution = model[currentIndex]
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                            }
                            Text { text: "帧率:"; font.pixelSize: 12; color: "#8B8FA3" }
                            SpinBox { from: 1; to: 30; value: cfgFps; onValueChanged: cfgFps = value }
                            Text { text: "码率(Kbps):"; font.pixelSize: 12; color: "#8B8FA3" }
                            SpinBox { from: 256; to: 16384; value: cfgBitrate; stepSize: 512; onValueChanged: cfgBitrate = value }
                        }

                        Row {
                            spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                                text: "💾 保存配置"; font.pixelSize: 11
                                onClicked: saveChannelConfig()
                                background: Rectangle { color: "#3B82F6"; radius: 6; width: 90; height: 30 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "▶ 开始推流"; font.pixelSize: 11
                                onClicked: { if (selectedChannel) mediaController.startStream(selectedChannel.deviceId, selectedChannel.channelNo) }
                                background: Rectangle { color: "#00D4AA"; radius: 6; width: 90; height: 30 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "📷 截图"; font.pixelSize: 11
                                onClicked: { if (selectedChannel) mediaController.snapshot(selectedChannel.channelNo) }
                                background: Rectangle { color: "#252830"; radius: 6; width: 70; height: 30 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "🧠 算法"; font.pixelSize: 11
                                onClicked: { if (selectedChannel) { algoPlugin = selectedChannel.algoPlugin || "无"; showAlgoDialog = true } }
                                background: Rectangle { color: "#8B5CF6"; radius: 6; width: 70; height: 30 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "⏹ 停止"; font.pixelSize: 11
                                onClicked: { if (selectedChannel) mediaController.stopStream(selectedChannel.deviceId + "_" + selectedChannel.channelNo) }
                                background: Rectangle { color: "#FF3D71"; radius: 6; width: 70; height: 30 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 24; height: 240; color: "#141720"; radius: 8
                    visible: selectedChannel === null
                    Text { text: "← 请从左侧选择一个通道"; font.pixelSize: 13; color: "#4A4D58"; anchors.centerIn: parent }
                }

                // ── 轮巡方案 ──
                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                Row {
                    spacing: 8; width: parent.width - 24
                    Text { text: "轮巡方案"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Button {
                        text: "➕ 新建"; font.pixelSize: 10
                        onClicked: { showPatrolDialog = true; editingPatrolName = "" }
                        background: Rectangle { color: "#252830"; radius: 4; width: 60; height: 22 }
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }

                ListView {
                    width: parent.width - 24; height: parent.height - 340; clip: true; spacing: 4
                    model: patrolPlans
                    delegate: Rectangle {
                        width: ListView.view.width; height: 52; color: "#141720"; radius: 6
                        Row {
                            anchors.fill: parent; anchors.margins: 8; spacing: 12
                            Rectangle { width: 6; height: 6; radius: 3; color: modelData.active ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; width: 160 }
                            Text { text: "间隔:" + modelData.interval; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: modelData.layout; font.pixelSize: 11; color: "#3B82F6" }
                            Text { text: modelData.channels + "通道"; font.pixelSize: 11; color: "#8B8FA3" }
                            Item { width: 20 }
                            Button {
                                text: modelData.active ? "⏹ 停止" : "▶ 启动"; font.pixelSize: 10
                                onClicked: togglePatrol(index)
                                background: Rectangle { color: modelData.active ? "#FF3D71" : "#00D4AA"; radius: 4; width: 52; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: modelData.active ? "#FFF" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "编辑"; font.pixelSize: 10
                                onClicked: { editingPatrolName = modelData.name; showPatrolDialog = true }
                                background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "删除"; font.pixelSize: 10
                                onClicked: removePatrol(index)
                                background: Rectangle { color: "#3A1A1A"; radius: 4; width: 36; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 批量配置弹窗
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        visible: showBatchDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showBatchDialog = false }
        Rectangle {
            width: 440; height: 360; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12

                Row { width: parent.width; spacing: 8
                    Text { text: "⚙️ 批量配置通道"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 130 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showBatchDialog = false } }
                }
                Text { text: "将以下配置应用到所有设备的全部通道"; font.pixelSize: 11; color: "#8B8FA3"; wrapMode: Text.WordWrap; width: parent.width }

                Grid {
                    columns: 2; columnSpacing: 12; rowSpacing: 8; width: parent.width
                    Text { text: "编码格式:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox {
                        width: 240; model: ["H.265", "H.264", "MJPEG"]
                        currentIndex: model.indexOf(batchCodec)
                        onActivated: batchCodec = model[currentIndex]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    }
                    Text { text: "分辨率:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox {
                        width: 240; model: ["3840x2160", "2560x1440", "1920x1080", "1280x720"]
                        currentIndex: model.indexOf(batchResolution)
                        onActivated: batchResolution = model[currentIndex]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    }
                    Text { text: "帧率:"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 1; to: 30; value: batchFps; onValueChanged: batchFps = value }
                    Text { text: "码率(Kbps):"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 256; to: 16384; value: batchBitrate; stepSize: 512; onValueChanged: batchBitrate = value }
                }

                Row {
                    spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button {
                        text: "取消"; font.pixelSize: 13; onClicked: showBatchDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "应用配置"; font.pixelSize: 13
                        onClicked: {
                            var devices = deviceController.devices
                            for (var i = 0; i < devices.length; i++) {
                                var dev = devices[i]
                                var chCount = dev.channelCount || 0
                                for (var j = 0; j < chCount; j++) {
                                    configController.saveConfig("channel_" + (dev.deviceId || dev.id) + "_" + (j+1), {
                                        codec: batchCodec, resolution: batchResolution, fps: batchFps, bitrate: batchBitrate
                                    })
                                }
                            }
                            statusText.text = "✅ 批量配置已应用"; statusText.color = "#00D4AA"; statusTimer.start()
                            showBatchDialog = false
                        }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 算法插件弹窗
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        visible: showAlgoDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showAlgoDialog = false }
        Rectangle {
            width: 400; height: 320; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12

                Row { width: parent.width; spacing: 8
                    Text { text: "🧠 算法插件设置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 130 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showAlgoDialog = false } }
                }

                Grid {
                    columns: 2; columnSpacing: 12; rowSpacing: 8; width: parent.width
                    Text { text: "算法插件:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox {
                        width: 220; model: ["无", "入侵检测", "烟火检测", "安全帽检测", "人脸检测", "徘徊检测", "车牌识别"]
                        currentIndex: model.indexOf(algoPlugin)
                        onActivated: algoPlugin = model[currentIndex]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    }
                    Text { text: "检测灵敏度:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row {
                        Slider { width: 150; from: 1; to: 10; value: algoSensitivity; stepSize: 1; onValueChanged: algoSensitivity = value }
                        Text { text: algoSensitivity; font.pixelSize: 12; color: "#E8E8E8"; width: 30; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "检测间隔(秒):"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 1; to: 60; value: algoInterval; onValueChanged: algoInterval = value }
                }

                Row {
                    spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button {
                        text: "取消"; font.pixelSize: 13; onClicked: showAlgoDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "应用插件"; font.pixelSize: 13
                        onClicked: {
                            if (selectedChannel) {
                                configController.configureAlgorithm(
                                    selectedChannel.deviceId + "_" + selectedChannel.channelNo,
                                    { plugin: algoPlugin, sensitivity: algoSensitivity, interval: algoInterval }
                                )
                            }
                            showAlgoDialog = false
                        }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 轮巡方案弹窗
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        visible: showPatrolDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showPatrolDialog = false }
        Rectangle {
            width: 400; height: 280; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12

                Row { width: parent.width; spacing: 8
                    Text { text: "📋 新建轮巡方案"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 130 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showPatrolDialog = false } }
                }

                Grid {
                    columns: 2; columnSpacing: 12; rowSpacing: 8; width: parent.width
                    Text { text: "方案名称:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField {
                        text: editingPatrolName; onTextChanged: editingPatrolName = text
                        width: 220; font.pixelSize: 12; color: "#E8E8E8"
                        placeholderText: "如: 默认轮巡"; placeholderTextColor: "#4A4D58"
                        background: Rectangle { color: "#252830"; radius: 6 }
                    }
                    Text { text: "轮巡间隔(秒):"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { id: patrolInterval; from: 1; to: 60; value: 10 }
                    Text { text: "画面布局:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox {
                        id: patrolLayout; width: 220; model: ["1宫格", "4宫格", "9宫格", "16宫格"]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    }
                }

                Row {
                    spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button {
                        text: "取消"; font.pixelSize: 13; onClicked: showPatrolDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "确认创建"; font.pixelSize: 13
                        onClicked: {
                            patrolPlans = patrolPlans.concat([{
                                name: editingPatrolName || "新轮巡",
                                interval: patrolInterval.value + "秒",
                                layout: patrolLayout.currentText,
                                channels: "0",
                                active: false
                            }])
                            showPatrolDialog = false
                        }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }
}