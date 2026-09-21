// =============================================================================
// [S3-4/S3-5 2026-09-20] probe.qml — 设备端 QML 模式探针根组件
//
// 用途: webrtc_render_probe --qml 模式下由 QQmlApplicationEngine 加载,
//   实例化真实 src/qml/WebRtcView.qml(经 probe.qrc 同根映射), 验证 S3-4
//   接线层(setStreamUrl → WebRtcClient.start)在真机 QML 环境可加载可播放。
//
// streamUrl 由 C++ 侧 context property "probeUrl" 注入(启动参数)。
// 帧统计/截图/退出逻辑均在 C++ 探针中轮询 WebRtcRendererItem 完成。
// =============================================================================
import QtQuick

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "webrtc_render_probe"

    // [S3-4] 真实 WebRtcView.qml(probe.qrc 同根 alias); streamUrl 来自 C++ context
    WebRtcView {
        anchors.fill: parent
        streamUrl: typeof probeUrl !== "undefined" ? probeUrl : ""
    }
}
