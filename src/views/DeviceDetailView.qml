// ========================================================================
// DeviceDetailView.qml — 设备详情 (信息+通道+PTZ+预览)
// Controller: deviceController + mediaController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: detailView

    property string deviceId: ""
    property var deviceDetail: ({})

    Component.onCompleted: {
        if (deviceId) deviceController.getDeviceDetail(deviceId)
    }

    Connections {
        target: deviceController
        function onDeviceDetailReceived(detail) {
            deviceDetail = detail
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Button {
                text: "← 返回"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Text { text: deviceDetail.name || "设备详情"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Rectangle { width: 8; height: 8; radius: 4; color: deviceDetail.status === "online" ? "#00D4AA" : "#FF3D71" }
            Text { text: deviceDetail.status || "unknown"; font.pixelSize: 12; color: deviceDetail.status === "online" ? "#00D4AA" : "#FF3D71" }
            Item { Layout.fillWidth: true }
            Button {
                text: "🔄 刷新"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.getDeviceDetail(deviceId)
            }
            Button {
                text: "🗑 删除设备"; font.pixelSize: 12
                background: Rectangle { color: "#FF3D71"; radius: 6; width: 80; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: deviceController.removeDevice(deviceId)
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 设备信息 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#141720"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 12; clip: true

                Column {
                    width: 256; spacing: 10

                    // 设备图标+名称
                    Rectangle {
                        width: parent.width; height: 80; color: "#0D0F12"; radius: 8
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "📹"; font.pixelSize: 28; horizontalAlignment: Text.AlignHCenter }
                            Text { text: deviceDetail.name || "设备"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter }
                        }
                    }

                    // 基本信息
                    Text { text: "📋 基本信息"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Column { spacing: 4; width: parent.width
                        Row { spacing: 6; Text { text: "型号:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.model || "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "序列号:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.serialNumber || "-"; font.pixelSize: 11; color: "#3B82F6" } }
                        Row { spacing: 6; Text { text: "固件:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.firmware || "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "IP:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.ip || "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "MAC:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.mac || "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "协议:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.protocol || "-"; font.pixelSize: 11; color: "#8B5CF6" } }
                    }

                    // 运行状态
                    Text { text: "📊 运行状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Column { spacing: 4; width: parent.width
                        Row { spacing: 6; Text { text: "温度:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: (deviceDetail.temperature || "-") + "°C"; font.pixelSize: 11; color: deviceDetail.temperature > 70 ? "#FF3D71" : "#00D4AA" } }
                        Row { spacing: 6; Text { text: "CPU:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: (deviceDetail.cpuUsage || "-") + "%"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "内存:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: (deviceDetail.memoryUsage || "-") + "%"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "运行时间:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.uptime || "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 6; Text { text: "通道数:"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 } Text { text: deviceDetail.channelCount || "0"; font.pixelSize: 11; color: "#E8E8E8" } }
                    }

                    // 操作
                    Text { text: "🔧 操作"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Column { spacing: 6; width: parent.width
                        Button { text: "🔄 重启设备"; width: parent.width; background: Rectangle { color: "#FFB800"; radius: 6; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        Button { text: "🔧 恢复出厂"; width: parent.width; background: Rectangle { color: "#252830"; radius: 6; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    }
                }
            }
        }

        // ── 中间: 通道列表 + 视频预览 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Row {
                    spacing: 12
                    Text { text: "通道列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Text { text: (deviceDetail.channels || 0) + " 路"; font.pixelSize: 11; color: "#8B8FA3" }
                }

                // 视频预览区
                Rectangle {
                    width: parent.width - 24; height: 200; color: "#000"; radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: "点击通道开始预览"
                        font.pixelSize: 14; color: "#4A4D58"
                    }
                }

                // 通道网格
                GridView {
                    width: parent.width - 24; height: parent.height - 280; cellWidth: 140; cellHeight: 50; clip: true
                    model: deviceDetail.channelList || []

                    delegate: Rectangle {
                        width: 132; height: 42; color: "#141720"; radius: 6

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mediaController.startStream(modelData.channelId || "", "live")
                        }

                        Row {
                            anchors.fill: parent; anchors.margins: 8; spacing: 6
                            Rectangle { width: 4; height: 4; radius: 2; color: modelData.streaming ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.name || "CH" + (index+1); font.pixelSize: 11; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: 10 }
                            Button {
                                text: "▶"; font.pixelSize: 10
                                background: Rectangle { color: "#252830"; radius: 3; width: 22; height: 18 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#00D4AA"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.startStream(modelData.channelId || "", "live")
                            }
                            Button {
                                text: "📷"; font.pixelSize: 10
                                background: Rectangle { color: "#252830"; radius: 3; width: 22; height: 18 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: mediaController.snapshot(modelData.channelId || "")
                            }
                        }
                    }
                }
            }
        }

        // ── 右侧: PTZ控制 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 180
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 6

                Text { text: "🎮 PTZ"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 3; spacing: 3; anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: ["↖", "↑", "↗", "←", "⏹", "→", "↙", "↓", "↘"]
                        delegate: Button {
                            width: 44; height: 44
                            background: Rectangle { color: pressed ? "#3B82F6" : "#252830"; radius: 6 }
                            contentItem: Text { text: modelData; font.pixelSize: 14; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: {
                                var cmds = ["left_up","up","right_up","left","stop","right","left_down","down","right_down"]
                                mediaController.ptzControl(deviceId, cmds[index], 0.5)
                            }
                        }
                    }
                }

                Column { spacing: 2; width: parent.width - 20
                    Text { text: "变倍"; font.pixelSize: 10; color: "#8B8FA3" }
                    Slider { width: parent.width; from: 1; to: 20; value: 1; onMoved: mediaController.ptzControl(deviceId, "zoom", value/20) }
                }
                Column { spacing: 2; width: parent.width - 20
                    Text { text: "聚焦"; font.pixelSize: 10; color: "#8B8FA3" }
                    Slider { width: parent.width; from: 0; to: 100; value: 50; onMoved: mediaController.ptzControl(deviceId, "focus", value/100) }
                }

                Text { text: "📍 预置点"; font.pixelSize: 11; color: "#E8E8E8" }
                Grid { columns: 4; spacing: 3
                    Repeater {
                        model: 8
                        delegate: Button {
                            text: "P" + (index+1); font.pixelSize: 9
                            width: 34; height: 22
                            background: Rectangle { color: "#252830"; radius: 3 }
                            contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: mediaController.ptzControl(deviceId, "preset_" + (index+1), 0)
                        }
                    }
                }

                Button {
                    text: "📷 截图"; width: parent.width - 20
                    background: Rectangle { color: "#00D4AA"; radius: 6; height: 30 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: mediaController.snapshot(deviceId)
                }
            }
        }
    }
}
