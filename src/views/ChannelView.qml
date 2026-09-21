// ========================================================================
// ChannelView.qml — 通道管理 (1:1 对齐 Web 端 /channels 截图)
//   - 工具栏: 搜索 + 按设备/状态/协议筛选 + 卡片/列表切换 + 共N个通道 + 刷新
//   - 列表视图: 通道号/通道名称/所属设备/状态/编码/分辨率/帧率/算法/操作 + 分页
//   - 卡片视图: CH badge + 基本信息 + 性能指标 + 算法配置 + 操作按钮
//   - 数据源: box-sdk REST GET/PUT/DELETE /api/v1/channels
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // [P2-1 2026-09-20] REST 基址统一走 ApiClient (默认 http://127.0.0.1:18080):
    //   原硬编码 8080 端口为设备平台服务(sophliteos, 实测 /api 404), 请求必然失败
    //   —— 统一改由 apiClient.baseUrl 提供。
    readonly property string apiBase: apiClient.baseUrl

    // ── 状态 ──
    property var allChannels: []        // 原始通道数据 (来自 REST)
    property bool loading: false
    property string loadError: ""
    property string viewMode: "card"    // "card" | "list"
    property string searchKey: ""
    property string filterDevice: ""    // device_id, 空=全部
    property string filterStatus: ""    // "" | "online" | "offline"
    property string filterProtocol: ""  // "" | "gb28181" | ...
    property string sortKey: ""         // "" | "no" | "name"
    property bool sortAsc: true
    property int curPage: 1
    property int pageSize: 20

    property var renameTarget: null
    property var deleteTarget: null

    Component.onCompleted: loadChannels()

    // ── REST ──
    function xhrRequest(method, url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var obj = null
                try { obj = JSON.parse(xhr.responseText) } catch (e) {}
                cb(xhr.status, obj)
            }
        }
        xhr.send(body ? JSON.stringify(body) : null)
    }

    function loadChannels() {
        loading = true
        loadError = ""
        xhrRequest("GET", apiBase + "/api/v1/channels?limit=500", null,
            function (status, resp) {
                loading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    allChannels = d.channels || d.items || []
                    if (curPage > totalPages()) curPage = Math.max(1, totalPages())
                } else {
                    allChannels = []
                    loadError = "通道数据加载失败 (后端服务不可用或返回异常)"
                }
            })
    }

    function doRename(chId, newName) {
        xhrRequest("PUT", apiBase + "/api/v1/channels/" + encodeURIComponent(chId),
            { id: chId, channel_id: chId, name: newName },
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("重命名成功")
                    loadChannels()
                } else {
                    showToast("重命名失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function doDelete(chId) {
        xhrRequest("DELETE", apiBase + "/api/v1/channels/" + encodeURIComponent(chId),
            { id: chId },
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("通道已删除")
                    loadChannels()
                } else {
                    showToast("删除失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    // ── 过滤 / 排序 / 分页 ──
    function filteredList() {
        var list = []
        for (var i = 0; i < allChannels.length; i++) {
            var ch = allChannels[i]
            var name = ch.name || ""
            var cid = String(ch.channel_id || "")
            if (searchKey.length > 0
                && name.toLowerCase().indexOf(searchKey.toLowerCase()) < 0
                && cid.toLowerCase().indexOf(searchKey.toLowerCase()) < 0)
                continue
            if (filterDevice.length > 0 && String(ch.device_id || "") !== filterDevice)
                continue
            if (filterStatus.length > 0 && String(ch.status || "") !== filterStatus)
                continue
            if (filterProtocol.length > 0 && String(ch.protocol || "").toLowerCase() !== filterProtocol.toLowerCase())
                continue
            list.push(ch)
        }
        if (sortKey === "no") {
            list.sort(function (a, b) {
                return sortAsc ? (a.channelNo || 0) - (b.channelNo || 0)
                               : (b.channelNo || 0) - (a.channelNo || 0)
            })
        } else if (sortKey === "name") {
            list.sort(function (a, b) {
                var s = String(a.name || "").localeCompare(String(b.name || ""))
                return sortAsc ? s : -s
            })
        }
        return list
    }

    function totalPages() {
        return Math.max(1, Math.ceil(filteredList().length / pageSize))
    }

    function pageList() {
        var list = filteredList()
        var start = (curPage - 1) * pageSize
        return list.slice(start, start + pageSize)
    }

    function deviceOptions() {
        var seen = {}
        var opts = []
        for (var i = 0; i < allChannels.length; i++) {
            var did = String(allChannels[i].device_id || "")
            if (did.length > 0 && !seen[did]) { seen[did] = true; opts.push(did) }
        }
        return opts
    }

    function protocolOptions() {
        var seen = {}
        var opts = []
        for (var i = 0; i < allChannels.length; i++) {
            var p = String(allChannels[i].protocol || "").toUpperCase()
            if (p.length > 0 && !seen[p]) { seen[p] = true; opts.push(p) }
        }
        return opts
    }

    function toggleSort(key) {
        if (sortKey === key) sortAsc = !sortAsc
        else { sortKey = key; sortAsc = true }
    }

    function algoText(ch) {
        var a = ch.algoPlugin || ch.algo_plugin || ""
        if (a === "" || a === "无" || a === "null") return ""
        return a
    }

    function rootWindowGoto(idx) {
        // root 定义在 main.qml, 通过 Window attached property 访问
        try {
            var w = root.Window.window
            if (w) w.sidebarCurrentIndex = idx
        } catch (e) {
            console.warn("[ChannelView] goto page failed:", e)
        }
    }

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    function chLabel(ch) {
        return (ch.channelNo !== undefined) ? ("CH" + ch.channelNo) : "CH-"
    }

    // ═══ 页面骨架 ═══
    Rectangle {
        anchors.fill: parent
        color: "#F5F7FA"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── 页标题 ──
        Text {
            text: "通道管理"
            font.pixelSize: 18
            font.bold: true
            color: "#303133"
        }

        // ── 工具栏卡片 ──
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#FFFFFF"
            radius: 4
            border.color: "#EBEEF5"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // 搜索框
                Rectangle {
                    Layout.preferredWidth: 230
                    Layout.preferredHeight: 32
                    radius: 4
                    color: "#FFFFFF"
                    border.color: searchField.activeFocus ? "#409EFF" : "#DCDFE6"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6
                        AppIcon { name: "search"; size: 14; iconColor: "#C0C4CC" }
                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            font.pixelSize: 13
                            color: "#303133"
                            clip: true
                            onTextChanged: { root.searchKey = text; root.curPage = 1 }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "搜索通道名称/ID…"
                                color: "#C0C4CC"
                                font.pixelSize: 13
                                visible: searchField.text === "" && !searchField.activeFocus
                            }
                        }
                    }
                }

                // 按设备筛选
                LightCombo {
                    id: deviceCombo
                    Layout.preferredWidth: 190
                    defaultLabel: "按设备筛选"
                    optionModel: root.deviceOptions()
                    onOptionSelected: function(opt) {
                        root.filterDevice = (opt === "按设备筛选") ? "" : opt
                        root.curPage = 1
                    }
                }

                // 按状态
                LightCombo {
                    id: statusCombo
                    Layout.preferredWidth: 110
                    defaultLabel: "按状态"
                    optionModel: ["在线", "离线"]
                    onOptionSelected: function(opt) {
                        root.filterStatus = (opt === "在线") ? "online" : (opt === "离线") ? "offline" : ""
                        root.curPage = 1
                    }
                }

                // 按协议
                LightCombo {
                    id: protocolCombo
                    Layout.preferredWidth: 120
                    defaultLabel: "按协议"
                    optionModel: root.protocolOptions()
                    onOptionSelected: function(opt) {
                        root.filterProtocol = (opt === "按协议") ? "" : opt
                        root.curPage = 1
                    }
                }

                // 卡片/列表切换
                Row {
                    Layout.preferredHeight: 32
                    spacing: 0
                    ViewToggleBtn {
                        label: "卡片"
                        selected: root.viewMode === "card"
                        leftSide: true
                        onTap: root.viewMode = "card"
                    }
                    ViewToggleBtn {
                        label: "列表"
                        selected: root.viewMode === "list"
                        leftSide: false
                        onTap: root.viewMode = "list"
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "共 " + root.filteredList().length + " 个通道"
                    font.pixelSize: 13
                    color: "#909399"
                }

                // 刷新按钮
                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 32
                    radius: 4
                    color: refreshMa.containsMouse ? "#ECF5FF" : "#FFFFFF"
                    border.color: refreshMa.containsMouse ? "#B3D8FF" : "#DCDFE6"

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        AppIcon { name: "refresh"; size: 14; iconColor: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "刷新"; font.pixelSize: 13; color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.loadChannels()
                    }
                }
            }
        }

        // ── 加载态 / 错误态 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.loading || root.loadError !== ""
            color: "#FFFFFF"
            radius: 4
            border.color: "#EBEEF5"

            Column {
                anchors.centerIn: parent
                spacing: 10
                BusyIndicator { running: root.loading; anchors.horizontalCenter: parent.horizontalCenter }
                Text {
                    visible: root.loading
                    text: "加载中…"
                    font.pixelSize: 13
                    color: "#909399"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    visible: !root.loading && root.loadError !== ""
                    text: root.loadError
                    font.pixelSize: 13
                    color: "#F56C6C"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Rectangle {
                    visible: !root.loading && root.loadError !== ""
                    width: retryRow.width + 24; height: 30; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: retryMa.containsMouse ? "#ECF5FF" : "#FFFFFF"
                    border.color: "#DCDFE6"
                    Row {
                        id: retryRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "重试"; font.pixelSize: 13; color: "#409EFF" }
                    }
                    MouseArea { id: retryMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.loadChannels() }
                }
            }
        }

        // ── 列表视图 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.viewMode === "list" && !root.loading && root.loadError === ""
            color: "#FFFFFF"
            radius: 4
            border.color: "#EBEEF5"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 表头
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    color: "#F5F7FA"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 0
                        ThCell { text: "通道号"; cellWidth: 80; sortable: true; onClicked: root.toggleSort("no") }
                        ThCell { text: "通道名称"; fill: true; sortable: true; onClicked: root.toggleSort("name") }
                        ThCell { text: "所属设备"; cellWidth: 200 }
                        ThCell { text: "状态"; cellWidth: 80 }
                        ThCell { text: "编码"; cellWidth: 90 }
                        ThCell { text: "分辨率"; cellWidth: 110 }
                        ThCell { text: "帧率"; cellWidth: 60 }
                        ThCell { text: "算法"; cellWidth: 110 }
                        ThCell { text: "操作"; cellWidth: 150 }
                    }
                }

                // 表体
                ListView {
                    id: tableView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.pageList()

                    delegate: Rectangle {
                        width: tableView.width
                        height: 48
                        color: rowMa.containsMouse ? "#F5F7FA" : "#FFFFFF"

                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: 1; color: "#EBEEF5"
                        }

                        MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 0

                            // 通道号
                            Text { text: modelData.channelNo !== undefined ? String(modelData.channelNo) : "-"; width: 80; font.pixelSize: 13; color: "#606266" }
                            // 通道名称
                            Text { text: modelData.name || "-"; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; color: "#303133" }
                            // 所属设备 (超长省略)
                            Text { text: String(modelData.device_id || "-"); width: 200; elide: Text.ElideMiddle; font.pixelSize: 13; color: "#606266" }
                            // 状态 tag
                            Item {
                                width: 80; height: 48
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: statusTagText.implicitWidth + 16; height: 22; radius: 3
                                    color: (modelData.status === "online") ? "#F0F9EB" : "#F4F4F5"
                                    border.color: (modelData.status === "online") ? "#E1F3D8" : "#E9E9EB"
                                    Text {
                                        id: statusTagText
                                        anchors.centerIn: parent
                                        text: (modelData.status === "online") ? "在线" : "离线"
                                        font.pixelSize: 12
                                        color: (modelData.status === "online") ? "#67C23A" : "#909399"
                                    }
                                }
                            }
                            // 编码 tag
                            Item {
                                width: 90; height: 48
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: codecTagText.implicitWidth + 16; height: 22; radius: 3
                                    color: "#ECF5FF"
                                    border.color: "#D9ECFF"
                                    Text {
                                        id: codecTagText
                                        anchors.centerIn: parent
                                        text: modelData.codec || "-"
                                        font.pixelSize: 12
                                        color: "#409EFF"
                                    }
                                }
                            }
                            // 分辨率
                            Text { text: modelData.resolution || "-"; width: 110; font.pixelSize: 13; color: "#606266" }
                            // 帧率
                            Text { text: modelData.fps !== undefined ? String(modelData.fps) : "-"; width: 60; font.pixelSize: 13; color: "#606266" }
                            // 算法
                            Text {
                                width: 110; elide: Text.ElideRight
                                text: root.algoText(modelData).length > 0 ? root.algoText(modelData) : "-"
                                font.pixelSize: 13; color: "#606266"
                            }
                            // 操作
                            Row {
                                width: 150; spacing: 10
                                OpIconBtn { icon: "play"; tip: "预览"; color: "#409EFF"; onTap: root.rootWindowGoto(1) }
                                OpIconBtn { icon: "info"; tip: "详情"; color: "#909399"; onTap: { root.viewMode = "card" } }
                                OpIconBtn { icon: "edit"; tip: "重命名"; color: "#E6A23C"; onTap: { root.renameTarget = modelData; renameField.text = modelData.name || ""; renameDialog.visible = true } }
                                OpIconBtn { icon: "delete"; tip: "删除"; color: "#F56C6C"; onTap: { root.deleteTarget = modelData; deleteDialog.visible = true } }
                            }
                        }
                    }

                    // 空态
                    Column {
                        visible: tableView.count === 0
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon { name: "channel"; size: 40; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            text: "暂无通道"
                            font.pixelSize: 13
                            color: "#909399"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // 分页条
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: "#FFFFFF"
                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10

                        Text { text: "共 " + root.filteredList().length + " 条"; font.pixelSize: 13; color: "#606266" }

                        LightCombo {
                            id: pageSizeCombo
                            Layout.preferredWidth: 100
                            defaultLabel: root.pageSize + "条/页"
                            optionModel: ["10条/页", "20条/页", "50条/页"]
                            onOptionSelected: function(opt) {
                                root.pageSize = parseInt(opt) || 20
                                root.curPage = 1
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // 页码导航
                        Row {
                            spacing: 4
                            PageBtn { label: "<"; enabled: root.curPage > 1; onTap: root.curPage-- }
                            PageBtn { label: String(root.curPage); active: true; onTap: {} }
                            PageBtn { label: ">"; enabled: root.curPage < root.totalPages(); onTap: root.curPage++ }
                        }

                        Text { text: "前往"; font.pixelSize: 13; color: "#606266" }
                        Rectangle {
                            width: 44; height: 28; radius: 4
                            border.color: jumpInput.activeFocus ? "#409EFF" : "#DCDFE6"
                            TextInput {
                                id: jumpInput
                                anchors.fill: parent
                                anchors.margins: 4
                                font.pixelSize: 13
                                color: "#303133"
                                horizontalAlignment: TextInput.AlignHCenter
                                validator: IntValidator { bottom: 1 }
                                onAccepted: {
                                    var p = parseInt(text) || 1
                                    root.curPage = Math.min(Math.max(1, p), root.totalPages())
                                }
                            }
                        }
                        Text { text: "页"; font.pixelSize: 13; color: "#606266" }
                    }
                }
            }
        }

        // ── 卡片视图 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.viewMode === "card" && !root.loading && root.loadError === ""
            color: "transparent"

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: cardColWrap.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cardColWrap
                    width: parent.width
                    spacing: 12

                    Grid {
                        id: cardGrid
                        width: parent.width
                        spacing: 12
                        columns: Math.max(1, Math.floor(width / 440))

                        Repeater {
                            id: cardRepeater
                            model: root.pageList()
                            delegate: ChannelCard { ch: modelData }
                        }
                    }

                    // 空态
                    Rectangle {
                        visible: cardRepeater.count === 0
                        width: parent.width
                        height: 160
                        radius: 4
                        color: "#FFFFFF"
                        border.color: "#EBEEF5"
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            AppIcon { name: "channel"; size: 40; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text {
                                text: "暂无通道"
                                font.pixelSize: 13
                                color: "#909399"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // 分页条 (卡片视图同样显示, 对齐截图)
                    Rectangle {
                        visible: root.filteredList().length > 0
                        width: parent.width
                        height: 48
                        radius: 4
                        color: "#FFFFFF"
                        border.color: "#EBEEF5"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 10

                            Text { text: "共 " + root.filteredList().length + " 条"; font.pixelSize: 13; color: "#606266" }

                            LightCombo {
                                Layout.preferredWidth: 100
                                defaultLabel: root.pageSize + "条/页"
                                optionModel: ["10条/页", "20条/页", "50条/页"]
                                onOptionSelected: function(opt) {
                                    root.pageSize = parseInt(opt) || 20
                                    root.curPage = 1
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 4
                                PageBtn { label: "<"; enabled: root.curPage > 1; onTap: root.curPage-- }
                                PageBtn { label: String(root.curPage); active: true; onTap: {} }
                                PageBtn { label: ">"; enabled: root.curPage < root.totalPages(); onTap: root.curPage++ }
                            }

                            Text { text: "前往"; font.pixelSize: 13; color: "#606266" }
                            Rectangle {
                                width: 44; height: 28; radius: 4
                                border.color: cardJumpInput.activeFocus ? "#409EFF" : "#DCDFE6"
                                TextInput {
                                    id: cardJumpInput
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    font.pixelSize: 13
                                    color: "#303133"
                                    horizontalAlignment: TextInput.AlignHCenter
                                    validator: IntValidator { bottom: 1 }
                                    onAccepted: {
                                        var p = parseInt(text) || 1
                                        root.curPage = Math.min(Math.max(1, p), root.totalPages())
                                    }
                                }
                            }
                            Text { text: "页"; font.pixelSize: 13; color: "#606266" }
                        }
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component ThCell: Item {
        property alias text: thText.text
        property bool sortable: false
        property bool fill: false
        property int cellWidth: 100
        signal clicked()
        Layout.fillWidth: fill
        Layout.preferredWidth: fill ? 0 : cellWidth
        Layout.fillHeight: true
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text { id: thText; font.pixelSize: 13; font.bold: true; color: "#909399" }
            AppIcon { visible: sortable; name: "sort"; size: 12; iconColor: "#C0C4CC"; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: parent; cursorShape: sortable ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: parent.clicked() }
    }

    component OpIconBtn: Item {
        property string icon: "play"
        property string tip: ""
        property color color: "#409EFF"
        signal tap()
        width: 24; height: 48
        AppIcon {
            anchors.centerIn: parent
            name: icon
            size: 16
            iconColor: opBtnMa.containsMouse ? Qt.darker(color, 1.2) : color
        }
        MouseArea {
            id: opBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tap()
        }
        ToolTip.visible: opBtnMa.containsMouse && tip !== ""
        ToolTip.text: tip
        ToolTip.delay: 300
    }

    component ViewToggleBtn: Rectangle {
        property string label: ""
        property bool selected: false
        property bool leftSide: true
        signal tap()
        width: 56; height: 32
        radius: 0
        color: selected ? "#409EFF" : (vtMa.containsMouse ? "#ECF5FF" : "#FFFFFF")
        border.color: selected ? "#409EFF" : "#DCDFE6"
        Text {
            anchors.centerIn: parent
            text: label
            font.pixelSize: 13
            color: selected ? "#FFFFFF" : "#606266"
        }
        MouseArea { id: vtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tap() }
    }

    component PageBtn: Rectangle {
        property string label: ""
        property bool active: false
        signal tap()
        width: 28; height: 28; radius: 4
        color: active ? "#409EFF" : (pbMa.containsMouse ? "#F5F7FA" : "#FFFFFF")
        border.color: active ? "#409EFF" : "#DCDFE6"
        Text { anchors.centerIn: parent; text: label; font.pixelSize: 13; color: active ? "#FFFFFF" : "#606266" }
        MouseArea { id: pbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tap() }
    }

    // ═══ LightCombo (浅色下拉) ═══
    component LightCombo: Item {
        id: comboRoot
        property string defaultLabel: ""
        property var optionModel: []
        property string current: ""
        signal optionSelected(string opt)
        implicitWidth: 120
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#FFFFFF"
            border.color: comboMa.containsMouse ? "#C0C4CC" : "#DCDFE6"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: comboRoot.current !== "" ? comboRoot.current : comboRoot.defaultLabel
                    font.pixelSize: 13
                    color: comboRoot.current !== "" ? "#303133" : "#909399"
                    elide: Text.ElideRight
                }
                AppIcon { name: "chevronDown"; size: 12; iconColor: "#C0C4CC" }
            }

            MouseArea {
                id: comboMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: comboPopup.visible ? comboPopup.close() : comboPopup.open()
            }
        }

        Popup {
            id: comboPopup
            y: comboRoot.height + 4
            width: Math.max(comboRoot.width, 170)
            padding: 5
            background: Rectangle {
                color: "#FFFFFF"
                radius: 4
                border.color: "#E4E7ED"
            }

            Column {
                width: parent.width
                Repeater {
                    model: [comboRoot.defaultLabel].concat(comboRoot.optionModel)
                    delegate: Rectangle {
                        width: comboPopup.width - 10
                        height: 30
                        radius: 3
                        color: comboItemMa.containsMouse ? "#F5F7FA" : "transparent"
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                            color: (modelData === comboRoot.current) ? "#409EFF"
                                 : (modelData === comboRoot.defaultLabel && comboRoot.current === "") ? "#909399"
                                 : "#606266"
                        }
                        MouseArea {
                            id: comboItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData === comboRoot.defaultLabel) {
                                    comboRoot.current = ""
                                    comboRoot.optionSelected(comboRoot.defaultLabel)
                                } else {
                                    comboRoot.current = modelData
                                    comboRoot.optionSelected(modelData)
                                }
                                comboPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ ChannelCard (卡片视图单元, 对齐截图) ═══
    component ChannelCard: Rectangle {
        id: card
        property var ch: ({})
        property bool recording: false
        Component.onCompleted: recording = (ch && ch.isRecording === true)

        width: 428
        height: cardBody.implicitHeight + 32
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"

        Column {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // ── 头部: CH badge + 名称 + 状态 + 停止 ──
            Row {
                spacing: 10
                Rectangle {
                    width: chBadgeText.implicitWidth + 14
                    height: 22
                    radius: 3
                    color: "#409EFF"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: chBadgeText
                        anchors.centerIn: parent
                        text: card.ch.channelNo !== undefined ? ("CH" + card.ch.channelNo) : "CH"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FFFFFF"
                    }
                }
                Text {
                    text: card.ch.name || card.ch.channel_id || "-"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#303133"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: cardStatusText.implicitWidth + 16
                    height: 24
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: (card.ch.status === "online") ? "#F0F9EB" : "#F4F4F5"
                    border.color: (card.ch.status === "online") ? "#E1F3D8" : "#E9E9EB"
                    Text {
                        id: cardStatusText
                        anchors.centerIn: parent
                        text: (card.ch.status === "online") ? "在线" : "离线"
                        font.pixelSize: 12
                        color: (card.ch.status === "online") ? "#67C23A" : "#909399"
                    }
                }
                Rectangle {
                    width: 52
                    height: 24
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: stopMa.containsMouse ? "#F5F7FA" : "#FFFFFF"
                    border.color: "#DCDFE6"
                    Text { anchors.centerIn: parent; text: "停止"; font.pixelSize: 12; color: "#909399" }
                    MouseArea {
                        id: stopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mediaController.stopAllStreams()
                            if (card.recording) {
                                mediaController.stopRecording(String(card.ch.channel_id || ""))
                                card.recording = false
                            }
                            root.showToast("已停止")
                        }
                    }
                }
            }

            // ── 基本信息 ──
            Row {
                spacing: 6
                Rectangle { width: 3; height: 14; color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "基本信息"; font.pixelSize: 14; font.bold: true; color: "#303133" }
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 20
                rowSpacing: 8
                InfoItem { itemLabel: "通道号"; itemValue: card.ch.channelNo !== undefined ? String(card.ch.channelNo) : "-" }
                InfoItem { itemLabel: "分辨率"; itemValue: card.ch.resolution || "-" }
                InfoItem { itemLabel: "帧率"; itemValue: card.ch.fps !== undefined ? (card.ch.fps + " fps") : "-" }
                InfoItem { itemLabel: "RTSP 地址"; itemValue: card.ch.rtspUrl || card.ch.source_url || "-" }
                InfoItem { itemLabel: "通道名称"; itemValue: card.ch.name || "-" }
                // 编码格式 (蓝色 badge)
                Item {
                    width: 188
                    height: 20
                    Row {
                        spacing: 8
                        Text { text: "编码格式"; font.pixelSize: 13; color: "#909399"; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: codecBadge.implicitWidth + 14
                            height: 20
                            radius: 3
                            color: "#ECF5FF"
                            border.color: "#D9ECFF"
                            Text { id: codecBadge; anchors.centerIn: parent; text: card.ch.codec || "-"; font.pixelSize: 12; color: "#409EFF" }
                        }
                    }
                }
                InfoItem { itemLabel: "码率"; itemValue: card.ch.bitrate || "-" }
                InfoItem { itemLabel: "丢包率"; itemValue: (card.ch.packetLoss !== undefined && card.ch.packetLoss !== "") ? (card.ch.packetLoss + "%") : "-" }
            }

            Rectangle { width: parent.width; height: 1; color: "#EBEEF5" }

            // ── 性能指标 ──
            Row {
                spacing: 6
                Rectangle { width: 3; height: 14; color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "性能指标"; font.pixelSize: 14; font.bold: true; color: "#303133" }
            }
            Row {
                width: parent.width
                spacing: 48
                MetricItem { metricValue: card.ch.bitrate || "-"; metricLabel: "码率" }
                MetricItem {
                    metricValue: (card.ch.status === "online" && card.ch.latency !== undefined) ? (card.ch.latency + " ms") : "-"
                    metricLabel: "延迟"
                    valueColor: "#409EFF"
                }
                MetricItem { metricValue: (card.ch.packetLoss !== undefined && card.ch.packetLoss !== "") ? (card.ch.packetLoss + "%") : "-"; metricLabel: "丢包率" }
            }

            Rectangle { width: parent.width; height: 1; color: "#EBEEF5" }

            // ── 算法配置 ──
            Row {
                spacing: 6
                Rectangle { width: 3; height: 14; color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "算法配置"; font.pixelSize: 14; font.bold: true; color: "#303133" }
            }
            Row {
                spacing: 8
                Text { text: "当前算法:"; font.pixelSize: 13; color: "#606266" }
                Text {
                    text: root.algoText(card.ch).length > 0 ? root.algoText(card.ch) : "未配置"
                    font.pixelSize: 13
                    color: root.algoText(card.ch).length > 0 ? "#303133" : "#909399"
                }
            }

            // ── 操作按钮 ──
            Row {
                spacing: 8
                CardBtn { label: "实时预览"; filled: true; onTap: root.rootWindowGoto(1) }
                CardBtn { label: "截图"; onTap: { mediaController.snapshotToFile(String(card.ch.channel_id || "")); root.showToast("截图已保存") } }
                CardBtn {
                    label: card.recording ? "停止录像" : "开始录像"
                    danger: card.recording
                    onTap: {
                        var cid = String(card.ch.channel_id || "")
                        if (card.recording) {
                            mediaController.stopRecording(cid)
                            card.recording = false
                            root.showToast("录像已停止")
                        } else {
                            mediaController.startRecording(cid)
                            card.recording = true
                            root.showToast("开始录像")
                        }
                    }
                }
                CardBtn {
                    label: "更多 ▾"
                    onTap: {
                        moreMenu.card = card.ch
                        moreMenu.popup()
                    }
                }
            }
        }
    }

    component InfoItem: Item {
        property string itemLabel: ""
        property string itemValue: "-"
        width: 188
        height: 20
        Row {
            spacing: 8
            Text { text: itemLabel; font.pixelSize: 13; color: "#909399"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: itemValue
                font.pixelSize: 13
                color: "#303133"
                width: 120
                elide: Text.ElideMiddle
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component MetricItem: Column {
        property string metricValue: "-"
        property string metricLabel: ""
        property color valueColor: "#303133"
        spacing: 4
        Text { text: metricValue; font.pixelSize: 18; font.bold: true; color: valueColor }
        Text { text: metricLabel; font.pixelSize: 12; color: "#909399" }
    }

    component CardBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property bool danger: false
        property bool dangerFilled: false
        signal tap()
        width: cardBtnText.implicitWidth + 24
        height: 32
        radius: 4
        color: filled ? (cardBtnMa.containsMouse ? "#66B1FF" : "#409EFF")
             : dangerFilled ? (cardBtnMa.containsMouse ? "#F78989" : "#F56C6C")
             : (cardBtnMa.containsMouse ? "#F5F7FA" : "#FFFFFF")
        border.color: filled ? "#409EFF" : dangerFilled ? "#F56C6C" : (danger ? "#FDE2E2" : "#DCDFE6")
        Text {
            id: cardBtnText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 13
            color: (filled || dangerFilled) ? "#FFFFFF" : (danger ? "#F56C6C" : "#606266")
        }
        MouseArea {
            id: cardBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tap()
        }
    }

    // ═══ “更多” 菜单 (卡片视图) ═══
    Menu {
        id: moreMenu
        property var card: null
        MenuItem {
            text: "详情"
            onTriggered: { /* 卡片视图即详情, 无额外动作 */ }
        }
        MenuItem {
            text: "重命名"
            onTriggered: {
                if (moreMenu.card) {
                    root.renameTarget = moreMenu.card
                    renameField.text = moreMenu.card.name || ""
                    renameDialog.visible = true
                }
            }
        }
        MenuItem {
            text: "删除"
            onTriggered: {
                if (moreMenu.card) {
                    root.deleteTarget = moreMenu.card
                    deleteDialog.visible = true
                }
            }
        }
    }

    // ═══ 重命名弹窗 ═══
    Rectangle {
        id: renameDialog
        visible: false
        anchors.fill: parent
        color: "#80000000"
        z: 100
        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 420
            height: 190
            anchors.centerIn: parent
            radius: 4
            color: "#FFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Text { text: "重命名通道"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                Text {
                    text: "通道 ID: " + (root.renameTarget ? String(root.renameTarget.channel_id || "") : "")
                    font.pixelSize: 12
                    color: "#909399"
                }
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 4
                    border.color: renameField.activeFocus ? "#409EFF" : "#DCDFE6"
                    TextInput {
                        id: renameField
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 13
                        color: "#303133"
                        focus: true
                    }
                }
                Item { width: 1; height: 1 }
                Row {
                    spacing: 10
                    anchors.right: parent.right
                    CardBtn { label: "取消"; onTap: renameDialog.visible = false }
                    CardBtn {
                        label: "确定"
                        filled: true
                        onTap: {
                            if (root.renameTarget && renameField.text.trim().length > 0) {
                                root.doRename(String(root.renameTarget.channel_id || ""), renameField.text.trim())
                                renameDialog.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 删除确认弹窗 ═══
    Rectangle {
        id: deleteDialog
        visible: false
        anchors.fill: parent
        color: "#80000000"
        z: 100
        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 400
            height: 170
            anchors.centerIn: parent
            radius: 4
            color: "#FFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Row {
                    spacing: 8
                    AppIcon { name: "warning"; size: 18; iconColor: "#E6A23C" }
                    Text { text: "删除通道"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "确定删除通道 \"" + (root.deleteTarget ? (root.deleteTarget.name || root.deleteTarget.channel_id) : "") + "\" 吗？删除后不可恢复。"
                    font.pixelSize: 13
                    color: "#606266"
                }
                Item { width: 1; height: 1 }
                Row {
                    spacing: 10
                    anchors.right: parent.right
                    CardBtn { label: "取消"; onTap: deleteDialog.visible = false }
                    CardBtn {
                        label: "删除"
                        dangerFilled: true
                        onTap: {
                            if (root.deleteTarget) {
                                root.doDelete(String(root.deleteTarget.channel_id || ""))
                                deleteDialog.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ Toast ═══
    Rectangle {
        id: toastBox
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: toastMsg.implicitWidth + 32
        height: 36
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"
        z: 200
        Text {
            id: toastMsg
            anchors.centerIn: parent
            font.pixelSize: 13
            color: "#606266"
        }
    }
    Timer {
        id: toastTimer
        interval: 2500
        onTriggered: toastBox.visible = false
    }
}
