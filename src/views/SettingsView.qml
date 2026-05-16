// ========================================================================
// SettingsView.qml — 增强版设置 (对标Web端4个Tab)
// 新增: 4个Tab(基本/网络&云端/告警策略/AI模型) | 联动动作配置 | 云端连接
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12
            Text { text: "⚙️ 系统设置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: "设备: ShieldBox Pro (BM1684X)"; font.pixelSize: 11; color: "#4A4D58" }
            Text { text: "固件: v2.3.2"; font.pixelSize: 11; color: "#4A4D58" }
        }
    }

    // ═══ Tab栏 ═══
    TabBar {
        id: tabBar
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 40; background: Rectangle { color: "#141720" }

        TabButton { text: "基本设置"; font.pixelSize: 13
            contentItem: Text { text: parent.text; font.pixelSize: 13; color: tabBar.currentIndex === 0 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: tabBar.currentIndex === 0 ? "#0D0F12" : "transparent"; radius: 4 }
        }
        TabButton { text: "网络 & 云端"; font.pixelSize: 13
            contentItem: Text { text: parent.text; font.pixelSize: 13; color: tabBar.currentIndex === 1 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: tabBar.currentIndex === 1 ? "#0D0F12" : "transparent"; radius: 4 }
        }
        TabButton { text: "告警策略"; font.pixelSize: 13
            contentItem: Text { text: parent.text; font.pixelSize: 13; color: tabBar.currentIndex === 2 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: tabBar.currentIndex === 2 ? "#0D0F12" : "transparent"; radius: 4 }
        }
        TabButton { text: "AI模型"; font.pixelSize: 13
            contentItem: Text { text: parent.text; font.pixelSize: 13; color: tabBar.currentIndex === 3 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: tabBar.currentIndex === 3 ? "#0D0F12" : "transparent"; radius: 4 }
        }
    }

    StackLayout {
        anchors.top: tabBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; currentIndex: tabBar.currentIndex

        // ═══ Tab 1: 基本设置 ═══
        ScrollView { clip: true
            Column {
                width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "🖥️ 系统信息"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 20; rowSpacing: 4; width: parent.width
                    Text { text: "设备型号:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "ShieldBox Pro"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "NPU:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "算能BM1684X (32TOPS)"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "内存:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "8GB DDR4"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "存储:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "128GB eMMC (已用 67GB)"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "固件版本:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "v2.3.2 (A分区)"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "序列号:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: "SBX-2026-0042"; font.pixelSize: 12; color: "#E8E8E8" }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "🕐 时间设置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Row { spacing: 12
                    TextField { text: "2026-05-16"; width: 120; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    TextField { text: "12:00:00"; width: 100; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    ComboBox { width: 120; height: 32; model: ["自动NTP", "手动设置"]; background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "🔊 显示与声音"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Row { spacing: 20; width: parent.width
                    Column { spacing: 4
                        Text { text: "屏幕亮度"; font.pixelSize: 11; color: "#8B8FA3" }
                        Slider { width: 200; from: 10; to: 100; value: 80 }
                    }
                    Column { spacing: 4
                        Text { text: "告警音量"; font.pixelSize: 11; color: "#8B8FA3" }
                        Slider { width: 200; from: 0; to: 100; value: 60 }
                    }
                }
                Row { spacing: 12
                    CheckBox { text: "告警弹窗"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "告警声光"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "自动关闭弹窗(15s)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Button { text: "💾 保存基本设置"; font.pixelSize: 13
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        // ═══ Tab 2: 网络 & 云端 ═══
        ScrollView { clip: true
            Column {
                width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "🌐 网络配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 6; width: parent.width
                    Text { text: "IP模式:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 160; height: 32; model: ["DHCP自动", "静态IP"]; background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "IP地址:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: "192.168.1.100"; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "子网掩码:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: "255.255.255.0"; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "网关:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: "192.168.1.1"; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "DNS:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: "8.8.8.8"; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "☁️ 云端连接"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 6; width: parent.width
                    Text { text: "云端地址:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: "https://api.shieldai.cloud"; width: 260; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "设备令牌:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4
                        TextField { text: "••••••••••••••••"; width: 200; height: 32; echoMode: TextInput.Password; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                        Button { text: "👁"; width: 32; height: 32; background: Rectangle { color: "#252830"; radius: 6 }; contentItem: Text { text: parent.text; color: "#8B8FA3" } }
                    }
                    Text { text: "连接状态:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "已连接 — 心跳正常"; font.pixelSize: 12; color: "#00D4AA" }
                    }
                    Text { text: "MQTT:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "mqtts://emqx.shieldai.cloud:8883"; font.pixelSize: 12; color: "#00D4AA" }
                    }
                }

                Row { spacing: 12
                    CheckBox { text: "告警转发到云端"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "配置同步"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "联邦学习参与"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Button { text: "💾 保存网络设置"; font.pixelSize: 13
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        // ═══ Tab 3: 告警策略 ═══
        ScrollView { clip: true
            Column {
                width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "🚨 告警策略配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "告警去重窗口:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4; SpinBox { from: 1; to: 60; value: 5; height: 32 }; Text { text: "秒"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter } }

                    Text { text: "最小置信度:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 8
                        Slider { width: 180; from: 0.3; to: 0.95; value: 0.5; stepSize: 0.05 }
                        Text { text: (0.5 * 100).toFixed(0) + "%"; font.pixelSize: 12; color: "#E8E8E8"; width: 40 }
                    }

                    Text { text: "严重告警最大延迟:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4; SpinBox { from: 100; to: 5000; value: 500; stepSize: 100; height: 32 }; Text { text: "ms"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter } }

                    Text { text: "自动确认超时:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4; SpinBox { from: 0; to: 60; value: 0; height: 32 }; Text { text: "分钟 (0=不自动)"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "🔗 联动动作"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Column { spacing: 4; width: parent.width
                    CheckBox { text: "📸 自动截图 (告警时)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "📹 3秒预录 (告警前)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "🔊 声光报警 (严重告警)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "☁️ 推送到云端"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "📱 推送到APP"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "🔔 继电器触发 (IO输出)"; checked: false; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "🔊 语音播报 (TTS)"; checked: false; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Button { text: "💾 保存告警策略"; font.pixelSize: 13
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        // ═══ Tab 4: AI模型 ═══
        ScrollView { clip: true
            Column {
                width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "🧠 AI模型配置"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 模型列表
                ListView {
                    width: parent.width; height: 280; spacing: 4; clip: true

                    model: ListModel {
                        ListElement { name: "person_detect_v3.bmodel"; version: "v3.2"; precision: "INT8"; size: "7.8"; inferMs: "12"; slot: 1; active: true }
                        ListElement { name: "perimeter_guard.bmodel"; version: "v2.1"; precision: "INT8"; size: "5.2"; inferMs: "9"; slot: 2; active: true }
                        ListElement { name: "fire_smoke.bmodel"; version: "v1.5"; precision: "FP16"; size: "12.1"; inferMs: "18"; slot: 3; active: true }
                        ListElement { name: "ppe_detect.bmodel"; version: "v2.0"; precision: "INT8"; size: "6.3"; inferMs: "11"; slot: 4; active: false }
                        ListElement { name: "face_recog.bmodel"; version: "v4.0"; precision: "INT8"; size: "15.7"; inferMs: "22"; slot: 5; active: false }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; color: "#0D0F12"; radius: 4
                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 10
                            Rectangle { width: 24; height: 24; radius: 12; color: model.active ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter
                                Text { text: "S" + model.slot; font.pixelSize: 9; color: "#0D0F12"; font.bold: true; anchors.centerIn: parent } }
                            Text { text: model.name; font.pixelSize: 11; color: "#E8E8E8"; width: 180; elide: Text.ElideRight }
                            Text { text: model.precision; font.pixelSize: 10; color: "#6C5CE7"; width: 40 }
                            Text { text: model.size + "MB"; font.pixelSize: 10; color: "#8B8FA3"; width: 50 }
                            Text { text: model.inferMs + "ms"; font.pixelSize: 10; color: "#FFB800"; width: 40 }
                            Button { text: model.active ? "卸载" : "加载"; font.pixelSize: 10
                                background: Rectangle { color: model.active ? "#2A1A1A" : "#1A2A1A"; radius: 4; width: 44; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: model.active ? "#FF6B35" : "#00D4AA"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }

                Button { text: "📤 上传模型"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32; border.color: "#4A4D58"; border.width: 1 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }
}
