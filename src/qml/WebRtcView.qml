import QtQuick

/**
 * @brief WebRtcView
 *
 * 子任务 2 — V4-V1 WebRTC 渲染引擎集成(SmartGateWay v4.0 §4.1)
 *
 * QML 包装 WebRtcRendererItem(registerType 在 main.cpp 中)。
 *
 * 用法(VideoTile.qml 中):
 *   ```
 *   Loader {
 *       sourceComponent: streamProtocol === "webrtc" ? webRtcComp : hlsComp
 *       anchors.fill: parent
 *   }
 *   Component {
 *       id: webRtcComp
 *       WebRtcView {
 *           width: 640
 *           height: 360
 *       }
 *   }
 *   ```
 *
 * 子任务 3 完成后,WebRtcView 内部调用:
 *   - setStreamUrl(zlm_webrtc_url) → PeerConnection::start()
 *   - 解码完成后 pushFrame() → 渲染管线自动消费
 */
Item {
    id: root

    // 子任务 3:实际从 StreamingController 拿 URL
    property string streamUrl: ""

    WebRtcRendererItem {
        id: fbo
        anchors.fill: parent
        objectName: "WebRtcRendererItem_" + (root.streamUrl || "default")

        Component.onCompleted: {
            if (root.streamUrl) fbo.setStreamUrl(root.streamUrl)
        }
        Connections {
            target: root
            function onStreamUrlChanged() {
                if (root.streamUrl) fbo.setStreamUrl(root.streamUrl)
            }
        }
    }

    // 调试用 stats(子任务 4 完成后可隐藏)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        color: "#88000000"
        radius: 4
        width: statsText.implicitWidth + 12
        height: statsText.implicitHeight + 6
        visible: fbo.totalProduced > 0
        Text {
            id: statsText
            anchors.centerIn: parent
            color: "#00D4AA"
            font.family: "monospace"
            font.pixelSize: 11
            text: "P:%1 C:%2 D:%3".arg(fbo.totalProduced)
                                            .arg(fbo.totalConsumed)
                                            .arg(fbo.totalDropped)
        }
    }
}
