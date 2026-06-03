// ========================================================================
// LinkageRuleView.qml — 事件联动配置 (海康平台标准)
// 条件: 时间段/区域/位置/事件类型/事件源/自动合并
// 动作: 客户端(20+项)/Web/APP/小程序/系统
// Controller: linkageController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: linkagePage

    property var editingRule: null
    property var rules: []

    // ── 数据收集函数 ──
    function collectRuleData() {
        // 时间条件
        var days = []
        for (var d = 0; d < dayRepeater.count; d++) {
            var dayItem = dayRepeater.itemAt(d)
            if (dayItem && dayItem.checked) days.push(d + 1)  // 1=周一 .. 7=周日
        }

        // 事件类型
        var eventTypes = []
        for (var e = 0; e < eventTypeRepeater.count; e++) {
            var evtItem = eventTypeRepeater.itemAt(e)
            if (evtItem && evtItem.checked) eventTypes.push(eventTypeRepeater.model[e])
        }

        // 通道
        var channels = []
        for (var c = 0; c < channelRepeater.count; c++) {
            var chItem = channelRepeater.itemAt(c)
            if (chItem && chItem.checked) channels.push(channelRepeater.model[c])
        }

        // 条件对象
        var conditions = {
            time: {
                enabled: true,
                from: timeFromField.text,
                to: timeToField.text,
                days: days
            },
            space: {
                location: locationCombo.currentIndex > 0 ? locationCombo.currentText : "",
                roi: roiCombo.currentIndex > 0 ? roiCombo.currentText : "",
                group: groupCombo.currentIndex > 0 ? groupCombo.currentText : ""
            },
            eventTypes: eventTypes,
            minSeverity: severityCombo.currentIndex + 1,
            minConfidence: Math.round(confidenceSlider.value * 100) / 100,
            sources: { channels: channels },
            merge: {
                enabled: mergeEnabledCheck.checked,
                window: mergeWindowSpin.value,
                maxCount: mergeMaxSpin.value,
                dimension: mergeDimensionCombo.currentText
            }
        }

        // 动作列表 — 遍历 5 个 Tab 的 Column
        var actions = []
        var columns = [clientActionColumn, webActionColumn, appActionColumn, mpActionColumn, sysActionColumn]
        for (var t = 0; t < columns.length; t++) {
            var col = columns[t]
            for (var i = 0; i < col.children.length; i++) {
                var child = col.children[i]
                if (child.actionType && child.checked) {
                    actions.push({ type: child.actionType })
                }
            }
        }

        return {
            name: ruleNameField.text,
            priority: prioritySpinBox.value,
            cooldown: cooldownSpinBox.value,
            enabled: true,
            conditions: conditions,
            actions: actions
        }
    }

    // ── 回填编辑表单 ──
    function populateForm(ruleData) {
        ruleNameField.text = ruleData.name || ""
        prioritySpinBox.value = ruleData.priority || 50
        cooldownSpinBox.value = ruleData.cooldown || 5000

        var cond = ruleData.conditions || {}

        // 时间
        var tc = cond.time || {}
        timeFromField.text = tc.from || "08:00"
        timeToField.text = tc.to || "20:00"
        var dayArr = tc.days || []
        for (var d = 0; d < dayRepeater.count; d++) {
            var di = dayRepeater.itemAt(d)
            if (di) di.checked = dayArr.indexOf(d + 1) >= 0
        }

        // 空间
        var sc = cond.space || {}
        locationCombo.currentIndex = Math.max(0, locationCombo.model.indexOf(sc.location || ""))
        roiCombo.currentIndex = Math.max(0, roiCombo.model.indexOf(sc.roi || ""))
        groupCombo.currentIndex = Math.max(0, groupCombo.model.indexOf(sc.group || ""))

        // 事件类型
        var evtArr = cond.eventTypes || []
        for (var e = 0; e < eventTypeRepeater.count; e++) {
            var ei = eventTypeRepeater.itemAt(e)
            if (ei) ei.checked = evtArr.indexOf(eventTypeRepeater.model[e]) >= 0
        }

        severityCombo.currentIndex = Math.max(0, (cond.minSeverity || 1) - 1)
        confidenceSlider.value = cond.minConfidence || 0.5

        // 通道
        var chArr = (cond.sources || {}).channels || []
        for (var c = 0; c < channelRepeater.count; c++) {
            var ci = channelRepeater.itemAt(c)
            if (ci) ci.checked = chArr.indexOf(channelRepeater.model[c]) >= 0
        }

        // 合并
        var mc = cond.merge || {}
        mergeEnabledCheck.checked = mc.enabled || false
        mergeWindowSpin.value = mc.window || 10000
        mergeMaxSpin.value = mc.maxCount || 10
        mergeDimensionCombo.currentIndex = Math.max(0, mergeDimensionCombo.model.indexOf(mc.dimension || ""))

        // 动作勾选
        var acts = ruleData.actions || []
        var actTypes = []
        for (var a = 0; a < acts.length; a++) actTypes.push(acts[a].type || acts[a])
        var columns = [clientActionColumn, webActionColumn, appActionColumn, mpActionColumn, sysActionColumn]
        for (var t = 0; t < columns.length; t++) {
            var col = columns[t]
            for (var i = 0; i < col.children.length; i++) {
                var child = col.children[i]
                if (child.actionType) {
                    child.checked = actTypes.indexOf(child.actionType) >= 0
                }
            }
        }
    }

    // ── 重置表单 ──
    function resetForm() {
        ruleNameField.text = ""
        prioritySpinBox.value = 50
        cooldownSpinBox.value = 5000
        timeFromField.text = "08:00"
        timeToField.text = "20:00"
        for (var d = 0; d < dayRepeater.count; d++) {
            var di = dayRepeater.itemAt(d)
            if (di) di.checked = d < 5
        }
        locationCombo.currentIndex = 0
        roiCombo.currentIndex = 0
        groupCombo.currentIndex = 0
        for (var e = 0; e < eventTypeRepeater.count; e++) {
            var ei = eventTypeRepeater.itemAt(e)
            if (ei) ei.checked = false
        }
        severityCombo.currentIndex = 0
        confidenceSlider.value = 0.5
        for (var c = 0; c < channelRepeater.count; c++) {
            var ci = channelRepeater.itemAt(c)
            if (ci) ci.checked = c < 4
        }
        mergeEnabledCheck.checked = false
        mergeWindowSpin.value = 10000
        mergeMaxSpin.value = 10
        mergeDimensionCombo.currentIndex = 0
        var columns = [clientActionColumn, webActionColumn, appActionColumn, mpActionColumn, sysActionColumn]
        for (var t = 0; t < columns.length; t++) {
            var col = columns[t]
            for (var i = 0; i < col.children.length; i++) {
                var child = col.children[i]
                if (child.actionType) child.checked = false
            }
        }
    }

    Component.onCompleted: {
        linkageController.refreshRules()
    }

    Connections {
        target: linkageController
        function onRulesUpdated() {
            rules = linkageController.rules
            ruleListView.model = rules
        }
        function onRuleCreated() {
            ruleEditor.visible = false
            linkageController.refreshRules()
        }
        function onRuleDeleted() {
            linkageController.refreshRules()
        }
    }

    // ── 工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12

            Text { text: "🔗 事件联动"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: "配置告警触发条件和联动动作"; font.pixelSize: 11; color: "#4A4D58" }

            Item { Layout.fillWidth: true }

            Button { text: "➕ 新建规则"; font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 8; width: 100; height: 34 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    editingRule = null
                    resetForm()
                    ruleEditor.visible = true
                }
            }
        }
    }

    // ── 左: 规则列表 ──
    Rectangle {
        id: ruleListPanel
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: ruleEditor.visible ? ruleEditor.left : parent.right
        anchors.margins: 8; color: "#141720"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            Row { spacing: 8; width: parent.width
                TextField { width: parent.width - 80; height: 32; placeholderText: "搜索规则..."
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6 } }
                ComboBox { width: 72; height: 32; model: ["全部", "启用", "停用"]
                    background: Rectangle { color: "#252830"; radius: 6 }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
            }

            ListView {
                id: ruleListView
                width: parent.width; height: parent.height - 44; spacing: 4; clip: true
                model: rules

                delegate: Rectangle {
                    width: ListView.view.width; height: 72; color: "#0D0F12"; radius: 8
                    border.color: modelData.enabled ? "#00D4AA" : "#252830"; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10

                        Switch {
                            checked: modelData.enabled
                            Layout.preferredHeight: 28
                            onToggled: linkageController.toggleRule(modelData.id, checked)
                        }

                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Row { spacing: 6
                                Text { text: modelData.name || "-"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                                Rectangle { width: 24; height: 16; radius: 8; color: "#1A2A1A"
                                    Text { text: "P" + (modelData.priority || 0); font.pixelSize: 9; color: "#00D4AA"; anchors.centerIn: parent } }
                            }
                            Row { spacing: 12
                                Text { text: "🎯 " + (modelData.eventTypes || "-"); font.pixelSize: 10; color: "#6C5CE7" }
                                Text { text: "⚡ " + (modelData.actions || "-"); font.pixelSize: 10; color: "#8B8FA3"; elide: Text.ElideRight; width: 200 }
                            }
                        }

                        Button { text: "✏️"; font.pixelSize: 14
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#8B8FA3" }
                            onClicked: {
                                editingRule = modelData
                                populateForm(modelData)
                                ruleEditor.visible = true
                            }
                        }
                        Button { text: "🗑️"; font.pixelSize: 14
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FF3D71" }
                            onClicked: linkageController.deleteRule(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ── 右: 规则编辑器 (滑出面板) ──
    Rectangle {
        id: ruleEditor
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.right: parent.right; width: 460
        anchors.margins: 8; color: "#1A1D23"; radius: 8
        visible: false; border.color: "#3B82F6"; border.width: 1

        ScrollView {
            anchors.fill: parent; clip: true

            Column {
                width: 428; spacing: 8; padding: 12

                // ── 基本信息 ──
                Row { spacing: 8
                    Text { text: editingRule ? "📝 编辑联动规则" : "📝 新建联动规则"; font.pixelSize: 15; font.bold: true; color: "#E8E8E8" }
                    Item { width: 100 }
                    Button { text: "✕ 关闭"; font.pixelSize: 11
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FF6B35" }
                        onClicked: ruleEditor.visible = false
                    }
                }

                Text { text: "规则名称"; font.pixelSize: 11; color: "#8B8FA3" }
                TextField {
                    id: ruleNameField
                    width: parent.width; height: 32; placeholderText: "例: 周界入侵联动"
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6 }
                    text: editingRule ? editingRule.name || "" : ""
                }

                Row { spacing: 12
                    Column { spacing: 2
                        Text { text: "优先级 (1-100)"; font.pixelSize: 11; color: "#8B8FA3" }
                        SpinBox { id: prioritySpinBox; from: 1; to: 100; value: editingRule ? editingRule.priority || 50 : 50; width: 100 }
                    }
                    Column { spacing: 2
                        Text { text: "冷却时间(ms)"; font.pixelSize: 11; color: "#8B8FA3" }
                        SpinBox { id: cooldownSpinBox; from: 1000; to: 60000; value: editingRule ? editingRule.cooldown || 5000 : 5000; stepSize: 1000; width: 120 }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                // ═══ 触发条件 ═══
                Text { text: "📋 触发条件"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 1. 指定时间段
                GroupBox {
                    width: parent.width; title: "🕐 时间条件"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Row { spacing: 4
                            Text { text: "从"; font.pixelSize: 11; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            TextField { id: timeFromField; text: "08:00"; width: 70; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                            Text { text: "至"; font.pixelSize: 11; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            TextField { id: timeToField; text: "20:00"; width: 70; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                        }
                        Row { spacing: 4
                            Repeater { id: dayRepeater; model: ["一","二","三","四","五","六","日"]
                                delegate: CheckBox { text: modelData; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#8B8FA3" } checked: index < 5 }
                            }
                        }
                    }
                }

                // 2. 指定区域/位置
                GroupBox {
                    width: parent.width; title: "📍 空间条件"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Text { text: "物理位置"; font.pixelSize: 11; color: "#8B8FA3" }
                        ComboBox { id: locationCombo; width: parent.width; height: 28; model: ["全部位置", "3号厂区", "东围墙", "2号车间", "1号大门"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                        Text { text: "ROI区域 (算法检测区)"; font.pixelSize: 11; color: "#8B8FA3" }
                        ComboBox { id: roiCombo; width: parent.width; height: 28; model: ["全部区域", "周界线A", "绊线B", "区域C"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                        Text { text: "设备分组"; font.pixelSize: 11; color: "#8B8FA3" }
                        ComboBox { id: groupCombo; width: parent.width; height: 28; model: ["全部分组", "东区摄像头", "室内摄像头", "室外摄像头"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    }
                }

                // 3. 指定事件类型
                GroupBox {
                    width: parent.width; title: "🎯 事件类型"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 4; width: parent.width
                        Row { spacing: 4
                            Repeater { id: eventTypeRepeater; model: ["周界入侵","绊线","烟火","安全帽","人脸","车牌","人群","摔倒"]
                                delegate: CheckBox { text: modelData; contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8" } }
                            }
                        }
                        Row { spacing: 12
                            Column { spacing: 2
                                Text { text: "最低严重度"; font.pixelSize: 10; color: "#8B8FA3" }
                                ComboBox { id: severityCombo; width: 100; height: 28; model: ["1-提示","2-低","3-中","4-高","5-紧急"]; background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 10; color: "#E8E8E8"; leftPadding: 4; verticalAlignment: Text.AlignVCenter } }
                            }
                            Column { spacing: 2
                                Text { text: "最低置信度"; font.pixelSize: 10; color: "#8B8FA3" }
                                Row { Slider { id: confidenceSlider; width: 120; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.05 } Text { text: Math.round(confidenceSlider.value * 100) + "%"; font.pixelSize: 10; color: "#E8E8E8" } }
                            }
                        }
                    }
                }

                // 4. 指定事件源
                GroupBox {
                    width: parent.width; title: "📹 事件源"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Text { text: "选择通道 (留空=全部)"; font.pixelSize: 11; color: "#8B8FA3" }
                        Row { spacing: 4
                            Repeater { id: channelRepeater; model: ["CH01","CH02","CH03","CH04","CH05","CH06","CH07","CH08"]
                                delegate: CheckBox { text: modelData; checked: index < 4; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8" } }
                            }
                        }
                    }
                }

                // 5. 自动合并
                GroupBox {
                    width: parent.width; title: "🔄 自动合并"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        CheckBox { id: mergeEnabledCheck; text: "启用自动合并"; checked: false; contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 12
                            Column { spacing: 2
                                Text { text: "合并窗口(ms)"; font.pixelSize: 10; color: "#8B8FA3" }
                                SpinBox { id: mergeWindowSpin; from: 1000; to: 60000; value: 10000; stepSize: 1000; width: 120 }
                            }
                            Column { spacing: 2
                                Text { text: "最大合并数"; font.pixelSize: 10; color: "#8B8FA3" }
                                SpinBox { id: mergeMaxSpin; from: 2; to: 100; value: 10; width: 80 }
                            }
                            Column { spacing: 2
                                Text { text: "合并维度"; font.pixelSize: 10; color: "#8B8FA3" }
                                ComboBox { id: mergeDimensionCombo; width: 80; height: 28; model: ["通道","类型","位置"]; background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 10; color: "#E8E8E8"; leftPadding: 4; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                // ═══ 联动动作 ═══
                Text { text: "⚡ 联动动作"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // Tab: 客户端 | Web | APP | 小程序 | 系统
                TabBar {
                    id: actionTabBar
                    width: parent.width; height: 32
                    background: Rectangle { color: "#0D0F12"; radius: 4 }

                    TabButton { text: "🖥️ 客户端"; font.pixelSize: 10
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: actionTabBar.currentIndex === 0 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 0 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "🌐 Web端"; font.pixelSize: 10
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: actionTabBar.currentIndex === 1 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 1 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "📱 APP"; font.pixelSize: 10
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: actionTabBar.currentIndex === 2 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 2 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "💬 小程序"; font.pixelSize: 10
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: actionTabBar.currentIndex === 3 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 3 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "⚙️ 系统"; font.pixelSize: 10
                        contentItem: Text { text: parent.text; font.pixelSize: 10; color: actionTabBar.currentIndex === 4 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 4 ? "#1A1D23" : "transparent"; radius: 4 } }
                }

                StackLayout {
                    width: parent.width; currentIndex: actionTabBar.currentIndex

                    // ─── 客户端动作 (海康标准20+项) ───
                    ScrollView { clip: true
                        Column { id: clientActionColumn; width: 412; spacing: 2

                            Text { text: "📹 视频联动"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "弹出指定监控点实时视频"; icon: "📹"; actionType: "CLIENT_SHOW_LIVE" }
                            ActionCheckRow { text: "弹出指定监控点录像回放"; icon: "📼"; actionType: "CLIENT_SHOW_PLAYBACK" }
                            ActionCheckRow { text: "弹出事件图片"; icon: "🖼️"; actionType: "CLIENT_SHOW_IMAGE" }
                            ActionCheckRow { text: "弹窗视频画面叠加事件信息"; icon: "📋"; actionType: "CLIENT_OVERLAY_INFO" }

                            Text { text: "🔊 音频联动"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "控制指定对讲通道语音对讲"; icon: "🎙️"; actionType: "CLIENT_VOICE_TALK" }
                            ActionCheckRow { text: "播放提示音"; icon: "🔔"; actionType: "CLIENT_PLAY_TONE" }
                            ActionCheckRow { text: "语音播报事件信息 (重复N次)"; icon: "📢"; actionType: "CLIENT_TTS_BROADCAST" }

                            Text { text: "📺 显示联动"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "联动地图位置"; icon: "🗺️"; actionType: "CLIENT_SHOW_MAP" }
                            ActionCheckRow { text: "指定监控点上电视墙 (持续N秒)"; icon: "🖥️"; actionType: "CLIENT_TV_WALL" }
                            ActionCheckRow { text: "发生预警不弹窗 (静默)"; icon: "🔇"; actionType: "CLIENT_SUPPRESS_POPUP" }
                            ActionCheckRow { text: "执行事件处理预案"; icon: "📋"; actionType: "CLIENT_EXECUTE_PLAN" }

                            Text { text: "📹 录像与抓图"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "指定监控点事件录像"; icon: "🎥"; actionType: "CLIENT_RECORD_EVENT" }
                            ActionCheckRow { text: "添加录像标记 (类型+描述)"; icon: "🔖"; actionType: "CLIENT_ADD_BOOKMARK" }
                            ActionCheckRow { text: "间隔N秒抓图M次"; icon: "📸"; actionType: "CLIENT_CAPTURE_IMAGE" }

                            Text { text: "🎮 设备控制"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "控制指定报警输出"; icon: "🚨"; actionType: "CLIENT_ALARM_OUTPUT" }
                            ActionCheckRow { text: "控制云台"; icon: "🎮"; actionType: "CLIENT_PTZ_CONTROL" }
                            ActionCheckRow { text: "事件开始转到预置点"; icon: "📍"; actionType: "CLIENT_PTZ_PRESET_START" }
                            ActionCheckRow { text: "事件结束恢复到预置点"; icon: "🔙"; actionType: "CLIENT_PTZ_PRESET_END" }
                            ActionCheckRow { text: "调用巡航路径"; icon: "🔄"; actionType: "CLIENT_PTZ_CRUISE" }
                            ActionCheckRow { text: "调用轨迹"; icon: "〰️"; actionType: "CLIENT_PTZ_TRACK" }
                            ActionCheckRow { text: "指定门禁点开门"; icon: "🚪"; actionType: "CLIENT_ACCESS_OPEN" }

                            Text { text: "📬 通知"; font.pixelSize: 11; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "发送短信给指定用户"; icon: "SMS"; actionType: "CLIENT_SEND_SMS" }
                            ActionCheckRow { text: "发送邮件给指定用户"; icon: "📧"; actionType: "CLIENT_SEND_EMAIL" }
                            ActionCheckRow { text: "指定IP进行指定模式报警"; icon: "🌐"; actionType: "CLIENT_ALARM_MODE" }
                            ActionCheckRow { text: "逐级推送 (每N秒未解决推送至下一级)"; icon: "⬆️"; actionType: "CLIENT_ESCALATE" }
                        }
                    }

                    // ─── Web端 ───
                    ScrollView { clip: true
                        Column { id: webActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "Web端弹窗通知"; icon: "💬"; actionType: "WEB_POPUP" }
                            ActionCheckRow { text: "发送邮件"; icon: "📧"; actionType: "WEB_EMAIL" }
                            ActionCheckRow { text: "HTTP回调 (WebHook)"; icon: "🔗"; actionType: "WEB_WEBHOOK" }
                            ActionCheckRow { text: "Dashboard嵌入告警"; icon: "📊"; actionType: "WEB_DASHBOARD_ALERT" }
                        }
                    }

                    // ─── APP ───
                    ScrollView { clip: true
                        Column { id: appActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "APP推送通知"; icon: "📱"; actionType: "APP_PUSH_NOTIFY" }
                            ActionCheckRow { text: "APP弹实时视频"; icon: "📹"; actionType: "APP_SHOW_LIVE" }
                            ActionCheckRow { text: "APP弹事件图片"; icon: "🖼️"; actionType: "APP_SHOW_IMAGE" }
                            ActionCheckRow { text: "APP弹录像回放"; icon: "📼"; actionType: "APP_SHOW_PLAYBACK" }
                            ActionCheckRow { text: "APP处置按钮"; icon: "✅"; actionType: "APP_HANDLE_DISPOSE" }
                        }
                    }

                    // ─── 小程序 ───
                    ScrollView { clip: true
                        Column { id: mpActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "小程序订阅消息"; icon: "💬"; actionType: "MP_SUBSCRIBE_MSG" }
                            ActionCheckRow { text: "小程序弹事件图片"; icon: "🖼️"; actionType: "MP_SHOW_IMAGE" }
                            ActionCheckRow { text: "小程序弹实时视频"; icon: "📹"; actionType: "MP_SHOW_LIVE" }
                        }
                    }

                    // ─── 系统 ───
                    ScrollView { clip: true
                        Column { id: sysActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "MQTT消息发布"; icon: "📡"; actionType: "SYS_MQTT_PUBLISH" }
                            ActionCheckRow { text: "Modbus写寄存器"; icon: "🔌"; actionType: "SYS_MODBUS_WRITE" }
                            ActionCheckRow { text: "ONVIF事件触发"; icon: "🔗"; actionType: "SYS_ONVIF_TRIGGER" }
                            ActionCheckRow { text: "继电器开关"; icon: "⚡"; actionType: "SYS_RELAY_SWITCH" }
                            ActionCheckRow { text: "HTTP回调"; icon: "🌐"; actionType: "SYS_HTTP_CALLBACK" }
                            ActionCheckRow { text: "转发到云端"; icon: "☁️"; actionType: "SYS_CLOUD_FORWARD" }
                        }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13
                        background: Rectangle { color: "#252830"; radius: 8; width: 90; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: ruleEditor.visible = false
                    }
                    Button { text: "💾 保存规则"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 110; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            var ruleData = collectRuleData()
                            if (!ruleData.name) {
                                notificationController.addNotification("错误", "规则名称不能为空", "error")
                                return
                            }
                            if (editingRule) {
                                linkageController.updateRule(editingRule.id, ruleData)
                            } else {
                                linkageController.createRule(ruleData)
                            }
                        }
                    }
                }

                Item { height: 20 }
            }
        }
    }

    // ─── 动作勾选行组件 ───
    component ActionCheckRow: Row {
        id: actionRow
        spacing: 6; width: 412; height: 28

        property string text: ""
        property string icon: ""
        property string actionType: ""
        property alias checked: cb.checked

        CheckBox { id: cb; anchors.verticalCenter: parent.verticalCenter }
        Text { text: actionRow.icon; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        Text { text: actionRow.text; font.pixelSize: 11; color: cb.checked ? "#E8E8E8" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter; width: 300; elide: Text.ElideRight }
        Button { text: "⚙️"; font.pixelSize: 10; visible: cb.checked; anchors.verticalCenter: parent.verticalCenter
            background: Rectangle { color: "transparent" }
            contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#3B82F6" }
        }
    }
}
