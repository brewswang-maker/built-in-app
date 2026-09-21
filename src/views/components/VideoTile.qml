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

    // [S3-4 2026-09-20] WebRTC 协议分支判定:
    //   webrtc://host:port/index/api/webrtc?... 或 http(s)://.../index/api/webrtc?...
    //   为 true 时绕过 Qt MediaPlayer(不支持 webrtc://), 改由 WebRtcView 软渲染显示
    readonly property bool isWebRtcUrl: {
        var u = root.streamUrl.toLowerCase()
        return u.indexOf("webrtc://") === 0
            || (u.indexOf("http") === 0 && u.indexOf("/index/api/webrtc") > 0)
    }

    // [V4-V3] 画面调节属性
    property real imgBrightness: 0.0   // -0.5 ~ 0.5
    property real imgContrast: 1.0     // 0.0 ~ 2.0
    property real imgSaturation: 1.0   // 0.0 ~ 2.0
    property bool mirrorH: false
    property bool mirrorV: false

    // [V4-V4] 电子放大 eZoom
    property real eZoomLevel: 1.0    // 1.0=正常 ~ 4.0=4倍放大
    property real eZoomOffsetX: 0.5  // 缩放中心 X (0.0~1.0)
    property real eZoomOffsetY: 0.5  // 缩放中心 Y (0.0~1.0)

    signal doubleClicked()
    // [S3-4 2026-09-20] 播放失败事件(WebRTC/MediaPlayer 错误桥):
    //   VideoGridView 接此信号 → mediaController.reportProtocolFailure 触发降级链
    signal streamFailed(string reason)

    // Video playback
    Rectangle {
        id: videoBackground
        anchors.fill: parent
        color: "#0D0F12"
        radius: 8
        clip: true

        MediaPlayer {
            id: mediaPlayer
            // [S3-4 2026-09-20] WebRTC URL 不走 MediaPlayer(source 置空), 由下方 WebRtcView 承载
            source: (root.streamUrl.length > 0 && !root.isWebRtcUrl) ? root.streamUrl : ""
            videoOutput: videoOutput
            autoPlay: true
            // [Audit-Fix P1] autoPlay=true 已在 source 变更时自动播放,
            //   onStreamUrlChanged 中不再显式调 play(), 避免 stop→play→黑屏 双触发
            onErrorOccurred: function(error, errorString) {
                console.warn("MediaPlayer[" + root.deviceId + "] ERROR:", error, errorString)
                // [S3-4] 错误上抛(降级链输入): 仅对生效中的非 WebRTC 流上报
                if (root.streamUrl.length > 0 && !root.isWebRtcUrl)
                    root.streamFailed("mediaplayer: " + errorString)
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: root.streamUrl.length > 0 && !root.isWebRtcUrl
            // [V4-V3] 镜像翻转 + [V4-V4] 电子放大
            transform: [
                Scale {
                    xScale: root.mirrorH ? -1 : 1
                    yScale: root.mirrorV ? -1 : 1
                    origin.x: videoOutput.width / 2
                    origin.y: videoOutput.height / 2
                },
                Scale {
                    xScale: root.eZoomLevel
                    yScale: root.eZoomLevel
                    origin.x: videoOutput.width * root.eZoomOffsetX
                    origin.y: videoOutput.height * root.eZoomOffsetY
                }
            ]
            // [V4-V3] 色彩调节 (layer + ShaderEffect)
            layer.enabled: root.imgBrightness !== 0.0 || root.imgContrast !== 1.0 || root.imgSaturation !== 1.0
            layer.effect: ShaderEffect {
                property real brightness: root.imgBrightness
                property real contrast: root.imgContrast
                property real saturation: root.imgSaturation
                fragmentShader: [
                    "uniform sampler2D source;",
                    "uniform lowp float qt_Opacity;",
                    "uniform highp float brightness;",
                    "uniform highp float contrast;",
                    "uniform highp float saturation;",
                    "varying highp vec2 qt_TexCoord0;",
                    "void main() {",
                    "    lowp vec4 src = texture2D(source, qt_TexCoord0);",
                    "    lowp vec3 color = src.rgb + vec3(brightness);",
                    "    color = (color - 0.5) * contrast + 0.5;",
                    "    lowp float gray = dot(color, vec3(0.299, 0.587, 0.114));",
                    "    color = mix(vec3(gray), color, saturation);",
                    "    color = clamp(color, 0.0, 1.0);",
                    "    gl_FragColor = vec4(color, src.a) * qt_Opacity;",
                    "}"
                ].join("\n")
            }
            // Connection established via MediaPlayer.videoOutput above
        }

        // [S3-4 2026-09-20] WebRTC 渲染分支(S3-2 信令/解包/解码 + S3-3 软渲染真实通路):
        //   webrtc:// URL → WebRtcView 收流解码 → QQuickPaintedItem.drawImage;
        //   失败信号上抛 root.streamFailed → VideoGridView 级降级
        WebRtcView {
            id: webRtcView
            anchors.fill: parent
            visible: root.isWebRtcUrl
            streamUrl: root.isWebRtcUrl ? root.streamUrl : ""

            onStreamFailed: function(reason) {
                console.warn("WebRtc[" + root.deviceId + "] ERROR:", reason)
                root.streamFailed(reason)
            }
        }

        // [v7.7 对齐 Web video-empty] 空格: 摄像机图标 + "拖拽通道到此处"
        Column {
            spacing: 6
            anchors.centerIn: parent
            visible: root.streamUrl.length === 0
            AppIcon { name: "camera"; size: 32; iconColor: "#8c8c8c"; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                text: "拖拽通道到此处"
                color: "#8c8c8c"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
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

        // Top-left: channel name [v7.7] 仅拉流时显示, 使用真实通道名
        Text {
            id: channelLabel
            visible: root.streamUrl.length > 0
            text: root.channelName || "未命名通道"
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

        // [V4-V4] eZoom 缩放指示器
        Rectangle {
            visible: root.eZoomLevel > 1.0
            height: 20; radius: 4
            color: "#FFB800"; opacity: 0.9
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 6
            width: zoomLabel.implicitWidth + 20

            Text {
                id: zoomLabel
                text: "\uD83D\uDD0D " + root.eZoomLevel.toFixed(1) + "x  (\u6ED1\u8F6E\u7F29\u653E \u00B7 \u62D6\u62FD\u5E73\u79FB \u00B7 \u53CC\u51FB\u590D\u4F4D)"
                color: "#0D0F12"
                font.pixelSize: 11; font.bold: true
                anchors.centerIn: parent
            }
        }

        // Active slot highlight border [v7.7] 对齐 Web active 蓝色选中框
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#409EFF"
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: root.doubleClicked()
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                tileContextMenu.popup()
            }
        }
    }

    // [V4-V3] 右键上下文菜单
    Menu {
        id: tileContextMenu

        MenuItem {
            text: "画面调节..."
            onTriggered: imageControlPanel.open()
        }
        MenuItem {
            text: root.mirrorH ? "取消水平镜像" : "水平镜像"
            onTriggered: root.mirrorH = !root.mirrorH
        }
        MenuItem {
            text: root.mirrorV ? "取消垂直翻转" : "垂直翻转"
            onTriggered: root.mirrorV = !root.mirrorV
        }
        MenuSeparator {}
        MenuItem {
            text: root.eZoomLevel > 1.0 ? ("重置电子放大 (" + root.eZoomLevel.toFixed(1) + "x)") : "电子放大"
            enabled: root.eZoomLevel > 1.0
            onTriggered: {
                root.eZoomLevel = 1.0
                root.eZoomOffsetX = 0.5
                root.eZoomOffsetY = 0.5
            }
        }
        MenuSeparator {}
        MenuItem {
            text: "重置画面"
            onTriggered: {
                root.imgBrightness = 0.0
                root.imgContrast = 1.0
                root.imgSaturation = 1.0
                root.mirrorH = false
                root.mirrorV = false
                root.eZoomLevel = 1.0
                root.eZoomOffsetX = 0.5
                root.eZoomOffsetY = 0.5
            }
        }
    }

    // [V4-V3] 画面调节面板
    ImageControlPanel {
        id: imageControlPanel
        x: parent.width - width - 10
        y: 10
        brightness: root.imgBrightness
        contrast: root.imgContrast
        saturation: root.imgSaturation
        mirrorH: root.mirrorH
        mirrorV: root.mirrorV
        onAdjusted: {
            root.imgBrightness = brightness
            root.imgContrast = contrast
            root.imgSaturation = saturation
            root.mirrorH = mirrorH
            root.mirrorV = mirrorV
        }
        onResetRequested: {
            root.imgBrightness = 0.0
            root.imgContrast = 1.0
            root.imgSaturation = 1.0
            root.mirrorH = false
            root.mirrorV = false
        }
    }
}
