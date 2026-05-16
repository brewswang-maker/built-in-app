import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: videoGridPage

    // ── Toolbar ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: "#141720"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Text {
                text: "📹 视频预览"
                font.pixelSize: 16
                font.bold: true
                color: "#E8E8E8"
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 4
                Repeater {
                    model: [1, 4, 9, 16]
                    delegate: Button {
                        width: 40
                        height: 32
                        text: modelData + "宫格"
                        font.pixelSize: 11
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

            Button {
                text: "📷 截图"
                font.pixelSize: 12
                onClicked: mediaController.snapshot("current")
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: parent.text; font.pixelSize: parent.font.pixelSize
                    color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: mediaController.isRecording ? "⏹ 停止录像" : "⏺ 录像"
                font.pixelSize: 12
                onClicked: mediaController.isRecording ?
                    mediaController.stopRecording("current") :
                    mediaController.startRecording("current")
                background: Rectangle {
                    color: mediaController.isRecording ? "#FF3D71" : "#252830"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: parent.font.pixelSize
                    color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── PTZ Panel (right side) ──
    Rectangle {
        id: ptzPanel
        anchors.top: toolbar.bottom
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 160
        color: "#141720"
        visible: mediaController.currentLayout === 1

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "云台控制"
                font.pixelSize: 13
                font.bold: true
                color: "#E8E8E8"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Grid {
                columns: 3
                spacing: 4
                anchors.horizontalCenter: parent.horizontalCenter

                Button { width: 44; height: 36; text: "↖"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "left_up", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "↑"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "up", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "↗"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "right_up", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "←"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "left", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Rectangle { width: 44; height: 36; color: "#1A1D23"; radius: 4 }
                Button { width: 44; height: 36; text: "→"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "right", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "↙"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "left_down", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "↓"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "down", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button { width: 44; height: 36; text: "↘"; font.pixelSize: 16
                    onClicked: mediaController.ptzControl("current", "right_down", 0.5)
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            Text { text: "变倍"; font.pixelSize: 11; color: "#8B8FA3" }
            Slider {
                width: 140
                from: 1
                to: 20
                value: 1
                onMoved: mediaController.ptzControl("current", "zoom", value)
            }
        }
    }

    // ── Video Grid ──
    Grid {
        id: grid
        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.right: ptzPanel.visible ? ptzPanel.left : parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
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
                width: grid.width / grid.cols - 4
                height: grid.height / grid.rows - 4
                deviceId: index < deviceController.devices.length ?
                    deviceController.devices[index].device_id || "" : ""
                channelName: index < deviceController.devices.length ?
                    deviceController.devices[index].device_name || ("Camera_" + (index + 1)) :
                    ("Camera_" + (index + 1))
                status: index < deviceController.devices.length ?
                    deviceController.devices[index].status || "offline" : "offline"
            }
        }
    }
}
