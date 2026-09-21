// ========================================================================
// MapPanel.qml — [P2-A 2026-09-21] 设备地理分布地图 (Canvas 自绘轻量实现)
// 调研结论 (执行期记录): 本机 /usr/lib/qt6/qml/ 无 QtLocation 模块, 且设备
//   离线环境无网红线/瓦片服务 → 降级为 Canvas 矢量自绘 (Locate3DPanel 同款
//   技术栈, 零外部依赖):
//   - 经纬度包围盒投影 + 经纬网格底图
//   - 设备点位 (在线绿/离线红/其它灰; 选中金色脉冲环)
//   - 点击点位 ↔ 设备列表 双向联动高亮
//   - 未配置坐标 (0,0 默认值) 的设备归入底部网格区, 如实区分不混入投影
// 数据源: DeviceController.devices (device_id/name/status/longitude/latitude)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: mapPanel
    color: "#04102E"

    // ── 外部输入: 设备数组 (QVariantList of map) ──
    property var devices: []

    // ── 联动状态: 双向高亮锚点 ──
    property string selectedDeviceId: ""

    // 有有效坐标 (非默认 0,0 且数值合法) 的设备
    readonly property var geoDevices: {
        var arr = []
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var lng = Number(d.longitude), lat = Number(d.latitude)
            if (isFinite(lng) && isFinite(lat) && !(lng === 0 && lat === 0))
                arr.push(d)
        }
        return arr
    }
    // 未配置坐标的设备 (底部网格区呈现, 不混入地理投影)
    readonly property var noGeoDevices: {
        var arr = []
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var lng = Number(d.longitude), lat = Number(d.latitude)
            if (!(isFinite(lng) && isFinite(lat) && !(lng === 0 && lat === 0)))
                arr.push(d)
        }
        return arr
    }

    // 状态→颜色 (对齐 Dashboard 设备状态配色)
    function statusColor(s) {
        return s === "online" ? "#17D71E" : s === "offline" ? "#FC4F55" : "#7D817B"
    }

    // 经纬度 → 画布投影 (留 40px 边距; 单点/零跨度时居中)
    function project(lng, lat, w, h) {
        var pad = 40
        var minLng = 1e9, maxLng = -1e9, minLat = 1e9, maxLat = -1e9
        for (var i = 0; i < geoDevices.length; i++) {
            var lo = Number(geoDevices[i].longitude), la = Number(geoDevices[i].latitude)
            if (lo < minLng) minLng = lo
            if (lo > maxLng) maxLng = lo
            if (la < minLat) minLat = la
            if (la > maxLat) maxLat = la
        }
        if (maxLng - minLng < 1e-6) { minLng -= 0.01; maxLng += 0.01 }
        if (maxLat - minLat < 1e-6) { minLat -= 0.01; maxLat += 0.01 }
        var x = pad + (lng - minLng) * (w - 2 * pad) / (maxLng - minLng)
        // 纬度向上 (北半球常规取向): y 轴翻转
        var y = h - pad - (lat - minLat) * (h - 2 * pad) / (maxLat - minLat)
        return { x: x, y: y }
    }

    onSelectedDeviceIdChanged: canvasMap.requestPaint()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // ── 主区: 地图 Canvas + 右侧设备列表 ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // 地图画布
            Canvas {
                id: canvasMap
                Layout.fillWidth: true
                Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    // 底图: 深蓝渐变 + 经纬网格 (12×8)
                    var g = ctx.createLinearGradient(0, 0, 0, height)
                    g.addColorStop(0, "#061A44")
                    g.addColorStop(1, "#030B24")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                    ctx.strokeStyle = Qt.rgba(0.02, 0.45, 0.9, 0.12)
                    ctx.lineWidth = 1
                    for (var gx = 0; gx <= 12; gx++) {
                        var x = width * gx / 12
                        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                    }
                    for (var gy = 0; gy <= 8; gy++) {
                        var y = height * gy / 8
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                    }

                    // 空态: 全部设备均无坐标时给出提示
                    if (geoDevices.length === 0) {
                        ctx.fillStyle = "#236DB7"
                        ctx.textAlign = "center"
                        ctx.font = "14px sans-serif"
                        ctx.fillText("暂无已配置坐标的设备 (设备管理中配置经纬度后展示分布)",
                                     width / 2, height / 2)
                        return
                    }

                    // 点位 + 标签
                    for (var i = 0; i < geoDevices.length; i++) {
                        var d = geoDevices[i]
                        var p = project(Number(d.longitude), Number(d.latitude), width, height)
                        var c = statusColor(d.status)
                        var sel = String(d.device_id) === selectedDeviceId

                        if (sel) {
                            // 选中: 金色脉冲双环
                            ctx.strokeStyle = "#FFD54A"
                            ctx.lineWidth = 2
                            ctx.beginPath(); ctx.arc(p.x, p.y, 13, 0, 2 * Math.PI); ctx.stroke()
                            ctx.strokeStyle = Qt.rgba(1, 0.84, 0.29, 0.45)
                            ctx.beginPath(); ctx.arc(p.x, p.y, 19, 0, 2 * Math.PI); ctx.stroke()
                        }
                        ctx.fillStyle = c
                        ctx.beginPath(); ctx.arc(p.x, p.y, sel ? 7 : 5, 0, 2 * Math.PI); ctx.fill()
                        // 外圈描边增强可视性
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.35)
                        ctx.lineWidth = 1
                        ctx.beginPath(); ctx.arc(p.x, p.y, sel ? 7 : 5, 0, 2 * Math.PI); ctx.stroke()

                        // 标签
                        ctx.fillStyle = sel ? "#FFD54A" : "#8FC7FF"
                        ctx.textAlign = "center"
                        ctx.font = (sel ? "bold " : "") + "11px sans-serif"
                        ctx.fillText(String(d.name || d.device_id), p.x, p.y - 14)
                    }

                    // 图例
                    ctx.textAlign = "left"
                    ctx.font = "11px sans-serif"
                    ctx.fillStyle = "#17D71E"; ctx.fillRect(10, height - 20, 8, 8)
                    ctx.fillStyle = "#8FC7FF"; ctx.fillText("在线", 22, height - 12)
                    ctx.fillStyle = "#FC4F55"; ctx.fillRect(62, height - 20, 8, 8)
                    ctx.fillStyle = "#8FC7FF"; ctx.fillText("离线", 74, height - 12)
                    ctx.fillStyle = "#7D817B"; ctx.fillRect(126, height - 20, 8, 8)
                    ctx.fillStyle = "#8FC7FF"; ctx.fillText("其它", 138, height - 12)
                }
                onMouseClicked: {
                    // 命中检测: 选中半径内最近点位
                    var best = -1, bestDist = 16 * 16
                    for (var i = 0; i < geoDevices.length; i++) {
                        var d = geoDevices[i]
                        var p = project(Number(d.longitude), Number(d.latitude), width, height)
                        var dx = p.x - mouse.x, dy = p.y - mouse.y
                        var dist = dx * dx + dy * dy
                        if (dist < bestDist) { bestDist = dist; best = i }
                    }
                    selectedDeviceId = best >= 0 ? String(geoDevices[best].device_id) : ""
                }
                Connections {
                    target: mapPanel
                    function onDevicesChanged() { canvasMap.requestPaint() }
                }
                Component.onCompleted: requestPaint()
            }

            // 设备列表 (联动高亮)
            Rectangle {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                color: "#061A44"
                border.color: "#0A2C6E"
                border.width: 1
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Text {
                        text: "设备 (" + devices.length + ")"
                        color: "#00B4FF"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    ListView {
                        id: deviceList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: devices
                        currentIndex: -1
                        highlightFollowsCurrentItem: true
                        delegate: Rectangle {
                            width: deviceList.width
                            height: 30
                            radius: 3
                            property string devId: String(modelData.device_id || "")
                            color: devId === selectedDeviceId
                                   ? Qt.rgba(1, 0.84, 0.29, 0.18) : "transparent"
                            border.color: devId === selectedDeviceId ? "#FFD54A" : "transparent"
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: statusColor(String(modelData.status || ""))
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.name || modelData.device_id || "")
                                    color: devId === selectedDeviceId ? "#FFD54A" : "#C7E3FF"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedDeviceId =
                                        (selectedDeviceId === devId) ? "" : devId
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: devices.length === 0
                            text: "暂无设备"
                            color: "#236DB7"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // ── 未配置坐标设备条 (如实呈现, 不混入地理投影) ──
        Rectangle {
            Layout.fillWidth: true
            visible: noGeoDevices.length > 0
            height: visible ? 28 : 0
            color: Qt.rgba(0.02, 0.45, 0.9, 0.06)
            radius: 3
            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "未配置坐标: " + noGeoDevices.length + " 台 (" +
                      noGeoDevices.slice(0, 5).map(function (d) {
                          return String(d.name || d.device_id)
                      }).join("、") + (noGeoDevices.length > 5 ? " …" : "") + ")"
                color: "#236DB7"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
