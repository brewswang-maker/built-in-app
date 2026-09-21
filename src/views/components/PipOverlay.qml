// ========================================================================
// PipOverlay.qml — 画中画悬浮小窗 [P0-2a 2026-09-20]
//
// 差异化扩展 (Web 端无对应功能, 对齐 EZView/快球客户端惯例):
//   在网格之外叠加一路独立播放小窗, 供"主看大画面 + 角落盯细节"场景
// Controller 已就绪 (MediaController.h:31-34/102-103):
//   pipChannelId (进入/退出) · pipOpacity (0~1, 默认 0.85) · enterPip/exitPip/setPipOpacity
// 交互: 顶部条拖拽移动 + 底部滑杆调透明度 (0.3~1.0) + 右上角关闭
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: pip

    // 可见性由 Controller 状态驱动 (enterPip 置非空 / exitPip 清空)
    visible: mediaController.pipChannelId !== ""

    width: 340; height: 232
    // 初始位置: 宿主右下角; 拖拽后由 drag 逻辑接管 x/y (绑定自动解除)
    x: parent ? Math.max(0, parent.width - width - 24) : 12
    y: parent ? Math.max(0, parent.height - height - 24) : 12

    // 流地址: 读取 streamUrls 属性建立依赖 (streamUrlsUpdated → 重算),
    //   与网格瓦片同源同键 (deviceId), 降级链切换后随 map 更新
    readonly property string pipUrl: {
        var id = mediaController.pipChannelId
        if (id === "") return ""
        var u = mediaController.streamUrls[id]
        return u !== undefined ? String(u) : ""
    }

    // 标题: 从设备列表匹配通道名 (匹配不到时回显 id)
    readonly property string pipTitle: {
        var id = mediaController.pipChannelId
        for (var i = 0; i < deviceController.devices.length; i++) {
            var d = deviceController.devices[i]
            if ((d.id || d.device_id || "") === id)
                return d.name || d.device_name || id
        }
        return id
    }

    // 透明度直接作用整个小窗 (Controller 侧已做 0~1 clamp)
    opacity: mediaController.pipOpacity

    Rectangle {
        id: frame
        anchors.fill: parent
        color: "#0D0F12"; radius: 8
        border.color: "#409EFF"; border.width: 1
        clip: true

        // ── 独立播放器 (与网格瓦片实例无关, 第二路解码) ──
        MediaPlayer {
            id: pipPlayer
            // 退出画中画时清空 source 释放解码资源
            source: pip.visible ? pip.pipUrl : ""
            videoOutput: pipOutput
            autoPlay: true
            onErrorOccurred: function(error, errorString) {
                console.warn("[PipOverlay] MediaPlayer ERROR:", error, errorString)
            }
        }
        VideoOutput {
            id: pipOutput
            anchors.fill: parent
            visible: pip.pipUrl.length > 0
        }

        // 空流提示 (如实呈现, 不造假画面)
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: pip.pipUrl.length === 0
            AppIcon {
                name: "camera"; size: 28; iconColor: "#8c8c8c"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "该通道暂无流地址\n请先在网格中预览后开启"
                color: "#8c8c8c"; font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ── 顶部控制条: 拖拽把柄 + 标题 + 关闭 ──
        //   (frame clip 负责顶部圆角裁剪, 顶部条不单独设 radius)
        Rectangle {
            id: topBar
            width: parent.width; height: 28
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: pip
                drag.minimumX: 0
                drag.maximumX: pip.parent ? Math.max(0, pip.parent.width - pip.width) : 0
                drag.minimumY: 0
                drag.maximumY: pip.parent ? Math.max(0, pip.parent.height - pip.height) : 0
            }
            Text {
                text: "画中画 · " + pip.pipTitle
                color: "#FFFFFF"; font.pixelSize: 12
                elide: Text.ElideRight
                width: Math.min(implicitWidth, topBar.width - 48)
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }
            // 声明在拖拽层之后 → 处于更上层, 可正常点击
            Text {
                id: closeBtn
                text: "✕"
                color: closeArea.containsMouse ? "#F56C6C" : "#FFFFFF"
                font.pixelSize: 13
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: closeArea
                    anchors.fill: parent; anchors.margins: -8
                    hoverEnabled: true
                    onClicked: mediaController.exitPip()
                }
            }
        }

        // ── 底部控制条: 透明度 (0.3~1.0, 写回 Controller) ──
        Rectangle {
            id: bottomBar
            width: parent.width; height: 30
            anchors.bottom: parent.bottom
            color: Qt.rgba(0, 0, 0, 0.45)

            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6

                Text {
                    text: "透明度"; color: "#DDDDDD"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    id: opacitySlider
                    width: parent.width - 108
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0.3; to: 1.0; stepSize: 0.05
                    value: mediaController.pipOpacity
                    onMoved: mediaController.setPipOpacity(value)
                }
                Text {
                    text: Math.round(mediaController.pipOpacity * 100) + "%"
                    color: "#DDDDDD"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
