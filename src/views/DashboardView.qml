import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: dashboard

    // ── Quick Stats Bar ──
    Rectangle {
        id: statsBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: "#141720"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 32

            Text {
                text: "🟢 在线设备: " + deviceController.deviceCount
                font.pixelSize: 13
                color: "#00D4AA"
            }
            Text {
                text: "🚨 今日告警: " + alarmController.alarmCount
                font.pixelSize: 13
                color: alarmController.hasUnread ? "#FF3D71" : "#8B8FA3"
            }
            Text {
                text: "🛡️ 安全评分: 85/100"
                font.pixelSize: 13
                color: "#FFB800"
            }

            Item { Layout.fillWidth: true }

            // Layout switcher
            Row {
                spacing: 4
                Repeater {
                    model: [1, 4, 9, 16]
                    delegate: Button {
                        width: 36
                        height: 28
                        text: modelData
                        font.pixelSize: 12
                        highlighted: mediaController.currentLayout === modelData
                        onClicked: mediaController.setLayout(modelData)
                        background: Rectangle {
                            color: parent.highlighted ? "#00D4AA" : "#252830"
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: parent.font.pixelSize
                            color: parent.highlighted ? "#0D0F12" : "#8B8FA3"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    // ── Video Grid ──
    Grid {
        id: videoGrid
        anchors.top: statsBar.bottom
        anchors.bottom: aiBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        anchors.bottomMargin: 4
        spacing: 4

        property int cols: mediaController.currentLayout <= 1 ? 1 :
                           mediaController.currentLayout <= 4 ? 2 :
                           mediaController.currentLayout <= 9 ? 3 : 4
        property int rows: mediaController.currentLayout <= 1 ? 1 :
                           mediaController.currentLayout <= 4 ? 2 :
                           mediaController.currentLayout <= 9 ? 3 : 4

        columns: cols
        rows: rows

        Repeater {
            model: mediaController.currentLayout

            VideoTile {
                width: videoGrid.width / videoGrid.cols - 4
                height: videoGrid.height / videoGrid.rows - 4
                deviceId: index < deviceController.devices.length ?
                    deviceController.devices[index].device_id || "" : ""
                channelName: index < deviceController.devices.length ?
                    deviceController.devices[index].device_name || ("Camera_" + (index + 1)) :
                    ("Camera_" + (index + 1))
                status: index < deviceController.devices.length ?
                    deviceController.devices[index].status || "offline" : "offline"
                algorithmTag: index < deviceController.devices.length ?
                    deviceController.devices[index].algorithm || "" : ""
            }
        }
    }

    // ── AI Assistant Bar ──
    Rectangle {
        id: aiBar
        anchors.bottom: statusBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: 4
        height: 48
        color: "#1A1D23"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Text {
                text: "🤖"
                font.pixelSize: 18
            }

            TextField {
                id: aiInput
                Layout.fillWidth: true
                placeholderText: "输入指令... (例: 查看3号厂区今日告警统计)"
                placeholderTextColor: "#4A4D58"
                color: "#E8E8E8"
                font.pixelSize: 13
                background: Rectangle {
                    color: "#252830"
                    radius: 6
                }
                onAccepted: {
                    if (text.trim()) {
                        aiController.sendMessage(text.trim())
                        text = ""
                    }
                }
            }

            Button {
                text: "发送"
                font.pixelSize: 13
                onClicked: {
                    if (aiInput.text.trim()) {
                        aiController.sendMessage(aiInput.text.trim())
                        aiInput.text = ""
                    }
                }
                background: Rectangle {
                    color: "#00D4AA"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    color: "#0D0F12"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── Status Bar ──
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        color: "#141720"
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 24

            Text {
                text: "CPU: " + statusController.cpuUsage.toFixed(1) + "%"
                font.pixelSize: 11
                color: statusController.cpuUsage > 80 ? "#FF3D71" : "#8B8FA3"
            }
            Text {
                text: "GPU: " + statusController.gpuUsage.toFixed(1) + "%"
                font.pixelSize: 11
                color: statusController.gpuUsage > 80 ? "#FF3D71" : "#8B8FA3"
            }
            Text {
                text: "TPU: " + statusController.tpuUtilization.toFixed(1) + "%"
                font.pixelSize: 11
                color: statusController.tpuUtilization > 90 ? "#FF3D71" : "#00D4AA"
            }
            Text {
                text: "内存: " + statusController.memoryUsage.toFixed(1) + "%"
                font.pixelSize: 11
                color: statusController.memoryUsage > 85 ? "#FF6B35" : "#8B8FA3"
            }
            Text {
                text: "温度: " + statusController.temperature.toFixed(0) + "°C"
                font.pixelSize: 11
                color: statusController.temperature > 70 ? "#FF3D71" : "#8B8FA3"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "模型: " + statusController.activeModels + " | " +
                      "运行: " + statusController.uptime
                font.pixelSize: 11
                color: "#4A4D58"
            }
        }
    }
}
