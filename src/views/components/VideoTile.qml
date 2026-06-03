import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent

    property alias deviceId: deviceIdText.text
    property alias channelName: channelLabel.text
    property alias streamUrl: streamUrlText.text
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
            source: streamUrlText.text.length > 0 ? streamUrlText.text : ""
            videoOutput: videoOutput
            onErrorOccurred: function(error, errorString) {
                console.warn("MediaPlayer error:", errorString)
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: streamUrlText.text.length > 0
        }

        Text {
            text: "📹 " + (channelName || "未连接")
            color: "#4A4D58"
            font.pixelSize: 16
            anchors.centerIn: parent
            visible: streamUrlText.text.length === 0
        }
    }

    // Detection boxes overlay
    Repeater {
        model: root.detectionBoxes

        Rectangle {
            required property var modelData
            x: modelData.x * root.width
            y: modelData.y * root.height
            width: modelData.width * root.width
            height: modelData.height * root.height
            color: "transparent"
            border.color: "#FF6B35"
            border.width: 2
            radius: 2

            Rectangle {
                color: "#FF6B35"
                radius: 2
                implicitWidth: labelBgText.implicitWidth + 4
                implicitHeight: labelBgText.implicitHeight + 2
                Text {
                    id: labelBgText
                    text: modelData.label || ""
                    color: "#FFFFFF"
                    font.pixelSize: 10
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
                font.pixelSize: 11
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
            font.pixelSize: 11
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

    // Hidden: device ID and stream URL
    Text { id: deviceIdText; visible: false }
    Text { id: streamUrlText; visible: false }

    // Auto-play when URL is set
    onStreamUrlChanged: {
        if (streamUrlText.text.length > 0) {
            mediaPlayer.play()
        } else {
            mediaPlayer.stop()
        }
    }

    // Double click -> fullscreen
    MouseArea {
        anchors.fill: parent
        onDoubleClicked: root.doubleClicked()
    }
}
