// ========================================================================
// ChannelView.qml — 通道管理 (码流配置 + 通道映射 + 多画面轮巡)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: channelView

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "📡 通道管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Button { text: "➕ 新建轮巡"; font.pixelSize: 12; background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "⚙️ 批量配置"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 设备-通道树 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 260
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "设备通道树"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                TreeView {  // 简化为ListView模拟
                    width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 2

                    model: ListModel {
                        ListElement { name: "📹 海康IPC-01"; indent: 0; isDevice: true; online: true }
                        ListElement { name: "CH1 主码流 (4K@25fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "CH2 子码流 (1080P@15fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "📹 大华IPC-02"; indent: 0; isDevice: true; online: true }
                        ListElement { name: "CH1 主码流 (2K@25fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "📹 宇视NVR-01"; indent: 0; isDevice: true; online: true }
                        ListElement { name: "CH1 (4K@25fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "CH2 (1080P@15fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "CH3 (1080P@25fps)"; indent: 1; isDevice: false; online: true }
                        ListElement { name: "CH4-CH16 (离线)"; indent: 1; isDevice: false; online: false }
                        ListElement { name: "📹 华为IPC-05"; indent: 0; isDevice: true; online: false }
                        ListElement { name: "CH1 (离线)"; indent: 1; isDevice: false; online: false }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 28; color: chMouse.containsMouse ? "#1A1D23" : "transparent"
                        Row {
                            x: model.indent * 16; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            Text { text: model.isDevice ? (model.online ? "📹" : "📹") : "•"; font.pixelSize: model.isDevice ? 12 : 8; color: model.online ? "#00D4AA" : "#FF3D71" }
                            Text { text: model.name; font.pixelSize: model.isDevice ? 12 : 11; color: model.online ? "#E8E8E8" : "#4A4D58"; font.bold: model.isDevice }
                        }
                        MouseArea { id: chMouse; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }

        // ── 右侧: 通道配置 + 轮巡 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "通道配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 通道配置表单
                Rectangle {
                    width: parent.width - 24; height: 200; color: "#141720"; radius: 8
                    Grid {
                        anchors.fill: parent; anchors.margins: 16
                        columns: 4; spacing: 12; rowSpacing: 10

                        Text { text: "通道名称:"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { text: "CH1 — 海康IPC-01主码流"; width: 200; font.pixelSize: 12; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }

                        Text { text: "启用:"; font.pixelSize: 12; color: "#8B8FA3" }
                        Switch { checked: true }

                        Text { text: "码流类型:"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { width: 160; model: ["主码流","子码流","三码流"]; background: Rectangle { color: "#252830"; radius: 4 } }

                        Text { text: "编码格式:"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { width: 160; model: ["H.265","H.264","MJPEG"]; background: Rectangle { color: "#252830"; radius: 4 } }

                        Text { text: "分辨率:"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { width: 160; model: ["3840x2160","2560x1440","1920x1080","1280x720"]; background: Rectangle { color: "#252830"; radius: 4 } }

                        Text { text: "帧率:"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { from: 1; to: 30; value: 25 }

                        Text { text: "码率(Kbps):"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { from: 256; to: 16384; value: 6144; stepSize: 512 }
                    }
                }

                // 轮巡方案
                Text { text: "轮巡方案"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8"; topPadding: 8 }

                ListView {
                    width: parent.width - 24; height: parent.height - 300; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { name: "默认轮巡 (全部通道)"; interval: "10秒"; layout: "4宫格"; channels: "12"; active: true }
                        ListElement { name: "重点区域轮巡"; interval: "5秒"; layout: "1宫格"; channels: "4"; active: false }
                        ListElement { name: "停车场夜间"; interval: "15秒"; layout: "4宫格"; channels: "6"; active: false }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#141720"; radius: 6
                        Row {
                            anchors.fill: parent; anchors.margins: 8; spacing: 12
                            Rectangle { width: 6; height: 6; radius: 3; color: model.active ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: model.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; width: 180 }
                            Text { text: "间隔:" + model.interval; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: model.layout; font.pixelSize: 11; color: "#3B82F6" }
                            Text { text: model.channels + "通道"; font.pixelSize: 11; color: "#8B8FA3" }
                            Item { width: 20 }
                            Button { text: model.active ? "⏹ 停止" : "▶ 启动"; font.pixelSize: 10; background: Rectangle { color: model.active ? "#FF3D71" : "#00D4AA"; radius: 4; width: 52; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: model.active ? "#FFF" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "编辑"; font.pixelSize: 10; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
            }
        }
    }
}
