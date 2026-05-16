// ========================================================================
// SettingsView.qml — 系统设置 (基本/网络/告警策略/AI模型 4Tab)
// Controller: configController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsView

    property int currentTab: 0

    Component.onCompleted: {
        configController.loadConfig()
        configController.getNetworkConfig()
        configController.getAlgorithmList()
    }

    Connections {
        target: configController
        function onConfigUpdated() {
            // 配置已更新 — UI绑定自动刷新
        }
        function onNetworkConfigUpdated() {
            ipField.text = configController.networkConfig.ip || ""
            subnetField.text = configController.networkConfig.subnet || ""
            gatewayField.text = configController.networkConfig.gateway || ""
            dnsField.text = configController.networkConfig.dns || ""
        }
        function onAlgorithmListUpdated() {
            aiModelList.model = configController.algorithmList
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "⚙️ 系统设置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            // Tab切换
            Row {
                spacing: 2
                Repeater {
                    model: ["基本", "网络", "告警策略", "AI模型"]
                    delegate: Button {
                        text: modelData; font.pixelSize: 11
                        background: Rectangle { color: settingsView.currentTab === index ? "#3B82F6" : "#252830"; radius: 6; width: 70; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: settingsView.currentTab === index ? "#FFF" : "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: settingsView.currentTab = index
                    }
                }
            }

            Button {
                text: "📥 导入"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: configController.importConfig("")
            }
            Button {
                text: "📤 导出"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: configController.exportConfig()
            }
        }
    }

    // ── Tab内容 ──
    StackLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 12; currentIndex: settingsView.currentTab

        // ═══ Tab 0: 基本设置 ═══
        Rectangle {
            color: "#0D0F12"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 16; clip: true

                Column {
                    width: parent.width - 32; spacing: 14

                    Text { text: "基本设置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

                    // 设备名
                    Column { spacing: 4; width: parent.width
                        Text { text: "设备名称"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            id: deviceNameField
                            width: parent.width; height: 36
                            text: configController.config.deviceName || "ShieldBox-AI-01"
                            placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }
                    }

                    // 时区
                    Column { spacing: 4; width: parent.width
                        Text { text: "时区"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox {
                            id: timezoneCombo
                            width: parent.width; height: 36
                            model: ["Asia/Shanghai (UTC+8)", "Asia/Tokyo (UTC+9)", "America/New_York (UTC-5)", "Europe/London (UTC+0)"]
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }
                    }

                    // 语言
                    Column { spacing: 4; width: parent.width
                        Text { text: "语言"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox {
                            id: langCombo
                            width: parent.width; height: 36
                            model: ["简体中文", "English", "日本語"]
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }
                    }

                    // NTP服务器
                    Column { spacing: 4; width: parent.width
                        Text { text: "NTP服务器"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            id: ntpField
                            width: parent.width; height: 36
                            text: configController.config.ntpServer || "ntp.aliyun.com"
                            placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 6 }
                        }
                    }

                    // 自动重启
                    Row {
                        spacing: 12
                        CheckBox {
                            id: autoReboot
                            text: "每日自动重启"
                            checked: configController.config.autoReboot || false
                        }
                        SpinBox { from: 0; to: 23; value: 3; enabled: autoReboot.checked }
                        Text { text: "时"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 日志级别
                    Column { spacing: 4; width: parent.width
                        Text { text: "日志级别"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { width: parent.width; model: ["DEBUG", "INFO", "WARN", "ERROR"]; background: Rectangle { color: "#252830"; radius: 6 } }
                    }

                    // 保存按钮
                    Button {
                        text: "💾 保存基本设置"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 180; height: 40 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            configController.saveConfig("deviceName", deviceNameField.text)
                            configController.saveConfig("timezone", timezoneCombo.currentText)
                            configController.saveConfig("language", langCombo.currentText)
                            configController.saveConfig("ntpServer", ntpField.text)
                            configController.saveConfig("autoReboot", autoReboot.checked)
                        }
                    }
                }
            }
        }

        // ═══ Tab 1: 网络设置 ═══
        Rectangle {
            color: "#0D0F12"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 16; clip: true

                Column {
                    width: parent.width - 32; spacing: 14

                    Text { text: "网络设置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 4; width: parent.width
                        Text { text: "IP地址"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { id: ipField; width: parent.width; height: 36; text: configController.networkConfig.ip || "192.168.1.200"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }
                    Column { spacing: 4; width: parent.width
                        Text { text: "子网掩码"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { id: subnetField; width: parent.width; height: 36; text: configController.networkConfig.subnet || "255.255.255.0"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }
                    Column { spacing: 4; width: parent.width
                        Text { text: "网关"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { id: gatewayField; width: parent.width; height: 36; text: configController.networkConfig.gateway || "192.168.1.1"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }
                    Column { spacing: 4; width: parent.width
                        Text { text: "DNS服务器"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { id: dnsField; width: parent.width; height: 36; text: configController.networkConfig.dns || "8.8.8.8"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }

                    Row {
                        spacing: 12
                        Text { text: "DHCP:"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                        Switch { id: dhcpSwitch; checked: false }
                    }

                    Column { spacing: 4; width: parent.width
                        Text { text: "VLAN ID (可选)"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { width: parent.width; height: 36; placeholderText: "留空表示不使用VLAN"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }

                    Column { spacing: 4; width: parent.width
                        Text { text: "API端口"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField { id: apiPortField; width: parent.width; height: 36; text: "8080"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    }

                    Button {
                        text: "💾 保存网络设置"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 180; height: 40 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            configController.setNetworkConfig({
                                ip: ipField.text, subnet: subnetField.text,
                                gateway: gatewayField.text, dns: dnsField.text,
                                dhcp: dhcpSwitch.checked, port: apiPortField.text
                            })
                        }
                    }
                }
            }
        }

        // ═══ Tab 2: 告警策略 ═══
        Rectangle {
            color: "#0D0F12"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 16; clip: true

                Column {
                    width: parent.width - 32; spacing: 14

                    Text { text: "告警策略"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

                    // 灵敏度
                    Column { spacing: 4; width: parent.width
                        Text { text: "检测灵敏度: " + sensitivitySlider.value + "%"; font.pixelSize: 12; color: "#E8E8E8" }
                        Slider { id: sensitivitySlider; width: parent.width; from: 10; to: 100; value: configController.config.sensitivity || 70; stepSize: 5 }
                    }

                    // 静默期
                    Column { spacing: 4; width: parent.width
                        Text { text: "告警静默期 (秒)"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { from: 5; to: 300; value: configController.config.silencePeriod || 30; stepSize: 5 }
                    }

                    // 自动确认
                    Row { spacing: 12
                        CheckBox { text: "低级别告警自动确认 (30分钟后)"; checked: configController.config.autoConfirm || false }
                    }
                    Row { spacing: 12
                        CheckBox { text: "AI判定误报自动静音"; checked: configController.config.autoMuteFalseAlarm || true }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    // 通知渠道
                    Text { text: "通知渠道"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Row { spacing: 16
                        CheckBox { text: "本地弹窗"; checked: true }
                        CheckBox { text: "语音播报"; checked: true }
                    }
                    Row { spacing: 16
                        CheckBox { text: "手机推送"; checked: false }
                        CheckBox { text: "短信通知"; checked: false }
                    }
                    Row { spacing: 16
                        CheckBox { text: "邮件通知"; checked: false }
                        CheckBox { text: "WebHook"; checked: false }
                    }

                    // 联动动作
                    Rectangle { height: 1; color: "#252830"; width: parent.width }
                    Text { text: "默认联动动作"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Row { spacing: 16
                        CheckBox { text: "触发录像"; checked: true }
                        CheckBox { text: "自动截图"; checked: true }
                    }
                    Row { spacing: 16
                        CheckBox { text: "声光报警"; checked: false }
                        CheckBox { text: "电视墙弹出"; checked: false }
                    }

                    Button {
                        text: "💾 保存告警策略"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 180; height: 40 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            configController.saveConfig("sensitivity", sensitivitySlider.value)
                            configController.saveConfig("silencePeriod", 30)
                        }
                    }
                }
            }
        }

        // ═══ Tab 3: AI模型 ═══
        Rectangle {
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 8

                Row {
                    spacing: 12
                    Text { text: "AI模型配置"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Text { text: configController.algorithmList.length + " 个已加载"; font.pixelSize: 11; color: "#8B8FA3" }
                }

                ListView {
                    id: aiModelList
                    width: parent.width; height: parent.height - 50; clip: true; spacing: 6
                    model: configController.algorithmList

                    delegate: Rectangle {
                        width: ListView.view.width; height: 56; color: "#141720"; radius: 6
                        property var mData: modelData || model

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            Text { text: "🧠"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                            Column { spacing: 2; width: 160
                                Text { text: mData.name || "模型"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                Text { text: (mData.precision || "INT8") + " | " + (mData.fps || 0) + " FPS"; font.pixelSize: 10; color: "#8B8FA3" }
                            }
                            Column { spacing: 2
                                Text { text: "灵敏度:"; font.pixelSize: 10; color: "#8B8FA3" }
                                Slider { width: 120; from: 10; to: 100; value: mData.sensitivity || 70; stepSize: 5
                                    onMoved: configController.configureAlgorithm(mData.id, { sensitivity: value })
                                }
                            }
                            Column { spacing: 2
                                Text { text: "最小置信度:"; font.pixelSize: 10; color: "#8B8FA3" }
                                Slider { width: 120; from: 10; to: 100; value: mData.minConfidence || 50; stepSize: 5
                                    onMoved: configController.configureAlgorithm(mData.id, { minConfidence: value })
                                }
                            }
                            Switch {
                                checked: mData.enabled !== false
                                onToggled: configController.configureAlgorithm(mData.id, { enabled: checked })
                            }
                        }
                    }
                }
            }
        }
    }
}
