import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: alarmPage

    // ── Summary Bar ──
    Rectangle {
        id: summaryBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "#141720"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 24

            Text {
                text: "🚨 告警中心"
                font.pixelSize: 16
                font.bold: true
                color: "#E8E8E8"
            }

            Rectangle {
                width: 80; height: 28; radius: 14
                color: "#FF3D71"
                Text {
                    anchors.centerIn: parent
                    text: "未处理"
                    font.pixelSize: 12
                    color: "white"
                    font.bold: true
                }
            }

            Text {
                text: "今日: " + alarmController.alarmCount + " 条"
                font.pixelSize: 13
                color: "#8B8FA3"
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "刷新"
                font.pixelSize: 12
                onClicked: alarmController.refreshAlarms(50)
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: parent.text; font.pixelSize: parent.font.pixelSize
                    color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── Alarm List ──
    ListView {
        id: alarmList
        anchors.top: summaryBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 6
        clip: true
        model: alarmController.alarms

        delegate: Rectangle {
            width: alarmList.width
            height: 88
            color: "#1A1D23"
            radius: 8

            property var levelColor: {
                var lvl = modelData.level || "info";
                if (lvl === "critical" || lvl === "Critical") return "#FF3D71";
                if (lvl === "warning" || lvl === "Warning") return "#FF6B35";
                return "#00D4AA";
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                radius: 2
                color: levelColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12

                // Alarm icon
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: levelColor
                    opacity: 0.15
                    Text {
                        anchors.centerIn: parent
                        text: "🚨"
                        font.pixelSize: 22
                    }
                }

                // Info
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: modelData.alarm_type || "未知告警"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#E8E8E8"
                    }
                    Text {
                        text: modelData.description || ""
                        font.pixelSize: 12
                        color: "#8B8FA3"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Row {
                        spacing: 12
                        Text {
                            text: "📍 " + (modelData.channel_id || "")
                            font.pixelSize: 11
                            color: "#4A4D58"
                        }
                        Text {
                            text: "🎯 " + (modelData.confidence ? (modelData.confidence * 100).toFixed(1) + "%" : "N/A")
                            font.pixelSize: 11
                            color: "#4A4D58"
                        }
                        Text {
                            text: modelData.timestamp || ""
                            font.pixelSize: 11
                            color: "#4A4D58"
                        }
                    }
                }

                // Action buttons
                Row {
                    spacing: 4

                    Button {
                        width: 36; height: 36
                        text: "✅"
                        font.pixelSize: 14
                        onClicked: alarmController.confirmAlarm(modelData.alarm_id)
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        ToolTip.visible: pressed
                        ToolTip.text: "确认"
                    }
                    Button {
                        width: 36; height: 36
                        text: "❌"
                        font.pixelSize: 14
                        onClicked: alarmController.markFalseAlarm(modelData.alarm_id)
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        ToolTip.visible: pressed
                        ToolTip.text: "误报"
                    }
                    Button {
                        width: 36; height: 36
                        text: "🔇"
                        font.pixelSize: 14
                        onClicked: alarmController.handleAlarm(modelData.alarm_id, "mute")
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        ToolTip.visible: pressed
                        ToolTip.text: "静音"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {
                    // Show alarm detail popup
                }
            }
        }
    }

    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            // List auto-updates via alarmController.alarms binding
        }
    }
}
