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

    // ── 校验错误状态 (规范 82ec775a: 显示给用户的可读错误) ──
    property string validationError: ""
    property string validationField: ""
    property int    validationCode: -1

    // ── 条件树状态 (P1 #5) ──
    property var conditionTree: ({node_type: "AND", children: []})
    property bool useTreeMode: false   // true=使用条件树, false=使用下方扁平字段

    // ── 互斥/抑制状态 (P1 #6) ──
    property string mutexGroup: ""
    property string suppressAfterRule: ""
    property bool   suppressLowerPriority: false

    // ── 数据收集函数 ──
    function collectRuleData() {
        // 时间条件 (P1 #8: 顶层 time_cond)
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

        // time_cond (P1 #8 顶层)
        var timeCond = {
            time_start: timeFromField.text,
            time_end: timeToField.text,
            weekdays: days
        }
        // source_cond (顶层)
        var sourceCond = {
            channel_ids: channels,
            event_types: eventTypes,
            min_severity: severityCombo.currentIndex + 1,
            min_confidence: Math.round(confidenceSlider.value * 100) / 100
        }
        // spatial_cond (顶层)
        var spatialCond = {
            region_id: roiCombo.currentIndex > 0 ? roiCombo.currentText : "",
            location_id: locationCombo.currentIndex > 0 ? locationCombo.currentText : "",
            device_group_id: groupCombo.currentIndex > 0 ? groupCombo.currentText : ""
        }
        // merge_cond (P1 #7 顶层)
        var mergeCond = {
            enabled: mergeEnabledCheck.checked,
            window_ms: mergeWindowSpin.value,
            max_merge_count: mergeMaxSpin.value,
            merge_by: mergeDimensionCombo.currentText
        }

        var rule = {
            name: ruleNameField.text,
            priority: prioritySpinBox.value,
            cooldown_ms: cooldownSpinBox.value,
            enabled: true,
            time_cond: timeCond,
            spatial_cond: spatialCond,
            source_cond: sourceCond,
            merge_cond: mergeCond,
            mutex_group: mutexGroup,
            suppress_after_rule: suppressAfterRule,
            suppress_lower_priority: suppressLowerPriority,
            actions: actions
        }

        // condition_tree (P1 #5 顶层, 启用树模式时才提交)
        if (useTreeMode && conditionTree) {
            rule.condition_tree = conditionTree
        }

        // 保留原 conditions 供后端兼容 (镜像)
        rule.conditions = {
            time: timeCond,
            space: spatialCond,
            eventTypes: eventTypes,
            minSeverity: sourceCond.min_severity,
            minConfidence: sourceCond.min_confidence,
            sources: { channels: channels },
            merge: { enabled: mergeCond.enabled, window: mergeCond.window_ms,
                     maxCount: mergeCond.max_merge_count, dimension: mergeCond.merge_by }
        }

        return rule
    }

    // ── 回填编辑表单 ──
    function populateForm(ruleData) {
        ruleNameField.text = ruleData.name || ""
        prioritySpinBox.value = ruleData.priority || 50
        cooldownSpinBox.value = ruleData.cooldown_ms || ruleData.cooldown || 5000

        // time_cond (P1 #8 顶层)
        var tc = ruleData.time_cond || {}
        if (!tc.time_start && ruleData.conditions && ruleData.conditions.time) {
            tc = ruleData.conditions.time
        }
        timeFromField.text = tc.time_start || tc.from || "08:00"
        timeToField.text   = tc.time_end   || tc.to   || "20:00"
        var dayArr = tc.weekdays || tc.days || []
        for (var d = 0; d < dayRepeater.count; d++) {
            var di = dayRepeater.itemAt(d)
            if (di) di.checked = dayArr.indexOf(d + 1) >= 0
        }

        // spatial_cond
        var sc = ruleData.spatial_cond || {}
        if (!sc.location_id && ruleData.conditions && ruleData.conditions.space) sc = ruleData.conditions.space
        locationCombo.currentIndex = Math.max(0, locationCombo.model.indexOf(sc.location_id || sc.location || ""))
        roiCombo.currentIndex      = Math.max(0, roiCombo.model.indexOf(sc.region_id || sc.roi || ""))
        groupCombo.currentIndex    = Math.max(0, groupCombo.model.indexOf(sc.device_group_id || sc.group || ""))

        // eventTypes
        var evtArr = []
        if (ruleData.source_cond && ruleData.source_cond.event_types) {
            evtArr = ruleData.source_cond.event_types
        } else if (ruleData.conditions && ruleData.conditions.eventTypes) {
            evtArr = ruleData.conditions.eventTypes
        }
        for (var e = 0; e < eventTypeRepeater.count; e++) {
            var ei = eventTypeRepeater.itemAt(e)
            if (ei) ei.checked = evtArr.indexOf(eventTypeRepeater.model[e]) >= 0
        }

        var minSev = 1, minConf = 0.5
        if (ruleData.source_cond) {
            minSev  = ruleData.source_cond.min_severity || 1
            minConf = ruleData.source_cond.min_confidence || 0.5
        } else if (ruleData.conditions) {
            minSev  = ruleData.conditions.minSeverity || 1
            minConf = ruleData.conditions.minConfidence || 0.5
        }
        severityCombo.currentIndex = Math.max(0, minSev - 1)
        confidenceSlider.value = minConf

        // channels
        var chArr = []
        if (ruleData.source_cond && ruleData.source_cond.channel_ids) {
            chArr = ruleData.source_cond.channel_ids
        } else if (ruleData.conditions && ruleData.conditions.sources) {
            chArr = ruleData.conditions.sources.channels || []
        }
        for (var c = 0; c < channelRepeater.count; c++) {
            var ci = channelRepeater.itemAt(c)
            if (ci) ci.checked = chArr.indexOf(channelRepeater.model[c]) >= 0
        }

        // merge_cond (P1 #7 顶层)
        var mc = ruleData.merge_cond || {}
        if (!mc.enabled && ruleData.conditions && ruleData.conditions.merge) mc = ruleData.conditions.merge
        mergeEnabledCheck.checked = mc.enabled || false
        mergeWindowSpin.value    = mc.window_ms || mc.window || 10000
        mergeMaxSpin.value       = mc.max_merge_count || mc.maxCount || 10
        mergeDimensionCombo.currentIndex = Math.max(0, mergeDimensionCombo.model.indexOf(mc.merge_by || mc.dimension || ""))

        // 互斥与抑制 (P1 #6)
        mutexGroup            = ruleData.mutex_group || ""
        suppressAfterRule     = ruleData.suppress_after_rule || ""
        suppressLowerPriority = ruleData.suppress_lower_priority === true

        // 条件树 (P1 #5)
        if (ruleData.condition_tree) {
            conditionTree = ruleData.condition_tree
            useTreeMode = true
        } else {
            useTreeMode = false
            // 默认根据现有表单生成一个 AND 根 + 所有 LEAF 的快照
            conditionTree = buildTreeFromFlat()
        }

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

    // ── 从扁平表单生成一个 AND 根 + 所有 LEAF 的快照 (供条件树初始值) ──
    function buildTreeFromFlat() {
        var children = []
        // 事件类型 LEAF
        for (var e = 0; e < eventTypeRepeater.count; e++) {
            var ei = eventTypeRepeater.itemAt(e)
            if (ei && ei.checked) {
                children.push({
                    node_type: "LEAF",
                    leaf_type: "SOURCE",
                    field: "event_type",
                    op: "==",
                    value: eventTypeRepeater.model[e]
                })
            }
        }
        // 通道 LEAF
        for (var c = 0; c < channelRepeater.count; c++) {
            var ci = channelRepeater.itemAt(c)
            if (ci && ci.checked) {
                children.push({
                    node_type: "LEAF",
                    leaf_type: "SOURCE",
                    field: "channel_id",
                    op: "==",
                    value: channelRepeater.model[c]
                })
            }
        }
        // 严重度 LEAF
        if (severityCombo.currentIndex > 0) {
            children.push({
                node_type: "LEAF",
                leaf_type: "SOURCE",
                field: "min_severity",
                op: ">=",
                value: severityCombo.currentIndex + 1
            })
        }
        return { node_type: "AND", children: children }
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
        // 互斥与抑制 (P1 #6)
        mutexGroup = ""
        suppressAfterRule = ""
        suppressLowerPriority = false
        mutexGroupField.text = ""
        suppressAfterCombo.currentIndex = 0
        suppressLowerSwitch.checked = false
        // 条件树 (P1 #5)
        useTreeMode = false
        conditionTree = { node_type: "AND", children: [] }
        treeRootEditor.refresh(conditionTree)
        treeModeSwitch.checked = false

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
        function onValidationFailed(code, field, message) {
            // 完整对接严格校验 (P0 #4 + P1 #5/#6/#7/#8)
            validationError = message || "校验失败"
            validationField = field || ""
            validationCode = code || -1
            errorBanner.visible = true
        }
    }

    // ── 工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12

            AppIcon { name: "linkage"; size: 22; iconColor: "#E8E8E8"; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Text { text: "事件联动"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: "配置告警触发条件和联动动作"; font.pixelSize: 12; color: "#4A4D58" }

            Item { Layout.fillWidth: true }

            Button { text: "新建规则"; font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 8; width: 100; height: 34 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    editingRule = null
                    resetForm()
                    ruleEditor.visible = true
                }
            }
            Button { text: "导出"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 8; width: 60; height: 34 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: exportDialog.open()
            }
            Button { text: "导入"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 8; width: 60; height: 34 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: importDialog.open()
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
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
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
                                    Text { text: "P" + (modelData.priority || 0); font.pixelSize: 12; color: "#00D4AA"; anchors.centerIn: parent } }
                            }
                            Row { spacing: 12
                                Text { text: (modelData.eventTypes || "-"); font.pixelSize: 12; color: "#6C5CE7" }
                                Text { text: (modelData.actions || "-"); font.pixelSize: 12; color: "#8B8FA3"; elide: Text.ElideRight; width: 200 }
                            }
                        }

                        Button { text: "编辑"; font.pixelSize: 12
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3" }
                            onClicked: {
                                editingRule = modelData
                                populateForm(modelData)
                                ruleEditor.visible = true
                            }
                        }
                        Button { text: "删除"; font.pixelSize: 12
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF3D71" }
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
                    Text { text: editingRule ? "编辑联动规则" : "新建联动规则"; font.pixelSize: 15; font.bold: true; color: "#E8E8E8" }
                    Item { width: 100 }
                    Button { text: "关闭"; font.pixelSize: 12
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF6B35" }
                        onClicked: ruleEditor.visible = false
                    }
                }

                Text { text: "规则名称"; font.pixelSize: 12; color: "#8B8FA3" }
                TextField {
                    id: ruleNameField
                    width: parent.width; height: 32; placeholderText: "例: 周界入侵联动"
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle {
                        color: validationField === "name" ? "#3B1A1A" : "#252830"
                        radius: 6
                        border.color: validationField === "name" ? "#FF3D71" : "transparent"
                        border.width: validationField === "name" ? 1 : 0
                    }
                    text: editingRule ? editingRule.name || "" : ""
                }

                // 规则 ID (规范 72d2dd9b: 必须字段, 提交时强制非空 + 唯一)
                Text { text: "规则 ID (唯一标识,提交后不可改)"; font.pixelSize: 12; color: "#8B8FA3" }
                TextField {
                    id: ruleIdField
                    width: parent.width; height: 32
                    placeholderText: "例: rule_perimeter_001"
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle {
                        color: validationField === "id" || validationField === "rule_id" ? "#3B1A1A" : "#252830"
                        radius: 6
                        border.color: (validationField === "id" || validationField === "rule_id") ? "#FF3D71" : "transparent"
                        border.width: (validationField === "id" || validationField === "rule_id") ? 1 : 0
                    }
                    text: editingRule ? (editingRule.id || editingRule.rule_id || "") : ""
                    readOnly: editingRule !== null   // 编辑模式: ID 锁定防误改
                }

                // 校验错误条 (规范 82ec775a: 可读错误信息)
                Rectangle {
                    id: errorBanner
                    width: parent.width; height: 36; radius: 6
                    color: "#3B1A1A"
                    border.color: "#FF3D71"; border.width: 1
                    visible: false
                    Row {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        AppIcon { name: "warning"; size: 16; iconColor: "#FFB800"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: validationError; font.pixelSize: 12; color: "#FF8080"; font.bold: true }
                            Text {
                                text: "字段: " + validationField + "  |  错误码: " + validationCode
                                font.pixelSize: 12; color: "#8B4A4A"
                                visible: validationField !== ""
                            }
                        }
                        Item { width: 8 }
                        Button { text: "X"; font.pixelSize: 12
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF8080" }
                            onClicked: { errorBanner.visible = false; validationError = ""; validationField = ""; validationCode = -1 }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Row { spacing: 12
                    Column { spacing: 2
                        Text { text: "优先级 (1-100)"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { id: prioritySpinBox; from: 1; to: 100; value: editingRule ? editingRule.priority || 50 : 50; width: 100 }
                    }
                    Column { spacing: 2
                        Text { text: "冷却时间(ms)"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox { id: cooldownSpinBox; from: 1000; to: 60000; value: editingRule ? editingRule.cooldown || 5000 : 5000; stepSize: 1000; width: 120 }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                // ═══ 触发条件 ═══
                Text { text: "触发条件"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 1. 指定时间段
                GroupBox {
                    width: parent.width; title: "时间条件"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Row { spacing: 4
                            Text { text: "从"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            TextField { id: timeFromField; text: "08:00"; width: 70; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                            Text { text: "至"; font.pixelSize: 12; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                            TextField { id: timeToField; text: "20:00"; width: 70; height: 28; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 4 } }
                        }
                        Row { spacing: 4
                            Repeater { id: dayRepeater; model: ["一","二","三","四","五","六","日"]
                                delegate: CheckBox { text: modelData; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3" } checked: index < 5 }
                            }
                        }
                    }
                }

                // 2. 指定区域/位置
                GroupBox {
                    width: parent.width; title: "空间条件"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Text { text: "物理位置"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { id: locationCombo; width: parent.width; height: 28; model: ["全部位置", "3号厂区", "东围墙", "2号车间", "1号大门"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                        Text { text: "ROI区域 (算法检测区)"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { id: roiCombo; width: parent.width; height: 28; model: ["全部区域", "周界线A", "绊线B", "区域C"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                        Text { text: "设备分组"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox { id: groupCombo; width: parent.width; height: 28; model: ["全部分组", "东区摄像头", "室内摄像头", "室外摄像头"]; background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                    }
                }

                // 3. 指定事件类型
                GroupBox {
                    width: parent.width; title: "事件类型"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 4; width: parent.width
                        Row { spacing: 4
                            Repeater { id: eventTypeRepeater; model: ["周界入侵","绊线","烟火","安全帽","人脸","车牌","人群","摔倒"]
                                delegate: CheckBox { text: modelData; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                            }
                        }
                        Row { spacing: 12
                            Column { spacing: 2
                                Text { text: "最低严重度"; font.pixelSize: 12; color: "#8B8FA3" }
                                ComboBox { id: severityCombo; width: 100; height: 28; model: ["1-提示","2-低","3-中","4-高","5-紧急"]; background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 4; verticalAlignment: Text.AlignVCenter } }
                            }
                            Column { spacing: 2
                                Text { text: "最低置信度"; font.pixelSize: 12; color: "#8B8FA3" }
                                Row { Slider { id: confidenceSlider; width: 120; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.05 } Text { text: Math.round(confidenceSlider.value * 100) + "%"; font.pixelSize: 12; color: "#E8E8E8" } }
                            }
                        }
                    }
                }

                // 4. 指定事件源
                GroupBox {
                    width: parent.width; title: "事件源"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Text { text: "选择通道 (留空=全部)"; font.pixelSize: 12; color: "#8B8FA3" }
                        Row { spacing: 4
                            Repeater { id: channelRepeater; model: ["CH01","CH02","CH03","CH04","CH05","CH06","CH07","CH08"]
                                delegate: CheckBox { text: modelData; checked: index < 4; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                            }
                        }
                    }
                }

                // 5. 自动合并
                GroupBox {
                    width: parent.width; title: "自动合并 (merge_cond)"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        CheckBox { id: mergeEnabledCheck; text: "启用自动合并"; checked: false; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                        Row { spacing: 12
                            Column { spacing: 2
                                Text { text: "合并窗口(ms, 0-60000)"; font.pixelSize: 12; color: "#8B8FA3" }
                                SpinBox { id: mergeWindowSpin; from: 0; to: 60000; value: 10000; stepSize: 1000; width: 120 }
                            }
                            Column { spacing: 2
                                Text { text: "最大合并数 (0-1000)"; font.pixelSize: 12; color: "#8B8FA3" }
                                SpinBox { id: mergeMaxSpin; from: 0; to: 1000; value: 10; width: 80 }
                            }
                            Column { spacing: 2
                                Text { text: "合并维度 (channel/type/location)"; font.pixelSize: 12; color: "#8B8FA3" }
                                ComboBox { id: mergeDimensionCombo; width: 110; height: 28; model: ["","channel","type","location"]; background: Rectangle { color: "#252830"; radius: 4 }
                                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 4; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }

                // 6. 互斥与抑制 (P1 #6)
                GroupBox {
                    width: parent.width; title: "互斥与抑制 (mutex_group / suppress_after / suppress_lower)"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Text { text: "互斥组 (同组规则同时只触发优先级最高一条, 留空 = 不参与互斥)"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            id: mutexGroupField
                            width: parent.width; height: 28
                            placeholderText: "例: perimeter_alarm_group"
                            placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 4 }
                            text: linkagePage.mutexGroup
                            onTextChanged: linkagePage.mutexGroup = text
                        }
                        Text { text: "抑制链 (本规则被指定规则触发后抑制)"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox {
                            id: suppressAfterCombo
                            width: parent.width; height: 28
                            model: [""].concat(linkageController.allRuleIds(editingRule ? (editingRule.id || editingRule.rule_id || "") : ""))
                            background: Rectangle { color: "#252830"; radius: 4 }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                            currentIndex: Math.max(0, model.indexOf(linkagePage.suppressAfterRule))
                            onActivated: linkagePage.suppressAfterRule = model[currentIndex]
                        }
                        Switch {
                            id: suppressLowerSwitch
                            text: "触发后抑制同组低优先级规则"
                            checked: linkagePage.suppressLowerPriority
                            onToggled: linkagePage.suppressLowerPriority = checked
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 32 }
                        }
                    }
                }

                // 7. 条件树 (P1 #5)
                GroupBox {
                    width: parent.width; title: "条件树 (AND / OR / LEAF, 深度≤3)"
                    label: Text { text: parent.title; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                    background: Rectangle { color: "#0D0F12"; radius: 6; y: parent.topInset; width: parent.availableWidth; height: parent.availableHeight + parent.topInset + parent.bottomInset }

                    Column { spacing: 6; width: parent.width
                        Row { spacing: 8
                            Switch {
                                id: treeModeSwitch
                                text: "启用条件树 (开后以上面 LEAF 为快照, 后端会优先使用本树)"
                                checked: linkagePage.useTreeMode
                                onToggled: linkagePage.useTreeMode = checked
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; leftPadding: 32; wrapMode: Text.WordWrap; width: 380 }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: linkagePage.useTreeMode ? 320 : 0
                            visible: linkagePage.useTreeMode
                            color: "#141720"; radius: 4; clip: true
                            Behavior on height { NumberAnimation { duration: 200 } }
                            ScrollView {
                                anchors.fill: parent; clip: true
                                Loader {
                                    id: treeEditorLoader
                                    active: linkagePage.useTreeMode
                                    source: "qrc:/LinkageConditionNode.qml"
                                    onLoaded: {
                                        item.node = linkagePage.conditionTree
                                        item.depth = 0
                                        item.width = Qt.binding(function() { return treeEditorLoader.parent.width - 12 })
                                        item.nodeChanged.connect(function() { linkagePage.conditionTree = item.node })
                                    }
                                }
                            }
                        }
                        QtObject {
                            id: treeRootEditor
                            function refresh(n) {
                                if (treeEditorLoader.item) treeEditorLoader.item.refresh(n)
                            }
                        }
                        Row { spacing: 6
                            Button { text: "+ 添加 LEAF 子节点"; font.pixelSize: 12
                                enabled: linkagePage.useTreeMode
                                onClicked: {
                                    if (!linkagePage.conditionTree.children) linkagePage.conditionTree.children = []
                                    linkagePage.conditionTree.children.push({ node_type: "LEAF", leaf_type: "SOURCE", field: "event_type", op: "==", value: "" })
                                    treeRootEditor.refresh(linkagePage.conditionTree)
                                }
                                background: Rectangle { color: enabled ? "#3B82F6" : "#252830"; radius: 4; width: 150; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "+ 嵌入 OR 子组"; font.pixelSize: 12
                                enabled: linkagePage.useTreeMode
                                onClicked: {
                                    if (!linkagePage.conditionTree.children) linkagePage.conditionTree.children = []
                                    linkagePage.conditionTree.children.push({ node_type: "OR", children: [{ node_type: "LEAF", leaf_type: "SOURCE", field: "event_type", op: "==", value: "" }] })
                                    treeRootEditor.refresh(linkagePage.conditionTree)
                                }
                                background: Rectangle { color: enabled ? "#6C5CE7" : "#252830"; radius: 4; width: 150; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "从上面表单生成快照"; font.pixelSize: 12
                                enabled: linkagePage.useTreeMode
                                onClicked: {
                                    linkagePage.conditionTree = linkagePage.buildTreeFromFlat()
                                    treeRootEditor.refresh(linkagePage.conditionTree)
                                }
                                background: Rectangle { color: enabled ? "#FFB800" : "#252830"; radius: 4; width: 150; height: 24 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#0D0F12" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                // ═══ 联动动作 ═══
                Text { text: "联动动作"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // Tab: 客户端 | Web | APP | 小程序 | 系统
                TabBar {
                    id: actionTabBar
                    width: parent.width; height: 32
                    background: Rectangle { color: "#0D0F12"; radius: 4 }

                    TabButton { text: "客户端"; font.pixelSize: 12
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: actionTabBar.currentIndex === 0 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 0 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "Web端"; font.pixelSize: 12
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: actionTabBar.currentIndex === 1 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 1 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "APP"; font.pixelSize: 12
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: actionTabBar.currentIndex === 2 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 2 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "小程序"; font.pixelSize: 12
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: actionTabBar.currentIndex === 3 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 3 ? "#1A1D23" : "transparent"; radius: 4 } }
                    TabButton { text: "系统"; font.pixelSize: 12
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: actionTabBar.currentIndex === 4 ? "#00D4AA" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: actionTabBar.currentIndex === 4 ? "#1A1D23" : "transparent"; radius: 4 } }
                }

                StackLayout {
                    width: parent.width; currentIndex: actionTabBar.currentIndex

                    // ─── 客户端动作 (海康标准20+项) ───
                    ScrollView { clip: true
                        Column { id: clientActionColumn; width: 412; spacing: 2

                            Text { text: "视频联动"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "弹出指定监控点实时视频"; icon: "camera"; actionType: "CLIENT_SHOW_LIVE" }
                            ActionCheckRow { text: "弹出指定监控点录像回放"; icon: "record"; actionType: "CLIENT_SHOW_PLAYBACK" }
                            ActionCheckRow { text: "弹出事件图片"; icon: "image"; actionType: "CLIENT_SHOW_IMAGE" }
                            ActionCheckRow { text: "弹窗视频画面叠加事件信息"; icon: "folder"; actionType: "CLIENT_OVERLAY_INFO" }

                            Text { text: "音频联动"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "控制指定对讲通道语音对讲"; icon: "device"; actionType: "CLIENT_VOICE_TALK" }
                            ActionCheckRow { text: "播放提示音"; icon: "bell"; actionType: "CLIENT_PLAY_TONE" }
                            ActionCheckRow { text: "语音播报事件信息 (重复N次)"; icon: "bell"; actionType: "CLIENT_TTS_BROADCAST" }

                            Text { text: "显示联动"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "联动地图位置"; icon: "map"; actionType: "CLIENT_SHOW_MAP" }
                            ActionCheckRow { text: "指定监控点上电视墙 (持续N秒)"; icon: "device"; actionType: "CLIENT_TV_WALL" }
                            ActionCheckRow { text: "发生预警不弹窗 (静默)"; icon: "info"; actionType: "CLIENT_SUPPRESS_POPUP" }
                            ActionCheckRow { text: "执行事件处理预案"; icon: "folder"; actionType: "CLIENT_EXECUTE_PLAN" }

                            Text { text: "录像与抓图"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "视频录像 (持续N秒)"; icon: "record"; actionType: "CLIENT_RECORD_VIDEO" }
                            ActionCheckRow { text: "指定监控点事件录像"; icon: "camera"; actionType: "CLIENT_RECORD_EVENT" }
                            ActionCheckRow { text: "添加录像标记 (类型+描述)"; icon: "folder"; actionType: "CLIENT_ADD_BOOKMARK" }
                            ActionCheckRow { text: "间隔N秒抓图M次"; icon: "snapshot"; actionType: "CLIENT_CAPTURE_IMAGE" }

                            Text { text: "设备控制"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "控制指定报警输出"; icon: "alarm"; actionType: "CLIENT_ALARM_OUTPUT" }
                            ActionCheckRow { text: "控制云台"; icon: "tool"; actionType: "CLIENT_PTZ_CONTROL" }
                            ActionCheckRow { text: "事件开始转到预置点"; icon: "map"; actionType: "CLIENT_PTZ_PRESET_START" }
                            ActionCheckRow { text: "事件结束恢复到预置点"; icon: "refresh"; actionType: "CLIENT_PTZ_PRESET_END" }
                            ActionCheckRow { text: "调用巡航路径"; icon: "refresh"; actionType: "CLIENT_PTZ_CRUISE" }
                            ActionCheckRow { text: "调用轨迹"; icon: "stream"; actionType: "CLIENT_PTZ_TRACK" }
                            ActionCheckRow { text: "指定门禁点开门"; icon: "lock"; actionType: "CLIENT_ACCESS_OPEN" }

                            Text { text: "通知"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }

                            ActionCheckRow { text: "发送短信给指定用户"; icon: "send"; actionType: "CLIENT_SEND_SMS" }
                            ActionCheckRow { text: "发送邮件给指定用户"; icon: "send"; actionType: "CLIENT_SEND_EMAIL" }
                            ActionCheckRow { text: "指定IP进行指定模式报警"; icon: "federation"; actionType: "CLIENT_ALARM_MODE" }
                            ActionCheckRow { text: "逐级推送 (每N秒未解决推送至下一级)"; icon: "upload"; actionType: "CLIENT_ESCALATE" }
                        }
                    }

                    // ─── Web端 ───
                    ScrollView { clip: true
                        Column { id: webActionColumn; width: 412; spacing: 2
                            Text { text: "基础通知"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "Web端弹窗通知"; icon: "send"; actionType: "WEB_POPUP" }
                            ActionCheckRow { text: "发送邮件"; icon: "send"; actionType: "WEB_EMAIL" }
                            ActionCheckRow { text: "HTTP回调 (WebHook)"; icon: "linkage"; actionType: "WEB_WEBHOOK" }
                            ActionCheckRow { text: "Dashboard嵌入告警"; icon: "statistics"; actionType: "WEB_DASHBOARD_ALERT" }

                            Text { text: "视频联动"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "Web端弹出实时视频"; icon: "camera"; actionType: "WEB_SHOW_LIVE" }
                            ActionCheckRow { text: "Web端弹出录像回放"; icon: "record"; actionType: "WEB_SHOW_PLAYBACK" }
                            ActionCheckRow { text: "Web端弹出事件图片"; icon: "image"; actionType: "WEB_SHOW_IMAGE" }
                            ActionCheckRow { text: "Web端事件录像"; icon: "camera"; actionType: "WEB_RECORD_EVENT" }

                            Text { text: "音频联动"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "Web端播放提示音"; icon: "bell"; actionType: "WEB_PLAY_TONE" }
                            ActionCheckRow { text: "Web端语音播报"; icon: "bell"; actionType: "WEB_TTS_BROADCAST" }

                            Text { text: "抓图与通知"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "Web端抓图"; icon: "snapshot"; actionType: "WEB_CAPTURE_IMAGE" }
                            ActionCheckRow { text: "Web端发送短信"; icon: "send"; actionType: "WEB_SEND_SMS" }
                        }
                    }

                    // ─── APP ───
                    ScrollView { clip: true
                        Column { id: appActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "APP推送通知"; icon: "bell"; actionType: "APP_PUSH_NOTIFY" }
                            ActionCheckRow { text: "APP弹实时视频"; icon: "camera"; actionType: "APP_SHOW_LIVE" }
                            ActionCheckRow { text: "APP弹事件图片"; icon: "image"; actionType: "APP_SHOW_IMAGE" }
                            ActionCheckRow { text: "APP弹录像回放"; icon: "record"; actionType: "APP_SHOW_PLAYBACK" }
                            ActionCheckRow { text: "APP处置按钮"; icon: "check"; actionType: "APP_HANDLE_DISPOSE" }
                        }
                    }

                    // ─── 小程序 ───
                    ScrollView { clip: true
                        Column { id: mpActionColumn; width: 412; spacing: 2
                            ActionCheckRow { text: "小程序订阅消息"; icon: "send"; actionType: "MP_SUBSCRIBE_MSG" }
                            ActionCheckRow { text: "小程序弹事件图片"; icon: "image"; actionType: "MP_SHOW_IMAGE" }
                            ActionCheckRow { text: "小程序弹实时视频"; icon: "camera"; actionType: "MP_SHOW_LIVE" }
                        }
                    }

                    // ─── 系统 ───
                    ScrollView { clip: true
                        Column { id: sysActionColumn; width: 412; spacing: 2
                            Text { text: "工业协议"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "MQTT消息发布"; icon: "gb28181"; actionType: "SYS_MQTT_PUBLISH" }
                            ActionCheckRow { text: "Modbus写寄存器"; icon: "onvif"; actionType: "SYS_MODBUS_WRITE" }
                            ActionCheckRow { text: "ONVIF事件触发"; icon: "linkage"; actionType: "SYS_ONVIF_TRIGGER" }
                            ActionCheckRow { text: "继电器开关"; icon: "alarm"; actionType: "SYS_RELAY_SWITCH" }

                            Text { text: "上层转发"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "HTTP回调"; icon: "federation"; actionType: "SYS_HTTP_CALLBACK" }
                            ActionCheckRow { text: "转发到云端"; icon: "upload"; actionType: "SYS_CLOUD_FORWARD" }

                            // 端到端闭环: 告警触发推理回写事件 (规范 a45b219c Hermes v6.0)
                            Text { text: "推理/流闭环 (Hermes v6.0)"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true; topPadding: 4 }
                            ActionCheckRow { text: "启动推理通道"; icon: "play"; actionType: "SYS_START_INFERENCE" }
                            ActionCheckRow { text: "停止推理通道"; icon: "stop"; actionType: "SYS_STOP_INFERENCE" }
                            ActionCheckRow { text: "启动拉流"; icon: "download"; actionType: "SYS_START_STREAM" }
                            ActionCheckRow { text: "停止拉流"; icon: "upload"; actionType: "SYS_STOP_STREAM" }
                            ActionCheckRow { text: "部署 Pipeline"; icon: "play"; actionType: "SYS_DEPLOY_PIPELINE" }
                            ActionCheckRow { text: "卸载 Pipeline"; icon: "stop"; actionType: "SYS_UNDEPLOY_PIPELINE" }
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
                    Button { text: "保存规则"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 110; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            var ruleData = collectRuleData()
                            ruleData.id = ruleIdField.text
                            if (!ruleData.id) ruleData.rule_id = ruleIdField.text
                            // 严格校验 (使用 createRuleChecked / updateRuleChecked, 走 addRuleChecked 路径)
                            if (editingRule) {
                                linkageController.updateRuleChecked(editingRule.id || editingRule.rule_id, ruleData)
                            } else {
                                linkageController.createRuleChecked(ruleData)
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
        AppIcon { name: actionRow.icon; size: 14; iconColor: cb.checked ? "#00D4AA" : "#4A4D58"; visible: actionRow.icon !== ""; anchors.verticalCenter: parent.verticalCenter }
        Text { text: actionRow.text; font.pixelSize: 12; color: cb.checked ? "#E8E8E8" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter; width: 300; elide: Text.ElideRight }
        Button { text: "配置"; font.pixelSize: 12; visible: cb.checked; anchors.verticalCenter: parent.verticalCenter
            background: Rectangle { color: "transparent" }
            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#3B82F6" }
        }
    }

    // ─── 条件树节点编辑器已迁移到独立文件 LinkageConditionNode.qml ───
    // 原因: Qt 6 内联 component 不允许自递归, 独立文件支持无限嵌套

    // ═══ P3.4: 规则导出弹窗 ═══
    Popup {
        id: exportDialog
        anchors.centerIn: parent; width: 560; height: 480
        background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }
        property string exportText: ""

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            Row {
                spacing: 8
                Text { text: "联动规则导出"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Item { width: 280 }
                AppIcon { name: "close"; size: 16; iconColor: "#8B8FA3"
                    MouseArea { anchors.fill: parent; onClicked: exportDialog.close() } }
            }

            Component.onCompleted: {
                var data = { version: "1.0", exportTime: new Date().toISOString(), rules: rules }
                exportDialog.exportText = JSON.stringify(data, null, 2)
            }

            ScrollView {
                width: parent.width; height: 340; clip: true
                TextArea {
                    id: exportArea
                    width: parent.width; height: 340
                    readOnly: true
                    text: exportDialog.exportText
                    color: "#00D4AA"; font.family: "monospace"; font.pixelSize: 12
                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                    wrapMode: TextArea.Wrap
                }
            }

            Row {
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "复制到剪贴板"; font.pixelSize: 12
                    background: Rectangle { color: "#3B82F6"; radius: 6; width: 120; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { exportArea.selectAll(); exportArea.copy() }
                }
                Button {
                    text: "关闭"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: exportDialog.close()
                }
            }
        }
    }

    // ═══ P3.4: 规则导入弹窗 ═══
    Popup {
        id: importDialog
        anchors.centerIn: parent; width: 560; height: 420
        background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            Row {
                spacing: 8
                Text { text: "联动规则导入"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Item { width: 280 }
                AppIcon { name: "close"; size: 16; iconColor: "#8B8FA3"
                    MouseArea { anchors.fill: parent; onClicked: importDialog.close() } }
            }

            Text { text: "粘贴 JSON 格式的规则数据:"; font.pixelSize: 12; color: "#8B8FA3" }

            ScrollView {
                width: parent.width; height: 280; clip: true
                TextArea {
                    id: importArea
                    width: parent.width; height: 280
                    placeholderText: '{"version":"1.0","rules":[...]}'
                    color: "#E8E8E8"; font.family: "monospace"; font.pixelSize: 12
                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                    wrapMode: TextArea.Wrap
                }
            }

            Row {
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "解析并导入"; font.pixelSize: 12
                    background: Rectangle { color: "#00D4AA"; radius: 6; width: 120; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        try {
                            var data = JSON.parse(importArea.text)
                            if (data.rules && Array.isArray(data.rules)) {
                                for (var i = 0; i < data.rules.length; i++) {
                                    linkageController.createLinkage(data.rules[i])
                                }
                                importDialog.close()
                                importArea.text = ""
                            }
                        } catch(e) {
                            console.log("Import error:", e)
                        }
                    }
                }
                Button {
                    text: "取消"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: importDialog.close()
                }
            }
        }
    }
}
