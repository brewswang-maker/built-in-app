import QtQuick 2.15
import QtQuick.Controls 2.15

Window {
    id: root
    width: 420
    height: 360
    color: "#1A1D23"
    flags: Qt.Popup | Qt.FramelessWindowHint

    property string eventType: ""
    property string level: "warning"       // "critical" / "warning" / "info"
    property string eventTime: ""
    property string location: ""
    property string description: ""
    property real confidence: 0.0
    property string aiVerdict: ""
    property string snapshotUrl: ""
    property int autoCloseMs: 3000

    readonly property var levelColors: ({
        "critical": "#FF3D71",
        "warning":  "#FF6B35",
        "info":     "#00D4AA"
    })

    readonly property color levelColor: levelColors[level] || levelColors["warning"]

    signal confirmed()
    signal falseAlarm()
    signal muted()
    signal replay()

    onVisibleChanged: {
        if (visible) autoCloseTimer.start()
    }

    Timer {
        id: autoCloseTimer
        interval: root.autoCloseMs
        running: false
        onTriggered: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: "#1A1D23"
        radius: 12
        border.color: root.levelColor
        border.width: 2

        // Close button
        Rectangle {
            id: closeBtn
            width: 24
            height: 24
            radius: 12
            color: "#252830"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            z: 20

            Text {
                text: "✕"
                color: "#8B8FA3"
                font.pixelSize: 12
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            Row {
                spacing: 8
                width: parent.width

                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: root.levelColor
                }

                Column {
                    spacing: 2
                    Text {
                        text: "🚨 " + root.eventType
                        color: "#E8E8E8"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "PingFang SC"
                    }
                    Text {
                        text: root.eventTime
                        color: "#8B8FA3"
                        font.pixelSize: 12
                        font.family: "PingFang SC"
                    }
                }
            }

            // Snapshot
            Rectangle {
                width: parent.width
                height: 140
                radius: 8
                color: "#141720"
                clip: true

                Image {
                    id: snapshotImg
                    anchors.fill: parent
                    source: root.snapshotUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    text: "📸 告警截图"
                    color: "#4A4D58"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                    visible: !snapshotImg.visible
                }
            }

            // Info grid
            Grid {
                columns: 2
                columnSpacing: 12
                rowSpacing: 4
                width: parent.width

                Text { text: "📍 位置: "; color: "#8B8FA3"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: root.location; color: "#E8E8E8"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: "🎯 置信度: "; color: "#8B8FA3"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: (root.confidence * 100).toFixed(1) + "%"; color: "#E8E8E8"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: "📝 描述: "; color: "#8B8FA3"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: root.description; color: "#E8E8E8"; font.pixelSize: 12; font.family: "PingFang SC"; wrapMode: Text.WordWrap; width: 240 }
                Text { text: "🤖 AI研判: "; color: "#8B8FA3"; font.pixelSize: 12; font.family: "PingFang SC" }
                Text { text: root.aiVerdict; color: "#00D4AA"; font.pixelSize: 12; font.family: "PingFang SC"; wrapMode: Text.WordWrap; width: 240 }
            }

            // Action buttons
            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    text: "✅ 确认"
                    font.family: "PingFang SC"
                    onClicked: { root.confirmed(); root.close() }
                    background: Rectangle { color: "#00D4AA"; radius: 6; implicitWidth: 80; implicitHeight: 32 }
                    contentItem: Text { text: parent.text; color: "#0D0F12"; font.pixelSize: 13; font.bold: true; anchors.centerIn: parent }
                }
                Button {
                    text: "❌ 误报"
                    font.family: "PingFang SC"
                    onClicked: { root.falseAlarm(); root.close() }
                    background: Rectangle { color: "#FF6B35"; radius: 6; implicitWidth: 80; implicitHeight: 32 }
                    contentItem: Text { text: parent.text; color: "#0D0F12"; font.pixelSize: 13; font.bold: true; anchors.centerIn: parent }
                }
                Button {
                    text: "🔇 静音"
                    font.family: "PingFang SC"
                    onClicked: { root.muted(); root.close() }
                    background: Rectangle { color: "#252830"; radius: 6; implicitWidth: 80; implicitHeight: 32 }
                    contentItem: Text { text: parent.text; color: "#8B8FA3"; font.pixelSize: 13; anchors.centerIn: parent }
                }
                Button {
                    text: "📹 回放"
                    font.family: "PingFang SC"
                    onClicked: { root.replay(); root.close() }
                    background: Rectangle { color: "#252830"; radius: 6; implicitWidth: 80; implicitHeight: 32 }
                    contentItem: Text { text: parent.text; color: "#8B8FA3"; font.pixelSize: 13; anchors.centerIn: parent }
                }
            }
        }
    }

    // Listen for new alarms
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            root.eventType = alarm.type || ""
            root.level = alarm.level || "warning"
            root.eventTime = alarm.time || Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
            root.location = alarm.location || alarm.channel || ""
            root.description = alarm.description || ""
            root.confidence = alarm.confidence || 0
            root.aiVerdict = alarm.aiVerdict || ""
            root.snapshotUrl = alarm.snapshotUrl || ""
            root.show()
        }
    }
}
