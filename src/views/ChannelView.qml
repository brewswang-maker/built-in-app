// ========================================================================
// ChannelView.qml — 通道管理 (码流配置 + 通道映射 + 多画面轮巡)
// 接入 deviceController + mediaController — box-sdk REST API
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: channelView

    property var selectedChannel: null
    property var selectedDevice: null
    property var channelTreeModel: []
    property var selectedChannels: []
    property bool showBatchConfig: false
    property bool showPatrolDialog: false
    property string batchCodec: "H.265"
    property string batchResolution: "1920x1080"
    property int batchFps: 25
    property int batchBitrate: 4096
    property string patrolName: ""
    property int patrolInterval: 10
    property string statusMsg: ""

    Component.onCompleted: {
        deviceController.refreshDevices()
        mediaController.refreshStreams()
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() { buildChannelTree() }
        function onErrorOccurred(code, message) { statusMsg = "Error: " + message; statusTimer.start() }
    }

    Connections {
        target: mediaController
        function onChannelsUpdated() { /* refresh channel info */ }
        function onStreamStarted(channelId) { statusMsg = "Preview started: " + channelId; statusTimer.start() }
        function onStreamStopped(channelId) { statusMsg = "Preview stopped: " + channelId; statusTimer.start() }
        function onErrorOccurred(code, message) { statusMsg = "Error: " + message; statusTimer.start() }
    }

    Timer { id: statusTimer; interval: 3000; onTriggered: statusMsg = "" }

    function buildChannelTree() {
        var devices = deviceController.devices
        var tree = []
        for (var i = 0; i < devices.length; i++) {
            var dev = devices[i]
            tree.push({ type: "device", name: dev.name || "Device", deviceId: dev.deviceId || dev.id || "", status: dev.status || "offline", protocol: dev.protocol || "-", ip: dev.ip || "-", channelCount: dev.channelCount || 0, indent: 0 })
            var channels = dev.channels || []
            for (var j = 0; j < channels.length; j++) {
                var ch = channels[j]
                tree.push({ type: "channel", name: ch.name || ("CH" + (j+1)), channelId: ch.channelId || (dev.deviceId + "_ch" + j), streamType: ch.streamType || "main", codec: ch.codec || "H.265", resolution: ch.resolution || "-", fps: ch.fps || 25, bitrate: ch.bitrate || 0, enabled: ch.enabled !== false, status: ch.status || (dev.status === "online" ? "online" : "offline"), deviceName: dev.name || "", indent: 1 })
            }
        }
        channelTreeModel = tree
    }

    function getChannelStreamInfo(channelId) {
        var streams = mediaController.streams
        for (var i = 0; i < streams.length; i++) {
            if (streams[i].channelId === channelId) return streams[i]
        }
        return null
    }

    function toggleChannelSelect(channelId) {
        var idx = selectedChannels.indexOf(channelId)
        var copy = selectedChannels.slice()
        if (idx >= 0) copy.splice(idx, 1); else copy.push(channelId)
        selectedChannels = copy
    }

    // ═══ Toolbar ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "Channel Mgmt"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: deviceController.deviceCount + " devices"; font.pixelSize: 12; color: "#8B8FA3" }
            Item { Layout.fillWidth: true }
            Text { text: statusMsg; font.pixelSize: 12; color: "#FFB800"; visible: statusMsg !== "" }

            Button {
                text: "Batch Config (" + selectedChannels.length + ")"; font.pixelSize: 12
                enabled: selectedChannels.length > 0; onClicked: showBatchConfig = true
                background: Rectangle { color: selectedChannels.length > 0 ? "#3B82F6" : "#252830"; radius: 6; width: 140; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: selectedChannels.length > 0 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "New Patrol"; font.pixelSize: 12; onClicked: showPatrolDialog = true
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Refresh"; font.pixelSize: 12
                onClicked: { deviceController.refreshDevices(); mediaController.refreshStreams() }
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ═══ Main Content ═══
    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── Left: channel tree ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280; color: "#141720"; radius: 8
            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Text { text: "Device-Channel Tree"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                TextField {
                    width: parent.width - 24; height: 28
                    placeholderText: "Search..."; placeholderTextColor: "#4A4D58"
                    color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 4 }
                }

                ListView {
                    id: channelTree
                    width: parent.width - 24; height: parent.height - 80
                    clip: true; spacing: 1
                    model: channelTreeModel

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: modelData.type === "device" ? 32 : 28
                        color: {
                            if (treeMouse.containsMouse) return "#1A1D23"
                            if (modelData.type === "channel" && selectedChannel && selectedChannel.channelId === modelData.channelId) return "#1A2A3A"
                            return "transparent"
                        }

                        MouseArea {
                            id: treeMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (modelData.type === "device") selectedDevice = modelData
                                else selectedChannel = modelData
                            }
                        }

                        Row {
                            x: modelData.indent * 20 + 8; spacing: 6; anchors.verticalCenter: parent.verticalCenter

                            // Checkbox for channels
                            Rectangle {
                                visible: modelData.type === "channel"; width: 14; height: 14; radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: selectedChannels.indexOf(modelData.channelId) >= 0 ? "#3B82F6" : "transparent"
                                border.color: selectedChannels.indexOf(modelData.channelId) >= 0 ? "#3B82F6" : "#4A4D58"; border.width: 1
                                MouseArea { anchors.fill: parent; onClicked: toggleChannelSelect(modelData.channelId) }
                            }

                            // Status dot
                            Rectangle {
                                width: modelData.type === "device" ? 8 : 6; height: width; radius: width / 2
                                color: modelData.status === "online" ? "#00D4AA" : "#FF3D71"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.type === "device" ? "D" : "-"
                                font.pixelSize: modelData.type === "device" ? 12 : 8
                                color: modelData.status === "online" ? "#00D4AA" : "#FF3D71"
                            }

                            Text {
                                text: modelData.name
                                font.pixelSize: modelData.type === "device" ? 12 : 11
                                color: modelData.status === "online" ? "#E8E8E8" : "#4A4D58"
                                font.bold: modelData.type === "device"
                                elide: Text.ElideRight; width: 140
                            }

                            // Protocol tag (device)
                            Rectangle {
                                visible: modelData.type === "device"
                                width: 50; height: 14; radius: 3; color: "#1A2A3A"
                                Text { text: modelData.protocol || ""; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                            }

                            // Codec tag (channel)
                            Rectangle {
                                visible: modelData.type === "channel"
                                width: 36; height: 14; radius: 3; color: "#1A3A2A"
                                Text { text: modelData.codec || ""; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent }
                            }
                        }
                    }
                }
            }
        }

        // ── Right: channel detail + config + PTZ + patrol ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true; color: "#0D0F12"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 12; clip: true

                Column {
                    width: parent.width - 24; spacing: 10

                    Text { text: "Channel Config"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    // Channel config panel
                    Rectangle {
                        visible: selectedChannel !== null
                        width: parent.width; height: 220; color: "#141720"; radius: 8

                        Column {
                            anchors.fill: parent; anchors.margins: 16; spacing: 8

                            Row { spacing: 8
                                Text { text: selectedChannel ? selectedChannel.name : ""; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                                Rectangle { width: 8; height: 8; radius: 4; color: selectedChannel && selectedChannel.status === "online" ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: selectedChannel ? ("(" + selectedChannel.deviceName + ")") : ""; font.pixelSize: 12; color: "#8B8FA3" }
                            }

                            Grid { columns: 4; spacing: 12; rowSpacing: 8; width: parent.width
                                Text { text: "Stream:"; font.pixelSize: 12; color: "#8B8FA3" }
                                ComboBox { width: 120; height: 28; model: ["Main", "Sub", "Third"]
                                    background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                                Text { text: "Enabled:"; font.pixelSize: 12; color: "#8B8FA3" }
                                Switch { checked: selectedChannel ? selectedChannel.enabled : false }

                                Text { text: "Codec:"; font.pixelSize: 12; color: "#8B8FA3" }
                                ComboBox { width: 120; height: 28; model: ["H.265", "H.264", "MJPEG"]
                                    background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                                Text { text: "Resolution:"; font.pixelSize: 12; color: "#8B8FA3" }
                                ComboBox { width: 120; height: 28; model: ["3840x2160", "2560x1440", "1920x1080", "1280x720"]
                                    background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                                Text { text: "FPS:"; font.pixelSize: 12; color: "#8B8FA3" }
                                SpinBox { from: 1; to: 30; value: selectedChannel ? selectedChannel.fps : 25; height: 28 }

                                Text { text: "Bitrate(K):"; font.pixelSize: 12; color: "#8B8FA3" }
                                SpinBox { from: 256; to: 16384; value: selectedChannel ? selectedChannel.bitrate : 4096; stepSize: 512; height: 28 }
                            }

                            Row { spacing: 8
                                Button { text: "Preview"; font.pixelSize: 12
                                    onClicked: { if (selectedChannel) mediaController.startStream(selectedChannel.channelId, "main") }
                                    background: Rectangle { color: "#00D4AA"; radius: 4; width: 70; height: 28 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Snapshot"; font.pixelSize: 12
                                    onClicked: { if (selectedChannel) mediaController.snapshot(selectedChannel.channelId) }
                                    background: Rectangle { color: "#252830"; radius: 4; width: 70; height: 28 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Record"; font.pixelSize: 12
                                    onClicked: { if (selectedChannel) mediaController.startRecording(selectedChannel.channelId) }
                                    background: Rectangle { color: "#FF3D71"; radius: 4; width: 70; height: 28 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Stop Rec"; font.pixelSize: 12
                                    onClicked: { if (selectedChannel) mediaController.stopRecording(selectedChannel.channelId) }
                                    background: Rectangle { color: "#252830"; radius: 4; width: 70; height: 28 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        visible: selectedChannel === null
                        width: parent.width; height: 100; color: "#141720"; radius: 8
                        Text { anchors.centerIn: parent; text: "Select a channel from the left"; font.pixelSize: 13; color: "#4A4D58" }
                    }

                    // PTZ panel
                    Rectangle {
                        visible: selectedChannel !== null
                        width: parent.width; height: 130; color: "#141720"; radius: 8
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 6
                            Text { text: "PTZ Control"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                            Row { spacing: 12
                                Grid { columns: 3; spacing: 4
                                    Repeater {
                                        model: ["leftUp", "up", "rightUp", "left", "stop", "right", "leftDown", "down", "rightDown"]
                                        delegate: Button {
                                            text: modelData.charAt(0).toUpperCase(); font.pixelSize: 12
                                            onClicked: { if (selectedChannel) mediaController.ptzControl(selectedChannel.channelId, modelData, 0.5) }
                                            background: Rectangle { color: "#252830"; radius: 4; width: 34; height: 26 }
                                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                }
                                Column { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                                    Row { spacing: 4
                                        Button { text: "Z+"; font.pixelSize: 12; onClicked: { if (selectedChannel) mediaController.ptzControl(selectedChannel.channelId, "zoomIn", 0.3) }
                                            background: Rectangle { color: "#252830"; radius: 3; width: 32; height: 22 }
                                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                        Button { text: "Z-"; font.pixelSize: 12; onClicked: { if (selectedChannel) mediaController.ptzControl(selectedChannel.channelId, "zoomOut", 0.3) }
                                            background: Rectangle { color: "#252830"; radius: 3; width: 32; height: 22 }
                                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                    }
                                    Row { spacing: 4
                                        Button { text: "F+"; font.pixelSize: 12; onClicked: { if (selectedChannel) mediaController.ptzControl(selectedChannel.channelId, "focusNear", 0.3) }
                                            background: Rectangle { color: "#252830"; radius: 3; width: 32; height: 22 }
                                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                        Button { text: "F-"; font.pixelSize: 12; onClicked: { if (selectedChannel) mediaController.ptzControl(selectedChannel.channelId, "focusFar", 0.3) }
                                            background: Rectangle { color: "#252830"; radius: 3; width: 32; height: 22 }
                                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                    }
                                }
                            }
                        }
                    }

                    // Stream info
                    Rectangle {
                        visible: selectedChannel !== null
                        width: parent.width; height: 70; color: "#141720"; radius: 8
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 4
                            Text { text: "Stream Info"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                            Row { spacing: 20
                                Text { text: "Res: " + (selectedChannel ? (selectedChannel.resolution || "-") : "-"); font.pixelSize: 12; color: "#8B8FA3" }
                                Text { text: "FPS: " + (selectedChannel ? (selectedChannel.fps || 0) : 0); font.pixelSize: 12; color: "#8B8FA3" }
                                Text { text: "Codec: " + (selectedChannel ? (selectedChannel.codec || "-") : "-"); font.pixelSize: 12; color: "#00D4AA" }
                                Text { text: "Bitrate: " + (selectedChannel ? (selectedChannel.bitrate || 0) : 0) + " Kbps"; font.pixelSize: 12; color: "#FFB800" }
                            }
                        }
                    }

                    // Patrol schemes
                    Text { text: "Patrol Schemes"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8"; topPadding: 8 }

                    ListView {
                        width: parent.width; height: 160; clip: true; spacing: 4
                        model: [{ name: "Default Patrol (All)", interval: 10, layout: "4", channels: 12, active: true }, { name: "Key Area Patrol", interval: 5, layout: "1", channels: 4, active: false }, { name: "Parking Night", interval: 15, layout: "4", channels: 6, active: false }]
                        delegate: Rectangle {
                            width: ListView.view.width; height: 44; color: "#141720"; radius: 6
                            Row {
                                anchors.fill: parent; anchors.margins: 8; spacing: 12
                                Rectangle { width: 6; height: 6; radius: 3; color: modelData.active ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; width: 180 }
                                Text { text: "Interval:" + modelData.interval + "s"; font.pixelSize: 12; color: "#8B8FA3" }
                                Text { text: modelData.layout + "-grid"; font.pixelSize: 12; color: "#3B82F6" }
                                Text { text: modelData.channels + " ch"; font.pixelSize: 12; color: "#8B8FA3" }
                                Item { width: 20 }
                                Button { text: modelData.active ? "Stop" : "Start"; font.pixelSize: 12
                                    background: Rectangle { color: modelData.active ? "#FF3D71" : "#00D4AA"; radius: 4; width: 48; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: modelData.active ? "#FFF" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "Edit"; font.pixelSize: 12
                                    background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ Batch config dialog ═══
    Rectangle {
        visible: showBatchConfig; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showBatchConfig = false }
        Rectangle {
            width: 420; height: 340; color: "#141720"; radius: 12; anchors.centerIn: parent
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "Batch Config (" + selectedChannels.length + " channels)"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 300 }
                    Text { text: "X"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showBatchConfig = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "Codec:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 200; height: 28; model: ["H.265", "H.264", "MJPEG"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "Resolution:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 200; height: 28; model: ["3840x2160", "2560x1440", "1920x1080", "1280x720"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "FPS:"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 1; to: 30; value: batchFps; onValueChanged: batchFps = value; height: 28 }
                    Text { text: "Bitrate(K):"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 256; to: 16384; value: batchBitrate; onValueChanged: batchBitrate = value; stepSize: 512; height: 28 }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "Cancel"; font.pixelSize: 13; onClicked: showBatchConfig = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Apply"; font.pixelSize: 13
                        onClicked: { statusMsg = "Batch config applied to " + selectedChannels.length + " channels"; showBatchConfig = false; selectedChannels = []; statusTimer.start() }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }

    // ═══ Patrol dialog ═══
    Rectangle {
        visible: showPatrolDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showPatrolDialog = false }
        Rectangle {
            width: 400; height: 300; color: "#141720"; radius: 12; anchors.centerIn: parent
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "New Patrol"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Text { text: "X"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showPatrolDialog = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "Name:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: patrolName; onTextChanged: patrolName = text; width: 200; height: 28; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "Patrol name"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 4 } }
                    Text { text: "Interval(s):"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 3; to: 60; value: patrolInterval; onValueChanged: patrolInterval = value; height: 28 }
                    Text { text: "Layout:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 200; height: 28; model: ["1-grid", "4-grid", "9-grid", "16-grid"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "Cancel"; font.pixelSize: 13; onClicked: showPatrolDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Create"; font.pixelSize: 13
                        onClicked: { statusMsg = "Patrol created: " + patrolName; showPatrolDialog = false; statusTimer.start() }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }
}
