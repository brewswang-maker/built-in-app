// ========================================================================
// OTAUpgradeView.qml — 系统升级 (OTA + 本地包 + 固件 + 回滚)
// 超越Web端: A/B分区切换、升级进度条、失败自动回滚
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: otaView

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "🔄 系统升级"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Button {
                text: "🔍 检查更新"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "📁 本地升级"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 当前版本信息 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 320
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 12

                Text { text: "📋 版本信息"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 8; width: parent.width - 32

                    Text { text: "系统版本:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "v2.1.0 (build 2026051601)"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "内核版本:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "5.15.0-bm1684x"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "TPU固件:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "SophonSDK v0.8.0"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "AI算法包:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "v1.5.0 (23个模型)"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "Web管理台:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "v2.1.0"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "发布日期:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "2026-05-16"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "活跃分区:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "A (可回滚到B)"; font.pixelSize: 12; color: "#00D4AA" }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 32 }

                // 可用更新
                Text { text: "🆕 可用更新"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Rectangle {
                    width: parent.width - 32; height: 120; color: "#0D0F12"; radius: 8
                    border.color: "#3B82F6"; border.width: 1

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: "v2.2.0 (2026-05-20)"; font.pixelSize: 13; font.bold: true; color: "#3B82F6" }
                        Text { text: "• 新增EHOME协议支持"; font.pixelSize: 11; color: "#E8E8E8" }
                        Text { text: "• 优化TPU推理性能(提升15%)"; font.pixelSize: 11; color: "#E8E8E8" }
                        Text { text: "• 修复GB28181级联心跳问题"; font.pixelSize: 11; color: "#E8E8E8" }
                        Text { text: "• 更新安全帽检测模型(精度+3%)"; font.pixelSize: 11; color: "#E8E8E8" }
                        Text { text: "大小: 45.2MB"; font.pixelSize: 11; color: "#8B8FA3" }
                    }
                }

                Row {
                    spacing: 8
                    Button {
                        text: "⬇️ 下载并安装"
                        background: Rectangle { color: "#00D4AA"; radius: 6; width: 140; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "仅下载"
                        background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }

        // ── 右侧: 升级历史 + 模型管理 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📜 升级历史"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4

                    model: ListModel {
                        ListElement { version: "v2.1.0"; date: "2026-05-16"; status: "当前"; size: "52.1MB"; partition: "A" }
                        ListElement { version: "v2.0.0"; date: "2026-05-01"; status: "可回滚"; size: "48.3MB"; partition: "B" }
                        ListElement { version: "v1.9.0"; date: "2026-04-15"; status: "已归档"; size: "45.0MB"; partition: "-" }
                        ListElement { version: "v1.8.0"; date: "2026-04-01"; status: "已归档"; size: "43.2MB"; partition: "-" }
                        ListElement { version: "v1.7.0"; date: "2026-03-15"; status: "已归档"; size: "41.8MB"; partition: "-" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#141720"; radius: 6

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            Text { text: model.version; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; width: 60 }
                            Text { text: model.date; font.pixelSize: 11; color: "#8B8FA3"; width: 80 }
                            Text { text: model.size; font.pixelSize: 11; color: "#8B8FA3"; width: 50 }
                            Text { text: "分区:" + model.partition; font.pixelSize: 11; color: "#8B8FA3"; width: 50 }

                            Rectangle {
                                width: 60; height: 20; radius: 4
                                color: model.status === "当前" ? "#0A2A1A" :
                                       model.status === "可回滚" ? "#2A2A0A" : "#141720"
                                Text {
                                    text: model.status
                                    font.pixelSize: 10; font.bold: true
                                    color: model.status === "当前" ? "#00D4AA" :
                                           model.status === "可回滚" ? "#FFB800" : "#4A4D58"
                                    anchors.centerIn: parent
                                }
                            }

                            Button {
                                text: "回滚"; font.pixelSize: 10
                                visible: model.status === "可回滚"
                                background: Rectangle { color: "#FFB800"; radius: 4; width: 40; height: 20 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
