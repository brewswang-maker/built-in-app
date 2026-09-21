import QtQuick
// [S3-4 2026-09-20] 修复: WebRtcRendererItem 由 main.cpp qmlRegisterType("ShieldBox",1,0) 注册,
//   本文件此前未 import 该模块(且从未被实例化所以未暴露) — 缺此 import 时
//   WebRtcRendererItem 无法解析, VideoTile 的 webrtc 分支必报运行时错误。
import ShieldBox 1.0

/**
 * @brief WebRtcView
 *
 * 子任务 2 — V4-V1 WebRTC 渲染引擎集成(SmartGateWay v4.0 §4.1)
 *
 * QML 包装 WebRtcRendererItem([P1-1 2026-09-20] 类型已在 main.cpp
 * qmlRegisterType 注册, 本文件已注册 qml.qrc)。
 *
 * [S3-3/S3-4 2026-09-20] 真实通路已接入(替换原"骨架"描述):
 *   - setStreamUrl(webrtc://host:port/index/api/webrtc?app=live&stream=<id>)
 *     → 内部 WebRtcClient WHEP 信令 + RTP 解包 + FFmpeg 软解 → WebRtcFrameSink
 *   - 渲染底座 QQuickPaintedItem(软渲染, GL 不可用设备可用), 33ms 定时器驱动重绘
 *   - 空 URL → fbo.stopStream()(停信令/解码/重绘)
 *   - streamFailed(r) 透传: VideoTile → VideoGridView → reportProtocolFailure 降级
 *
 * 用法(VideoTile.qml 中, S3-4 已实现):
 *   ```
 *   WebRtcView {
 *       anchors.fill: parent
 *       visible: root.isWebRtcUrl
 *       streamUrl: root.isWebRtcUrl ? root.streamUrl : ""
 *   }
 *   ```
 */
Item {
    id: root

    property string streamUrl: ""

    // [S3-4 2026-09-20] 事件透传: 渲染器 → 上层(降级链/首帧取证)
    signal streamFailed(string reason)
    signal firstFrameRendered()

    WebRtcRendererItem {
        id: fbo
        anchors.fill: parent
        objectName: "WebRtcRendererItem_" + (root.streamUrl || "default")

        function applyUrl() {
            if (root.streamUrl && root.streamUrl.length > 0)
                fbo.setStreamUrl(root.streamUrl)
            else
                fbo.stopStream() // [S3-4] 清空 URL 必须停机(旧实现会继续收流)
        }

        Component.onCompleted: applyUrl()
        Connections {
            target: root
            function onStreamUrlChanged() { fbo.applyUrl() }
        }
        onStreamFailed: function(reason) { root.streamFailed(reason) }
        onFirstFrameRendered: root.firstFrameRendered()
    }

    // 调试用 stats(真机取证锚点: P=入池 C=消费 D=丢弃 Dc=解码)
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
            text: "P:%1 C:%2 D:%3 Dc:%4".arg(fbo.totalProduced)
                                            .arg(fbo.totalConsumed)
                                            .arg(fbo.totalDropped)
                                            .arg(fbo.totalDecoded)
        }
    }
}
