// ========================================================================
// ActionParamDialog.qml — 联动动作参数配置弹窗 (P1-#1 v3.0 R1 补齐)
//
// 对标海康 iVMS-8700 / 大华 DSS / ONVIF Profile-G 动作参数化:
//   58 类 LinkageActionType 参数 schema SSOT (对标海康 iVMS-8700), 弹出此 dialog
//   接受 schema (box-sdk/data/action_schemas.json 形式) 动态渲染表单
//
// [V4-L5] 增强: 动作分类导航 + 搜索 + 实时模板预览 + 占位符提示
//
// 字段类型:
//   - string:  TextField (支持占位符提示)
//   - int:     SpinBox
//   - float:   TextField (数字校验)
//   - bool:    Switch
//   - enum:    ComboBox
//   - list:    TextField (JSON 格式)
//
// 用法:
//   ActionParamDialog {
//       id: paramDialog
//       actionType: "SYS_MQTT_PUBLISH"
//       schema: linkageController.actionSchemas["SYS_MQTT_PUBLISH"]
//       initialParams: rule.actions[0].params || ({})
//   }
//   paramDialog.open()
//
// 信号:
//   accepted(params): 用户点 OK, params 是合并后的参数 map
//   rejected(): 用户点 Cancel
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    title: "配置动作参数: " + (actionType || "")
    modal: true
    anchors.centerIn: parent
    width: Math.min(540, parent ? parent.width - 80 : 540)
    height: Math.min(620, parent ? parent.height - 80 : 620)
    standardButtons: Dialog.NoButton  // 我们用 footer 自定义按钮
    closePolicy: Popup.CloseOnEscape

    // ── 输入属性 ──
    property string actionType: ""
    property var schema: ({fields: []})
    property var initialParams: ({})

    // [V4-L5] 动作分类映射
    property var actionCategories: ({
        "CLIENT_": "客户端控制",
        "APP_":    "APP推送",
        "WEB_":    "Web端",
        "MP_":     "小程序",
        "SYS_":    "系统集成"
    })

    // [V4-L5] 获取当前动作的分类
    function _getCategory(typeStr) {
        for (var prefix in actionCategories) {
            if (typeStr.indexOf(prefix) === 0) return actionCategories[prefix]
        }
        return "其他"
    }

    // [V4-L5] 检测字符串中的模板占位符
    function _detectPlaceholders(text) {
        if (!text) return []
        var phs = []
        var re = /\$\{(\w+)\}/g
        var match
        while ((match = re.exec(text)) !== null) {
            if (phs.indexOf(match[1]) === -1) phs.push(match[1])
        }
        return phs
    }

    // [V4-L5] 预览模板渲染结果
    function _renderTemplate(template, sampleData) {
        if (!template) return ""
        var result = template
        var phs = _detectPlaceholders(template)
        for (var i = 0; i < phs.length; i++) {
            var val = sampleData[phs[i]]
            if (val !== undefined) {
                result = result.replace(new RegExp('\\$\\{' + phs[i] + '\\}', 'g'), val)
            } else {
                result = result.replace(new RegExp('\\$\\{' + phs[i] + '\\}', 'g'), '[' + phs[i] + ']')
            }
        }
        return result
    }

    // [V4-L5] 示例数据 (用于模板预览)
    property var _sampleData: ({
        alarm_type: "入侵告警",
        channel_id: 3,
        channel_name: "南门",
        device_name: "IPC-001",
        timestamp: "2026-07-09 14:30:00",
        confidence: "0.92",
        bbox: "[100,200,300,400]"
    })

    // ── 内部状态 ──
    property var fieldValues: ({})
    property var fieldErrors: ({})

    // ── 公开: 获取当前参数 ──
    function getCurrentParams() {
        var out = ({})
        if (schema && schema.fields) {
            for (var i = 0; i < schema.fields.length; i++) {
                var f = schema.fields[i]
                var v = fieldValues[f.name]
                if (v === undefined) v = f.default
                out[f.name] = v
            }
        }
        return out
    }

    // ── 公开: 校验所有字段 ──
    function validateAll() {
        fieldErrors = ({})
        if (!schema || !schema.fields) return true
        for (var i = 0; i < schema.fields.length; i++) {
            var f = schema.fields[i]
            var v = fieldValues[f.name]
            if (f.required && (v === undefined || v === null || v === "")) {
                fieldErrors[f.name] = "必填字段"
                return false
            }
            if (typeof v === "number") {
                if (f.min !== undefined && v < f.min) {
                    fieldErrors[f.name] = "不能小于 " + f.min
                    return false
                }
                if (f.max !== undefined && v > f.max) {
                    fieldErrors[f.name] = "不能大于 " + f.max
                    return false
                }
            }
        }
        return true
    }

    // ── 打开时初始化 ──
    onOpened: {
        fieldValues = ({})
        fieldErrors = ({})
        if (schema && schema.fields) {
            for (var i = 0; i < schema.fields.length; i++) {
                var f = schema.fields[i]
                var name = f.name
                var def = (initialParams && initialParams[name] !== undefined) ? initialParams[name] : f.default
                fieldValues[name] = def
            }
        }
    }

    // ── 头部: 动作类型 + 字段数 ──
    header: Rectangle {
        color: "#141720"
        implicitHeight: 56
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
            AppIcon { name: "settings"; size: 22; iconColor: "#3B82F6"; Layout.preferredWidth: 28 }
            Text {
                text: root.actionType || "(未指定)"
                font.pixelSize: 14; font.bold: true; color: "#E8E8E8"
            }
            // [V4-L5] 分类标签
            Rectangle {
                visible: root.actionType.length > 0
                radius: 10; color: "#3B82F620"
                border.color: "#3B82F6"; border.width: 1
                Layout.preferredHeight: 20
                Layout.preferredWidth: catLabel.implicitWidth + 16
                Text {
                    id: catLabel
                    anchors.centerIn: parent
                    text: root._getCategory(root.actionType)
                    font.pixelSize: 11; color: "#3B82F6"
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root.schema && root.schema.fields) ? (root.schema.fields.length + " 个字段") : "无参数"
                font.pixelSize: 12; color: "#8B8FA3"
            }
        }
    }

    // ── 主体: 滚动字段 ──
    contentItem: ColumnLayout {
        spacing: 6
        Label {
            text: "此动作无需配置参数"
            color: "#8B8FA3"
            font.pixelSize: 13
            visible: !(root.schema && root.schema.fields && root.schema.fields.length > 0)
        }
        ScrollView {
            id: paramScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Column {
                width: paramScroll.width
                spacing: 8
                padding: 12

                Repeater {
                    model: (root.schema && root.schema.fields) ? root.schema.fields : []
                    delegate: Column {
                        width: parent.width
                        spacing: 4
                        property var fieldData: modelData
                        property string fieldName: fieldData ? fieldData.name : ""
                        property bool hasError: root.fieldErrors[fieldName] !== undefined
                        property string errorMsg: hasError ? root.fieldErrors[fieldName] : ""

                        // 字段标签行
                        Row {
                            width: parent.width
                            spacing: 4
                            Text {
                                text: fieldData ? (fieldData.name + (fieldData.required ? " *" : "")) : ""
                                color: "#E8E8E8"; font.pixelSize: 12; font.bold: fieldData && fieldData.required
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: fieldData ? (fieldData.type + (fieldData.options ? " (" + fieldData.options.length + " 项)" : "")) : ""
                                color: "#4A4D58"; font.pixelSize: 11
                            }
                        }

                        // ── 输入控件: 按类型选择 (inline 5 种) ──
                        // 1) enum -> ComboBox
                        ComboBox {
                            id: enumInput
                            width: parent.width
                            visible: fieldData && fieldData.type === "enum"
                            model: fieldData && fieldData.options ? fieldData.options : []
                            currentIndex: {
                                if (!fieldData) return 0
                                var v = root.fieldValues[fieldName] !== undefined ? root.fieldValues[fieldName] : fieldData.default
                                if (v === undefined || v === null) return 0
                                var idx = model.indexOf(v)
                                return idx >= 0 ? idx : 0
                            }
                            onActivated: if (currentIndex >= 0) root.fieldValues[fieldName] = model[currentIndex]
                        }
                        // 2) int -> SpinBox
                        SpinBox {
                            id: intInput
                            width: parent.width
                            visible: fieldData && fieldData.type === "int"
                            from: fieldData && fieldData.min !== undefined ? fieldData.min : 0
                            to: fieldData && fieldData.max !== undefined ? fieldData.max : 9999999
                            value: root.fieldValues[fieldName] !== undefined ? root.fieldValues[fieldName] : (fieldData ? (fieldData.default || 0) : 0)
                            editable: true
                            onValueChanged: root.fieldValues[fieldName] = value
                        }
                        // 3) float -> TextField (数字校验)
                        TextField {
                            id: floatInput
                            width: parent.width
                            visible: fieldData && fieldData.type === "float"
                            color: "#E8E8E8"; font.pixelSize: 12
                            text: root.fieldValues[fieldName] !== undefined ? String(root.fieldValues[fieldName]) : (fieldData && fieldData.default !== undefined ? String(fieldData.default) : "")
                            background: Rectangle {
                                color: "#252830"; radius: 4
                                border.color: hasError ? "#FF3D71" : "transparent"
                                border.width: hasError ? 1 : 0
                            }
                            placeholderText: "浮点数"
                            onTextChanged: {
                                var n = parseFloat(text)
                                root.fieldValues[fieldName] = isNaN(n) ? text : n
                            }
                        }
                        // 4) bool -> Switch
                        Switch {
                            id: boolInput
                            width: parent.width
                            visible: fieldData && fieldData.type === "bool"
                            text: "启用"
                            checked: root.fieldValues[fieldName] !== undefined ? root.fieldValues[fieldName] : (fieldData ? (fieldData.default === true) : false)
                            onToggled: root.fieldValues[fieldName] = checked
                        }
                        // 5) string / list -> TextField
                        TextField {
                            id: textInput
                            width: parent.width
                            visible: fieldData && (fieldData.type === "string" || fieldData.type === "list" || !fieldData.type)
                            color: "#E8E8E8"; font.pixelSize: 12
                            text: root.fieldValues[fieldName] !== undefined ? String(root.fieldValues[fieldName]) : (fieldData && fieldData.default !== undefined ? String(fieldData.default) : "")
                            background: Rectangle {
                                color: "#252830"; radius: 4
                                border.color: hasError ? "#FF3D71" : "transparent"
                                border.width: hasError ? 1 : 0
                            }
                            placeholderText: fieldData ? (fieldData.description || fieldData.name) : ""
                            onTextChanged: {
                                var v = text
                                if (fieldData && fieldData.type === "int") {
                                    var i = parseInt(text)
                                    v = isNaN(i) ? text : i
                                } else if (fieldData && fieldData.type === "list") {
                                    try { v = JSON.parse(text) } catch (e) { v = text }
                                }
                                root.fieldValues[fieldName] = v
                            }
                        }

                        // 描述
                        Text {
                            width: parent.width
                            text: fieldData ? (fieldData.description || "") : ""
                            color: "#6C6F7C"; font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            visible: text.length > 0
                        }

                        // 错误提示
                        Rectangle {
                            width: parent.width
                            height: 18
                            color: "#3B1A1A"; radius: 4
                            visible: hasError
                            border.color: "#FF3D71"; border.width: 1
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 8
                                text: "⚠ " + errorMsg
                                color: "#FF8080"; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // [V4-L5] 模板预览区 (显示含占位符的字符串字段渲染效果)
    Rectangle {
        id: templatePreview
        visible: {
            if (!root.schema || !root.schema.fields) return false
            for (var i = 0; i < root.schema.fields.length; i++) {
                var f = root.schema.fields[i]
                var v = root.fieldValues[f.name]
                if (typeof v === "string" && root._detectPlaceholders(v).length > 0) return true
            }
            return false
        }
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        height: 72
        color: "#0D1117"
        border.color: "#252830"; border.width: 1

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: "#3B82F640"
        }

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            Text {
                text: "[V4-L5] 模板预览 (示例数据)"
                font.pixelSize: 11; color: "#3B82F6"; font.bold: true
            }

            ScrollView {
                width: parent.width; height: parent.height - 18
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: parent.width; spacing: 2

                    Repeater {
                        model: root.schema && root.schema.fields ? root.schema.fields : []

                        Text {
                            width: parent.width
                            visible: {
                                var v = root.fieldValues[modelData.name]
                                return typeof v === "string" && root._detectPlaceholders(v).length > 0
                            }
                            text: {
                                var v = root.fieldValues[modelData.name]
                                if (typeof v !== "string") return ""
                                var rendered = root._renderTemplate(v, root._sampleData)
                                return modelData.name + " → " + rendered
                            }
                            font.pixelSize: 11; color: "#55EFC4"
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    // ── footer: 自定义按钮 (Cancel + Reset + OK) ──
    footer: DialogButtonBox {
        background: Rectangle { color: "#0D0F12" }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            Button {
                text: "重置默认"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (schema && schema.fields) {
                        for (var i = 0; i < schema.fields.length; i++) {
                            var f = schema.fields[i]
                            fieldValues[f.name] = f.default
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "取消"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.reject()
            }
            Button {
                text: "保存"
                font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (root.validateAll()) {
                        // 触发 accepted 信号 (Dialog 标准), 携带最终参数
                        root.lastAcceptedParams = root.getCurrentParams()
                        root.accept()
                    } else {
                        console.warn("[ActionParamDialog] 校验失败:", JSON.stringify(root.fieldErrors))
                    }
                }
            }
        }
    }

    // ── 信号 ──
    signal acceptedParams(var params)
    property var lastAcceptedParams: ({})

    // 监听标准 accepted 事件, 转发到 acceptedParams
    onAccepted: {
        // 标准 OK 按钮触发, acceptedParams 已设置
        acceptedParams(getCurrentParams())
    }
}
