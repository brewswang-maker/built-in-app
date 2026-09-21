// ========================================================================
// AlgorithmView.qml — 算法商城 (1:1 对齐 Web AlgorithmStoreView)
// 端点:
//   GET  /api/v1/marketplace/algorithms?page&pageSize&sortBy&keyword&category
//   GET  /api/v1/marketplace/categories
//   GET  /api/v1/marketplace/orders
//   GET  /api/v1/marketplace/licenses
//   POST /api/v1/marketplace/algorithms/:id/install
// 原则: 后端无对应字段时如实显示 "-"，不伪造数据
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

    property bool loading: false
    property string searchKeyword: ""
    property string sortBy: "rating"
    property string activeCategory: "all"
    property var categories: []          // [{key,name,count}]
    property var products: []            // 后端原始算法列表
    property int totalCount: 0
    property var purchasedIds: []        // 已购算法 id
    property var selectedProduct: null
    property bool purchasing: false
    property string toastMsg: ""

    readonly property var sortOptions: [
        { label: "最高评分",       value: "rating" },
        { label: "最多下载",       value: "popular" },
        { label: "价格从低到高",   value: "price_asc" },
        { label: "价格从高到低",   value: "price_desc" },
        { label: "最新发布",       value: "newest" }
    ]

    function xhrRequest(method, url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var resp = null
                try { resp = JSON.parse(xhr.responseText) } catch (e) { resp = null }
                cb(resp, xhr.status)
            }
        }
        xhr.send(body ? JSON.stringify(body) : null)
    }

    function showToast(msg) {
        toastMsg = msg
        toastTimer.restart()
    }

    function categoryName(key) {
        for (var i = 0; i < categories.length; i++)
            if (categories[i].key === key) return categories[i].name
        return key || ""
    }

    function isPurchased(id) { return purchasedIds.indexOf(id) >= 0 }

    function formatCount(c) {
        if (c >= 10000) return (c / 10000).toFixed(1) + "w"
        if (c >= 1000) return (c / 1000).toFixed(1) + "k"
        return String(c)
    }

    function priceLabel(p) {
        var price = p.price
        if (price === undefined || price === null) return "-"
        if (price <= 0) return "免费"
        return "¥" + price.toFixed(0)
    }

    function priceTagColor(p) {
        var price = p.price
        if (price === undefined || price === null) return "#909399"
        return price <= 0 ? "#67C23A" : "#E6A23C"
    }

    // ── 数据加载 ──
    function fetchCategories() {
        xhrRequest("GET", apiBase + "/api/v1/marketplace/categories", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data)
                categories = Array.isArray(resp.data) ? resp.data : []
        })
    }

    function fetchProducts() {
        loading = true
        var url = apiBase + "/api/v1/marketplace/algorithms?page=1&pageSize=100"
        if (activeCategory !== "all") url += "&category=" + activeCategory
        xhrRequest("GET", url, null, function(resp) {
            loading = false
            if (resp && (resp.code === 0 || resp.success === true) && resp.data) {
                var list = resp.data.items || resp.data.algorithms || []
                totalCount = resp.data.total !== undefined ? resp.data.total : list.length
                // 客户端排序 (后端忽略 sortBy)
                var sorted = list.slice()
                if (sortBy === "rating") sorted.sort(function(a, b) { return (b.rating || 0) - (a.rating || 0) })
                else if (sortBy === "popular") sorted.sort(function(a, b) { return (b.downloads || 0) - (a.downloads || 0) })
                else if (sortBy === "price_asc") sorted.sort(function(a, b) { return (a.price || 0) - (b.price || 0) })
                else if (sortBy === "price_desc") sorted.sort(function(a, b) { return (b.price || 0) - (a.price || 0) })
                else if (sortBy === "newest") sorted.sort(function(a, b) { return (b.createdAt || "").localeCompare(a.createdAt || "") })
                // 客户端关键词过滤 (后端不支持)
                var kw = searchKeyword.trim().toLowerCase()
                if (kw.length > 0) {
                    sorted = sorted.filter(function(p) {
                        var hay = ((p.name || "") + " " + (p.vendor || "") + " " + (p.description || "") + " " + ((p.tags || []).join(" "))).toLowerCase()
                        return hay.indexOf(kw) >= 0
                    })
                }
                products = sorted
            } else {
                products = []
                totalCount = 0
            }
        })
    }

    function fetchLicenses() {
        xhrRequest("GET", apiBase + "/api/v1/marketplace/licenses?page=1&pageSize=200", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data) {
                var list = resp.data.items || resp.data.licenses || []
                var ids = []
                for (var i = 0; i < list.length; i++) {
                    var aid = list[i].algorithmId || list[i].pluginId || ""
                    if (aid && ids.indexOf(aid) < 0) ids.push(aid)
                }
                purchasedIds = ids
            }
        })
    }

    function selectCategory(id) {
        activeCategory = id
        fetchProducts()
    }

    function openDetail(p) {
        selectedProduct = p
        detailPopup.open()
    }

    function handlePurchase() {
        if (!selectedProduct) return
        purchasing = true
        var p = selectedProduct
        xhrRequest("POST", apiBase + "/api/v1/marketplace/algorithms/" + p.id + "/install", {}, function(resp) {
            purchasing = false
            if (resp && (resp.code === 0 || resp.success === true)) {
                var free = (p.price === undefined || p.price === null || p.price <= 0)
                if (free) {
                    if (purchasedIds.indexOf(p.id) < 0) purchasedIds = purchasedIds.concat([p.id])
                    detailPopup.close()
                    showToast("获取成功")
                } else {
                    // 付费算法: 后端仅提供下载队列，无真实支付能力，如实提示
                    showToast("已加入下载队列，支付功能当前不可用")
                }
                fetchLicenses()
            } else {
                showToast((resp && resp.message) ? resp.message : "获取失败")
            }
        })
    }

    Component.onCompleted: {
        fetchCategories()
        fetchProducts()
        fetchLicenses()
    }

    // ════════════════ 页面主体 ════════════════
    Rectangle {
        anchors.fill: parent
        color: "#F5F7FA"
    }

    Flickable {
        id: pageScroll
        anchors.fill: parent
        contentHeight: mainCol.height + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: mainCol
            x: 16; y: 16
            width: parent.width - 32
            spacing: 16

            // ── 筛选卡片 ──
            Rectangle {
                width: parent.width; height: filterCol.height + 40
                color: "#FFFFFF"; radius: 4
                border.color: "#EBEEF5"; border.width: 1

                Column {
                    id: filterCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 20

                    // 头部: 搜索框 | 排序 | 计数
                    Row {
                        width: parent.width; spacing: 16

                        // 搜索框
                        Rectangle {
                            width: (parent.width - 32) / 3; height: 40
                            color: "#FFFFFF"; radius: 4
                            border.color: "#DCDFE6"; border.width: 1

                            Row {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 6
                                AppIcon { name: "search"; size: 15; iconColor: "#C0C4CC"; anchors.verticalCenter: parent.verticalCenter }
                                TextInput {
                                    id: searchInput
                                    width: parent.width - 60; height: parent.height
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: 14; color: "#303133"
                                    selectByMouse: true
                                    onTextChanged: root.searchKeyword = text
                                    Keys.onReturnPressed: root.fetchProducts()
                                    Keys.onEnterPressed: root.fetchProducts()
                                    Text {
                                        text: "搜索算法名称、标签、厂商..."
                                        color: "#A8ABB2"; font.pixelSize: 14
                                        visible: searchInput.displayText.length === 0
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                AppIcon {
                                    name: "close"; size: 13; iconColor: "#C0C4CC"
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchInput.displayText.length > 0
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: { searchInput.text = ""; root.searchKeyword = ""; root.fetchProducts() }
                                    }
                                }
                            }
                        }

                        // 排序下拉
                        Rectangle {
                            id: sortBox
                            width: (parent.width - 32) / 3; height: 40
                            color: "#FFFFFF"; radius: 4
                            border.color: sortMa.containsMouse ? "#C0C4CC" : "#DCDFE6"; border.width: 1

                            Row {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 6
                                Text {
                                    text: {
                                        for (var i = 0; i < sortOptions.length; i++)
                                            if (sortOptions[i].value === sortBy) return sortOptions[i].label
                                        return "排序方式"
                                    }
                                    color: "#303133"; font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24; elide: Text.ElideRight
                                }
                                AppIcon { name: "chevronDown"; size: 13; iconColor: "#A8ABB2"; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: sortMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sortPopup.open() }

                            Popup {
                                id: sortPopup
                                x: 0; y: sortBox.height + 4
                                width: sortBox.width; padding: 5
                                background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED"; layer.enabled: true; layer.effect: Item {} }
                                Column {
                                    width: parent.width
                                    Repeater {
                                        model: sortOptions
                                        delegate: Rectangle {
                                            width: parent.width - 10; height: 34; radius: 4
                                            color: sortOptMa.containsMouse ? "#F5F7FA" : "transparent"
                                            Text {
                                                text: modelData.label
                                                color: modelData.value === sortBy ? "#409EFF" : "#606266"
                                                font.pixelSize: 14; font.bold: modelData.value === sortBy
                                                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10
                                            }
                                            MouseArea {
                                                id: sortOptMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { sortBy = modelData.value; sortPopup.close(); root.fetchProducts() }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 计数 tag
                        Item { width: (parent.width - 32) / 3; height: 40 }
                    }

                    Item { width: 1; height: 16 }

                    // 分类条
                    Flickable {
                        width: parent.width; height: 32; clip: true
                        contentWidth: catRow.width
                        boundsBehavior: Flickable.StopAtBounds
                        Row {
                            id: catRow; spacing: 8; height: 32

                            // 全部
                            Rectangle {
                                width: allCatText.implicitWidth + 24; height: 30; radius: 4
                                color: activeCategory === "all" ? "#409EFF" : "#FFFFFF"
                                border.color: activeCategory === "all" ? "#409EFF" : "#E9E9EB"; border.width: 1
                                Text {
                                    id: allCatText; text: "全部"; font.pixelSize: 14
                                    color: activeCategory === "all" ? "#FFFFFF" : "#909399"
                                    anchors.centerIn: parent
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectCategory("all") }
                            }

                            Repeater {
                                model: categories
                                delegate: Rectangle {
                                    width: catText.implicitWidth + 24; height: 30; radius: 4
                                    color: activeCategory === modelData.key ? "#409EFF" : "#FFFFFF"
                                    border.color: activeCategory === modelData.key ? "#409EFF" : "#E9E9EB"; border.width: 1
                                    Text {
                                        id: catText
                                        // Web 端读取 algorithmCount 字段，后端无此字段 → 如实显示空括号
                                        text: modelData.name + " ()"
                                        font.pixelSize: 14
                                        color: activeCategory === modelData.key ? "#FFFFFF" : "#909399"
                                        anchors.centerIn: parent
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectCategory(modelData.key) }
                                }
                            }
                        }
                    }
                }

                // 计数 tag (头部右侧)
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 20
                    anchors.top: parent.top; anchors.topMargin: 20
                    width: countText.implicitWidth + 24; height: 40; radius: 4
                    color: "#FFFFFF"; border.color: "#E9E9EB"; border.width: 1
                    Text {
                        id: countText
                        text: "共 " + totalCount + " 个算法 · 已购买 " + purchasedIds.length + " 个"
                        font.pixelSize: 14; color: "#909399"
                        anchors.centerIn: parent
                    }
                }
            }

            // ── 商品列表卡片 ──
            Rectangle {
                width: parent.width
                height: productArea.height + 40
                color: "#FFFFFF"; radius: 4
                border.color: "#EBEEF5"; border.width: 1

                Column {
                    id: productArea
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 20

                    // 加载中
                    Column {
                        visible: loading
                        width: parent.width; spacing: 10

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"; border.color: "#409EFF"; border.width: 3
                            Rectangle { width: 20; height: 12; color: "#FFFFFF"; anchors.top: parent.top; anchors.topMargin: -2; anchors.horizontalCenter: parent.horizontalCenter }
                            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; running: loading; loops: Animation.Infinite }
                        }
                        Text { text: "加载中..."; color: "#909399"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }
                        Item { width: 1; height: 40 }
                    }

                    // 空态
                    Column {
                        visible: !loading && products.length === 0
                        width: parent.width; spacing: 12
                        AppIcon { name: "algorithm"; size: 56; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "未找到匹配的算法"; color: "#606266"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                        Item { width: 1; height: 40 }
                    }

                    // 商品网格
                    Grid {
                        visible: !loading && products.length > 0
                        width: parent.width
                        columns: Math.max(1, Math.floor(parent.width / 280))
                        spacing: 16

                        Repeater {
                            model: products
                            delegate: ProductCard {
                                width: Math.floor((productArea.width - 16 * (Math.max(1, Math.floor(productArea.width / 280)) - 1)) / Math.max(1, Math.floor(productArea.width / 280)))
                                product: modelData
                                purchased: isPurchased(modelData.id)
                                catName: categoryName(modelData.category)
                                priceTxt: priceLabel(modelData)
                                priceColor: priceTagColor(modelData)
                                downloadsTxt: modelData.downloads !== undefined ? formatCount(modelData.downloads) : "-"
                                ratingTxt: modelData.rating !== undefined ? Number(modelData.rating).toFixed(1) : "-"
                                onCardClicked: openDetail(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 算法详情弹窗 ═══
    Popup {
        id: detailPopup
        anchors.centerIn: parent
        width: 680; height: detailCol.implicitHeight + 130
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5" }

        Column {
            id: detailCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top

            // 标题栏
            Rectangle {
                width: parent.width; height: 54; color: "#FFFFFF"
                Text {
                    text: selectedProduct ? (selectedProduct.name || "算法详情") : "算法详情"
                    font.pixelSize: 18; font.bold: true; color: "#303133"
                    anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
                }
                AppIcon {
                    name: "close"; size: 16; iconColor: "#909399"
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: detailPopup.close() }
                }
                Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
            }

            // 描述表格 (2列)
            Grid {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.right: parent.right; anchors.rightMargin: 20
                columns: 2
                columnSpacing: 0; rowSpacing: 0

                Repeater {
                    model: selectedProduct ? [
                        { label: "版本",     value: selectedProduct.version !== undefined ? String(selectedProduct.version) : "-" },
                        { label: "厂商",     value: selectedProduct.vendor || "-" },
                        { label: "分类",     value: categoryName(selectedProduct.category) || "-" },
                        { label: "定价模式", value: (selectedProduct.price === undefined || selectedProduct.price === null) ? "-" : (selectedProduct.price <= 0 ? "免费" : "一次性买断") },
                        { label: "价格",     value: priceLabel(selectedProduct) },
                        { label: "平均延迟", value: "-" },
                        { label: "下载次数", value: selectedProduct.downloads !== undefined ? String(selectedProduct.downloads) : "-" },
                        { label: "评分",     value: selectedProduct.rating !== undefined ? Number(selectedProduct.rating).toFixed(1) : "-" },
                        { label: "精度",     value: "-" },
                        { label: "TPU显存",  value: selectedProduct.sizeMb !== undefined ? selectedProduct.sizeMb + "MB" : "-" },
                        { label: "状态",     value: isPurchased(selectedProduct.id) ? "已购买" : "未购买" }
                    ] : []
                    delegate: Rectangle {
                        width: (parent.width) / 2; height: 40
                        color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
                            Text {
                                text: modelData.label
                                color: "#909399"; font.pixelSize: 13
                                width: 64; anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.value
                                color: modelData.label === "状态"
                                       ? (isPurchased(selectedProduct ? selectedProduct.id : "") ? "#67C23A" : "#E6A23C")
                                       : "#606266"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // 标签
            Row {
                anchors.left: parent.left; anchors.leftMargin: 20
                spacing: 6
                topPadding: 12
                visible: selectedProduct && (selectedProduct.tags || []).length > 0
                Repeater {
                    model: selectedProduct ? (selectedProduct.tags || []) : []
                    delegate: Rectangle {
                        width: tagText.implicitWidth + 14; height: 24; radius: 3
                        color: "#FFFFFF"; border.color: "#E9E9EB"; border.width: 1
                        Text { id: tagText; text: modelData; color: "#909399"; font.pixelSize: 12; anchors.centerIn: parent }
                    }
                }
            }

            // 详细说明
            Column {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.right: parent.right; anchors.rightMargin: 20
                spacing: 12
                topPadding: 20
                Text { text: "详细说明"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                Text {
                    text: selectedProduct ? (selectedProduct.description || "-") : "-"
                    width: parent.width; wrapMode: Text.WordWrap
                    font.pixelSize: 13; color: "#606266"; lineHeight: 1.6
                }
            }

            Item { width: 1; height: 20 }

            // 底部按钮
            Rectangle {
                width: parent.width; height: 64; color: "#FFFFFF"
                Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: closeTxt.implicitWidth + 32; height: 36; radius: 4
                        color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                        Text { id: closeTxt; text: "关闭"; color: "#606266"; font.pixelSize: 14; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: detailPopup.close() }
                    }

                    Rectangle {
                        visible: selectedProduct && !isPurchased(selectedProduct.id)
                        width: buyTxt.implicitWidth + 32; height: 36; radius: 4
                        color: purchasing ? "#A0CFFF" : "#409EFF"
                        Text {
                            id: buyTxt
                            text: purchasing ? "处理中..." : (selectedProduct && selectedProduct.price !== undefined && selectedProduct.price > 0 ? "立即购买" : "免费获取")
                            color: "#FFFFFF"; font.pixelSize: 14; anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: purchasing ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: { if (!purchasing) handlePurchase() }
                        }
                    }

                    Rectangle {
                        visible: selectedProduct && isPurchased(selectedProduct.id)
                        width: boughtTxt.implicitWidth + 32; height: 36; radius: 4
                        color: "#F0F9EB"; border.color: "#E1F3D8"; border.width: 1
                        Text { id: boughtTxt; text: "已购买"; color: "#67C23A"; font.pixelSize: 14; anchors.centerIn: parent }
                    }
                }
            }
        }
    }

    // ═══ Toast ═══
    Rectangle {
        visible: toastMsg.length > 0
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24
        width: toastText.implicitWidth + 40; height: 40; radius: 4; z: 99
        color: "#FFFFFF"; border.color: "#E1F3D8"; border.width: 1
        Row {
            anchors.centerIn: parent; spacing: 8
            AppIcon { name: "check"; size: 15; iconColor: "#67C23A"; anchors.verticalCenter: parent.verticalCenter }
            Text { id: toastText; text: toastMsg; color: "#606266"; font.pixelSize: 14 }
        }
        Timer { id: toastTimer; interval: 2500; onTriggered: toastMsg = "" }
    }

    // ═══ 商品卡片组件 ═══
    component ProductCard: Rectangle {
        id: cardRoot
        property var product: null
        property bool purchased: false
        property string catName: ""
        property string priceTxt: "-"
        property string priceColor: "#909399"
        property string downloadsTxt: "-"
        property string ratingTxt: "-"
        signal cardClicked()
        height: 244; radius: 8
        color: "#FFFFFF"
        border.color: purchased ? "#67C23A" : (cardMa.containsMouse ? "#D9ECFF" : "#EBEEF5")
        border.width: 1

        MouseArea { id: cardMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.cardClicked() }

        Column {
            anchors.fill: parent

            // 封面
            Rectangle {
                width: parent.width; height: 120
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#667eea" }
                    GradientStop { position: 1.0; color: "#764ba2" }
                }

                // 占位图标
                Rectangle {
                    width: 64; height: 64; radius: 16
                    color: "#33FFFFFF"
                    anchors.centerIn: parent
                    AppIcon { name: "algorithm"; size: 40; iconColor: "#409EFF"; anchors.centerIn: parent }
                }

                // 价格徽标
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8
                    width: priceBadgeText.implicitWidth + 14; height: 22; radius: 3
                    color: cardRoot.priceColor
                    Text { id: priceBadgeText; text: cardRoot.priceTxt; color: "#FFFFFF"; font.pixelSize: 12; anchors.centerIn: parent }
                }

                // 已拥有徽标
                Rectangle {
                    visible: purchased
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                    width: ownedText.implicitWidth + 16; height: 22; radius: 11
                    color: "#67C23A"
                    Text { id: ownedText; text: "✓ 已拥有"; color: "#FFFFFF"; font.pixelSize: 12; anchors.centerIn: parent }
                }
            }

            // 信息区
            Column {
                width: parent.width; padding: 12; spacing: 6

                Text {
                    text: product ? (product.name || "") : ""
                    width: parent.width - 24; elide: Text.ElideRight
                    font.pixelSize: 15; font.bold: true; color: "#303133"
                }
                Text {
                    text: product ? (product.description || "") : ""
                    width: parent.width - 24; elide: Text.ElideRight
                    font.pixelSize: 12; color: "#909399"
                }

                Row {
                    spacing: 16
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        AppIcon { name: "sort"; size: 12; iconColor: "#E6A23C" }
                        Text { text: cardRoot.ratingTxt; font.pixelSize: 12; color: "#606266" }
                    }
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        AppIcon { name: "download"; size: 12; iconColor: "#606266" }
                        Text { text: cardRoot.downloadsTxt; font.pixelSize: 12; color: "#606266" }
                    }
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        AppIcon { name: "warning"; size: 12; iconColor: "#606266" }
                        // 后端无 avgLatencyMs 字段，如实显示 "-"
                        Text { text: "-ms"; font.pixelSize: 12; color: "#606266" }
                    }
                }

                Row {
                    width: parent.width - 24; spacing: 8
                    Rectangle {
                        width: cardCatText.implicitWidth + 14; height: 22; radius: 3
                        color: "#F4F4F5"
                        Text { id: cardCatText; text: catName; color: "#909399"; font.pixelSize: 12; anchors.centerIn: parent }
                    }
                    Item { width: 1; height: 1 }
                    Text {
                        text: product ? (product.vendor || "") : ""
                        color: "#C0C4CC"; font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - cardCatText.implicitWidth - 30
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
