import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        ColumnLayout {
            width: settingsPage.width - 32
            spacing: 16

            Text {
                text: "⚙️ 系统设置"
                font.pixelSize: 20
                font.bold: true
                color: "#E8E8E8"
            }

            // ── System Info ──
            Rectangle {
                Layout.fillWidth: true
                height: 140
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    Text { text: "系统信息"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Text { text: "固件版本: v1.0.0"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "序列号: SBX-2025-00001"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "运行时间: " + statusController.uptime; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "网络状态: " + statusController.networkStatus; font.pixelSize: 12; color: "#00D4AA" }
                }
            }

            // ── Network Config ──
            Rectangle {
                Layout.fillWidth: true
                height: 200
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text { text: "网络配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    GridLayout {
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        Text { text: "IP 地址:"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "192.168.1.100"
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }

                        Text { text: "网关:"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "192.168.1.1"
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }

                        Text { text: "DNS:"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "8.8.8.8"
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }
                    }

                    Button {
                        text: "保存网络配置"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignRight
                        onClicked: configController.setNetworkConfig({})
                        background: Rectangle { color: "#00D4AA"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: parent.font.pixelSize; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            // ── Storage ──
            Rectangle {
                Layout.fillWidth: true
                height: 120
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text { text: "存储管理"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    ProgressBar {
                        Layout.fillWidth: true
                        value: 0.65
                        from: 0
                        to: 1
                        background: Rectangle { color: "#252830"; radius: 4; height: 12 }
                        contentItem: Rectangle {
                            width: parent.visualPosition * parent.width
                            height: 12
                            radius: 4
                            color: parent.value > 0.9 ? "#FF3D71" : "#00D4AA"
                        }
                    }
                    Text { text: "已使用 65% (130GB / 200GB)"; font.pixelSize: 12; color: "#8B8FA3" }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "录像保留天数:"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { from: 7; to: 90; value: 30 }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "清理"
                            font.pixelSize: 12
                            background: Rectangle { color: "#FF6B35"; radius: 6 }
                            contentItem: Text { text: parent.text; font.pixelSize: parent.font.pixelSize; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            // ── OTA Upgrade ──
            Rectangle {
                Layout.fillWidth: true
                height: 100
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text { text: "系统升级"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "当前版本: v1.0.0"; font.pixelSize: 12; color: "#8B8FA3" }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "检查更新"
                            font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 6 }
                            contentItem: Text { text: parent.text; font.pixelSize: parent.font.pixelSize; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            // ── Alarm Notification ──
            Rectangle {
                Layout.fillWidth: true
                height: 140
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text { text: "告警通知设置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    RowLayout {
                        Text { text: "告警声音"; font.pixelSize: 12; color: "#E8E8E8"; Layout.preferredWidth: 100 }
                        Switch { checked: true }
                    }
                    RowLayout {
                        Text { text: "弹窗通知"; font.pixelSize: 12; color: "#E8E8E8"; Layout.preferredWidth: 100 }
                        Switch { checked: true }
                    }
                    RowLayout {
                        Text { text: "声光联动"; font.pixelSize: 12; color: "#E8E8E8"; Layout.preferredWidth: 100 }
                        Switch { checked: false }
                    }
                }
            }

            // ── Model Management ──
            Rectangle {
                Layout.fillWidth: true
                height: 100
                color: "#1A1D23"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text { text: "模型管理 (" + statusController.activeModels + " 已加载)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "TPU 利用率: " + statusController.tpuUtilization.toFixed(1) + "%"; font.pixelSize: 12; color: "#00D4AA" }
                        Text { text: "显存: " + statusController.tpuMemoryUsed + "MB"; font.pixelSize: 12; color: "#8B8FA3" }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "上传模型"
                            font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 6 }
                            contentItem: Text { text: parent.text; font.pixelSize: parent.font.pixelSize; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        configController.loadConfig()
        configController.getNetworkConfig()
    }
}
