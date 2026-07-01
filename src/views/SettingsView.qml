// ========================================================================
// SettingsView.qml — 系统设置 (4 Tab)
// 接入 configController — box-sdk REST API
// 功能: 基本/网络/告警策略/AI模型 Tab + 导入导出配置
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage

    property string statusMsg: ""
    property real alertSensitivity: 0.5
    property int alertSilencePeriod: 5
    property bool alertAutoConfirm: false
    property bool alertScreenshot: true
    property bool alertPreRecord: true
    property bool alertSoundLight: true
    property bool alertCloudPush: true
    property bool alertAppPush: true
    property bool alertRelay: false
    property bool alertTTS: false

    // Form fields bound to configController.config
    property string cfgDeviceName: ""
    property string cfgTimezone: "Asia/Shanghai"
    property string cfgLanguage: "zh-CN"
    property string cfgNtpServer: "ntp.aliyun.com"
    property string cfgIp: ""
    property string cfgSubnet: ""
    property string cfgGateway: ""
    property string cfgDns: ""
    property string cfgVlan: ""

    Component.onCompleted: {
        configController.loadConfig()
        configController.getNetworkConfig()
    }

    Connections {
        target: configController
        function onConfigUpdated() {
            var c = configController.config
            cfgDeviceName = c.deviceName || ""
            cfgTimezone = c.timezone || "Asia/Shanghai"
            cfgLanguage = c.language || "zh-CN"
            cfgNtpServer = c.ntpServer || "ntp.aliyun.com"
            alertSensitivity = c.alertSensitivity || 0.5
            alertSilencePeriod = c.alertSilencePeriod || 5
            alertAutoConfirm = c.alertAutoConfirm || false
        }
        function onNetworkConfigUpdated() {
            var nc = configController.networkConfig
            cfgIp = nc.ip || ""
            cfgSubnet = nc.subnet || ""
            cfgGateway = nc.gateway || ""
            cfgDns = nc.dns || ""
            cfgVlan = nc.vlan || ""
        }
        function onConfigSaved() { statusMsg = "Config saved"; statusTimer.start() }
        function onErrorOccurred(code, message) { statusMsg = "Error: " + message; statusTimer.start() }
    }

    Timer { id: statusTimer; interval: 3000; onTriggered: statusMsg = "" }

    // ═══ Header ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12
            Text { text: "Settings"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: statusMsg; font.pixelSize: 11; color: "#FFB800"; visible: statusMsg !== "" }

            Button { text: "Export"; font.pixelSize: 12; onClicked: configController.exportConfig()
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "Import"; font.pixelSize: 12; onClicked: configController.importConfig("")
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    // ═══ Tab Bar ═══
    TabBar {
        id: tabBar
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 40; background: Rectangle { color: "#141720" }

        Repeater {
            model: ["General", "Network", "Alert Policy", "AI Models"]
            delegate: TabButton {
                text: modelData; font.pixelSize: 13
                contentItem: Text { text: parent.text; font.pixelSize: 13; color: tabBar.currentIndex === index ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: tabBar.currentIndex === index ? "#0D0F12" : "transparent"; radius: 4 }
            }
        }
    }

    // ═══ Content ═══
    StackLayout {
        anchors.top: tabBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; currentIndex: tabBar.currentIndex

        // ── Tab 0: General ──
        ScrollView { clip: true
            Column { width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "System Info"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 20; rowSpacing: 4; width: parent.width
                    Text { text: "Model:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.deviceModel || "ShieldBox Pro"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "NPU:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.npuModel || "BM1684X (32TOPS)"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Memory:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.memory || "8GB DDR4"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Storage:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.storage || "128GB eMMC"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Firmware:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.firmwareVersion || "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Serial:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.serialNumber || "-"; font.pixelSize: 12; color: "#E8E8E8" }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "General Settings"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "Device Name:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgDeviceName; onTextChanged: cfgDeviceName = text; width: 240; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

                    Text { text: "Timezone:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 240; height: 32; model: ["Asia/Shanghai", "UTC", "America/New_York", "Europe/London", "Asia/Tokyo"]; currentIndex: model.indexOf(cfgTimezone)
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                    Text { text: "Language:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 240; height: 32; model: ["zh-CN", "en-US", "ja-JP"]; currentIndex: model.indexOf(cfgLanguage)
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                    Text { text: "NTP Server:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgNtpServer; onTextChanged: cfgNtpServer = text; width: 240; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                }

                Button { text: "Save General"; font.pixelSize: 13
                    onClicked: {
                        configController.saveConfig("deviceName", cfgDeviceName)
                        configController.saveConfig("timezone", cfgTimezone)
                        configController.saveConfig("language", cfgLanguage)
                        configController.saveConfig("ntpServer", cfgNtpServer)
                    }
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "Display & Sound"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Row { spacing: 20; width: parent.width
                    Column { spacing: 4
                        Text { text: "Screen Brightness"; font.pixelSize: 11; color: "#8B8FA3" }
                        Slider { width: 200; from: 10; to: 100; value: configController.config.screenBrightness || 80; onValueChanged: configController.saveConfig("screenBrightness", value) }
                    }
                    Column { spacing: 4
                        Text { text: "Alert Volume"; font.pixelSize: 11; color: "#8B8FA3" }
                        Slider { width: 200; from: 0; to: 100; value: configController.config.alertVolume || 60; onValueChanged: configController.saveConfig("alertVolume", value) }
                    }
                }
                Row { spacing: 12
                    CheckBox { text: "Alert Popup"; checked: configController.config.alertPopup !== false; onCheckedChanged: configController.saveConfig("alertPopup", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Sound & Light"; checked: configController.config.alertSoundLight !== false; onCheckedChanged: configController.saveConfig("alertSoundLight", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Auto-dismiss (15s)"; checked: configController.config.autoDismiss === true; onCheckedChanged: configController.saveConfig("autoDismiss", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "System Maintenance"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Row { spacing: 12
                    Button { text: "Restart Service"; font.pixelSize: 12
                        onClicked: { configController.saveConfig("_action", "restartService"); statusMsg = "Restarting service..."; statusTimer.start() }
                        background: Rectangle { color: "#FFB800"; radius: 6; width: 110; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Factory Reset"; font.pixelSize: 12
                        onClicked: { configController.saveConfig("_action", "factoryReset"); statusMsg = "Factory reset initiated"; statusTimer.start() }
                        background: Rectangle { color: "#FF3D71"; radius: 6; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Reboot Device"; font.pixelSize: 12
                        onClicked: { configController.saveConfig("_action", "reboot"); statusMsg = "Rebooting..."; statusTimer.start() }
                        background: Rectangle { color: "#FF3D71"; radius: 6; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }

        // ── Tab 1: Network ──
        ScrollView { clip: true
            Column { width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "Network Config"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 6; width: parent.width
                    Text { text: "IP Mode:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 200; height: 32; model: ["DHCP", "Static IP"]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "IP Address:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgIp; onTextChanged: cfgIp = text; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "Subnet Mask:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgSubnet; onTextChanged: cfgSubnet = text; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "Gateway:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgGateway; onTextChanged: cfgGateway = text; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "DNS:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgDns; onTextChanged: cfgDns = text; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "VLAN:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: cfgVlan; onTextChanged: cfgVlan = text; width: 200; height: 32; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "Cloud Connection"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 6; width: parent.width
                    Text { text: "Cloud URL:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.cloudUrl || "-"; font.pixelSize: 12; color: "#3B82F6" }
                    Text { text: "Status:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: configController.config.cloudConnected ? "Connected" : "Disconnected"; font.pixelSize: 12; color: configController.config.cloudConnected ? "#00D4AA" : "#FF3D71" }
                    }
                    Text { text: "MQTT:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: configController.config.mqttBroker || "-"; font.pixelSize: 12; color: "#00D4AA" }
                }

                Button { text: "Save Network"; font.pixelSize: 13
                    onClicked: configController.setNetworkConfig({ "ip": cfgIp, "subnet": cfgSubnet, "gateway": cfgGateway, "dns": cfgDns, "vlan": cfgVlan })
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }
        }

        // ── Tab 2: Alert Policy ──
        ScrollView { clip: true
            Column { width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "Alert Policy"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "Sensitivity:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 8
                        Slider { width: 180; from: 0.3; to: 0.95; value: alertSensitivity; stepSize: 0.05; onValueChanged: alertSensitivity = value }
                        Text { text: (alertSensitivity * 100).toFixed(0) + "%"; font.pixelSize: 12; color: "#E8E8E8"; width: 40 }
                    }

                    Text { text: "Silence Period:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4
                        SpinBox { from: 1; to: 60; value: alertSilencePeriod; onValueChanged: alertSilencePeriod = value; height: 32 }
                        Text { text: "seconds"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Text { text: "Auto Confirm:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row { spacing: 4
                        SpinBox { from: 0; to: 60; value: 0; height: 32 }
                        Text { text: "min (0=disabled)"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "Linkage Actions"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Column { spacing: 4; width: parent.width
                    CheckBox { text: "Auto Screenshot"; checked: alertScreenshot; onCheckedChanged: alertScreenshot = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "3s Pre-record"; checked: alertPreRecord; onCheckedChanged: alertPreRecord = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Sound & Light"; checked: alertSoundLight; onCheckedChanged: alertSoundLight = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Cloud Push"; checked: alertCloudPush; onCheckedChanged: alertCloudPush = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "App Push"; checked: alertAppPush; onCheckedChanged: alertAppPush = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Relay Output"; checked: alertRelay; onCheckedChanged: alertRelay = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "TTS Broadcast"; checked: alertTTS; onCheckedChanged: alertTTS = checked; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Button { text: "Save Alert Policy"; font.pixelSize: 13
                    onClicked: {
                        configController.saveConfig("alertSensitivity", alertSensitivity)
                        configController.saveConfig("alertSilencePeriod", alertSilencePeriod)
                        configController.saveConfig("alertAutoConfirm", alertAutoConfirm)
                        configController.saveConfig("alertScreenshot", alertScreenshot)
                        configController.saveConfig("alertPreRecord", alertPreRecord)
                        configController.saveConfig("alertSoundLight", alertSoundLight)
                        configController.saveConfig("alertCloudPush", alertCloudPush)
                        configController.saveConfig("alertAppPush", alertAppPush)
                    }
                    background: Rectangle { color: "#3B82F6"; radius: 8; width: 140; height: 38 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "Notification Channels"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "Webhook URL:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: configController.config.webhookUrl || ""; onTextChanged: configController.saveConfig("webhookUrl", text); width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "https://..."; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "Email:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: configController.config.alertEmail || ""; onTextChanged: configController.saveConfig("alertEmail", text); width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "admin@example.com"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "SMS Phone:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: configController.config.smsPhone || ""; onTextChanged: configController.saveConfig("smsPhone", text); width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "+86..."; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                }

                Row { spacing: 12
                    CheckBox { text: "Enable Webhook"; checked: configController.config.webhookEnabled === true; onCheckedChanged: configController.saveConfig("webhookEnabled", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Enable Email"; checked: configController.config.emailEnabled === true; onCheckedChanged: configController.saveConfig("emailEnabled", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Enable SMS"; checked: configController.config.smsEnabled === true; onCheckedChanged: configController.saveConfig("smsEnabled", checked); contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Text { text: "Schedule"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Grid { columns: 4; columnSpacing: 12; rowSpacing: 6; width: parent.width
                    Text { text: "Active from:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: configController.config.alertActiveFrom || "00:00"; onTextChanged: configController.saveConfig("alertActiveFrom", text); width: 80; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                    Text { text: "Active until:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: configController.config.alertActiveUntil || "23:59"; onTextChanged: configController.saveConfig("alertActiveUntil", text); width: 80; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                }
                Row { spacing: 12
                    CheckBox { text: "Mon"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Tue"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Wed"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Thu"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Fri"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Sat"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "Sun"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                }
            }
        }

        // ── Tab 3: AI Models ──
        ScrollView { clip: true
            Column { width: settingsPage.width - 24; spacing: 8; padding: 8

                Text { text: "AI Model Config"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    width: parent.width; height: 320; spacing: 4; clip: true
                    model: configController.algorithms

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#0D0F12"; radius: 4
                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 10
                            Rectangle { width: 24; height: 24; radius: 12; color: modelData.status === "active" ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter
                                Text { text: "S" + (modelData.slot || 0); font.pixelSize: 9; color: "#0D0F12"; font.bold: true; anchors.centerIn: parent } }
                            Text { text: modelData.name || modelData.algoId; font.pixelSize: 11; color: "#E8E8E8"; width: 180; elide: Text.ElideRight }
                            Text { text: modelData.precision || "INT8"; font.pixelSize: 10; color: "#6C5CE7"; width: 40 }
                            Text { text: (modelData.size || 0) + "MB"; font.pixelSize: 10; color: "#8B8FA3"; width: 50 }
                            Text { text: (modelData.inferenceMs || 0) + "ms"; font.pixelSize: 10; color: "#FFB800"; width: 40 }
                            Button {
                                text: modelData.status === "active" ? "Deactivate" : "Activate"; font.pixelSize: 10
                                onClicked: configController.configureAlgorithm(modelData.algoId, { "action": modelData.status === "active" ? "deactivate" : "activate" })
                                background: Rectangle { color: modelData.status === "active" ? "#2A1A1A" : "#1A2A1A"; radius: 4; width: 60; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: modelData.status === "active" ? "#FF6B35" : "#00D4AA"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "Config"; font.pixelSize: 10
                                onClicked: configController.configureAlgorithm(modelData.algoId, { "action": "getConfig" })
                                background: Rectangle { color: "#252830"; radius: 4; width: 44; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }

                // TPU utilization summary
                Rectangle {
                    width: parent.width; height: 80; color: "#141720"; radius: 8
                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4
                        Text { text: "TPU Utilization"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Row { spacing: 20
                            Text { text: "Active models: " + (configController.algorithms || []).filter(function(e){ return e.status === "active" }).length; font.pixelSize: 11; color: "#00D4AA" }
                            Text { text: "Total FPS: " + (configController.algorithms || []).reduce(function(a, e){ return a + (e.fps || 0) }, 0); font.pixelSize: 11; color: "#3B82F6" }
                            Text { text: "Avg latency: " + ((configController.algorithms || []).length > 0 ? ((configController.algorithms || []).reduce(function(a, e){ return a + (e.inferenceMs || 0) }, 0) / (configController.algorithms || []).filter(function(e){ return e.status === "active" }).length).toFixed(1) : 0) + "ms"; font.pixelSize: 11; color: "#FFB800" }
                        }
                        Row { spacing: 20
                            Text { text: "Storage used: " + (configController.algorithms || []).reduce(function(a, e){ return a + (e.size || 0) }, 0).toFixed(1) + " MB"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "TPU slots: " + (configController.algorithms || []).filter(function(e){ return e.slot > 0 }).length + "/8"; font.pixelSize: 11; color: "#8B8FA3" }
                        }
                    }
                }

                Button { text: "Refresh Models"; font.pixelSize: 12
                    onClicked: configController.getAlgorithmList()
                    background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32; border.color: "#4A4D58"; border.width: 1 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }
        }
    }
}
