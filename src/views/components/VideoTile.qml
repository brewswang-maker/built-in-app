import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: root

    property string deviceId: ""
    property string channelName: ""
    property string streamUrl: ""
    property alias status: statusIndicator.status
    property string fps: "0"
    property string algorithmTag: ""
    property var detectionBoxes: []
    property bool active: false

    signal doubleClicked()

    // Video playback
    Rectangle {
        id: videoBackground
        anchors.fill: parent
        color: "#0D0F12"
        radius: 8
        clip: true

        MediaPlayer {
            id: mediaPlayer
            source: root.streamUrl.length > 0 ? root.streamUrl : ""
            videoOutput: videoOutput
            autoPlay: true
            // [Audit-Fix P1] autoPlay=true 已在 source 变更时自动播放,
            //   onStreamUrlChanged 中不再显式调 play(), 避免 stop→play→黑屏 双触发
            onErrorOccurred: function(error, errorString) {
                console.warn("MediaPlayer[" + root.deviceId + "] ERROR:", error, errorString)
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: root.streamUrl.length > 0
            // Connection established via MediaPlayer.videoOutput above
        }

        Row {
            spacing: 6
            anchors.centerIn: parent
            visible: root.streamUrl.length === 0
            AppIcon { name: "camera"; size: 18; iconColor: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: channelName || "未连接"
                color: "#4A4D58"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // P1-1: AI Detection overlay (color-coded + confidence)
    Repeater {
        model: root.detectionBoxes

        Item {
            required property var modelData
            x: modelData.x * root.width
            y: modelData.y * root.height
            width: modelData.width * root.width
            height: modelData.height * root.height

            // Detection box border with class-based color
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: modelData.color || "#FF6B35"
                border.width: 2
                radius: 2
                // Smooth fade for detection updates
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Corner accent marks (professional style like Hikvision)
            Rectangle { width: 8; height: 2; color: modelData.color || "#FF6B35"; anchors.top: parent.top; anchors.left: parent.left }
            Rectangle { width: 2; height: 8; color: modelData.color || "#FF6B35"; anchors.top: parent.top; anchors.left: parent.left }
            Rectangle { width: 8; height: 2; color: modelData.color || "#FF6B35"; anchors.top: parent.top; anchors.right: parent.right }
            Rectangle { width: 2; height: 8; color: modelData.color || "#FF6B35"; anchors.top: parent.top; anchors.right: parent.right }
            Rectangle { width: 8; height: 2; color: modelData.color || "#FF6B35"; anchors.bottom: parent.bottom; anchors.left: parent.left }
            Rectangle { width: 2; height: 8; color: modelData.color || "#FF6B35"; anchors.bottom: parent.bottom; anchors.left: parent.left }
            Rectangle { width: 8; height: 2; color: modelData.color || "#FF6B35"; anchors.bottom: parent.bottom; anchors.right: parent.right }
            Rectangle { width: 2; height: 8; color: modelData.color || "#FF6B35"; anchors.bottom: parent.bottom; anchors.right: parent.right }

            // Label + confidence badge
            Rectangle {
                color: modelData.color || "#FF6B35"
                radius: 2
                width: labelText.implicitWidth + 12
                height: 16
                anchors.bottom: parent.top
                anchors.left: parent.left
                anchors.bottomMargin: 1

                Text {
                    id: labelText
                    text: (modelData.label || "unknown") + " " + Math.round((modelData.confidence || 0) * 100) + "%"
                    color: "#FFFFFF"
                    font.pixelSize: 12  // [Audit-Fix P1] 9→12 (QtQuick.Controls 2 最小规范)
                    font.bold: true
                    font.family: "PingFang SC"
                    anchors.centerIn: parent
                }
            }
        }
    }

    // Overlay layer
    Item {
        anchors.fill: parent
        z: 10

        // Top-left: channel name
        Text {
            id: channelLabel
            text: "通道1"
            color: "#E8E8E8"
            font.pixelSize: 13
            font.family: "PingFang SC"
            font.bold: true
            padding: 6
            anchors.top: parent.top
            anchors.left: parent.left

            style: Text.Outline
            styleColor: "#000000"
        }

        // Top-right: algorithm tag
        Rectangle {
            visible: root.algorithmTag.length > 0
            height: 22
            radius: 4
            color: "#00D4AA"
            opacity: 0.85
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6

            Text {
                text: root.algorithmTag
                color: "#0D0F12"
                font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
                font.bold: true
                font.family: "PingFang SC"
                anchors.centerIn: parent
                leftPadding: 6
                rightPadding: 6
            }
        }

        // Bottom-left: status indicator
        StatusIndicator {
            id: statusIndicator
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 6
        }

        // Bottom-right: FPS
        Text {
            text: root.fps + " FPS"
            color: "#8B8FA3"
            font.pixelSize: 12  // [Audit-Fix P1] 11→12 (规范最小)
            font.family: "PingFang SC"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 6

            style: Text.Outline
            styleColor: "#000000"
        }

        // Active slot highlight border
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#00D4AA"
            border.width: 2
            radius: 8
            visible: root.active
        }
    }

    // [Audit-Fix P1] 仅在 URL 清空时显式 stop();
    //   URL 设置时由 autoPlay=true 自动播放, 不再显式 play() 避免 double-trigger
    onStreamUrlChanged: {
        if (root.streamUrl.length === 0) {
            mediaPlayer.stop()
        }
    }

    // Double click -> fullscreen
    MouseArea {
        anchors.fill: parent
        onDoubleClicked: root.doubleClicked()
    }
}
