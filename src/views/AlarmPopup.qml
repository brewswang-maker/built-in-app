// ========================================================================
// AlarmPopup.qml — 告警弹窗 (3秒视频回放 + AI研判 + 联动执行)
// Controller: alarmController + linkageController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: alarmPopup
    width: 560; height: 420
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var currentAlarm: ({})
    property int autoCloseSeconds: 15
    property bool isPaused: false

    // ═══ P2.2: 优先级色编码 ═══
    readonly property color priorityColor: {
        var lv = (currentAlarm.level || "").toLowerCase()
        if (lv === "critical" || currentAlarm.level === "紧急") return "#F56C6C"  // 红
        if (lv === "high" || currentAlarm.level === "高") return "#FF6B35"       // 橙
        if (lv === "medium" || currentAlarm.level === "中") return "#E6A23C"      // 黄
        return "#909399"                                                              // 灰(低)
    }
    readonly property bool isCritical: {
        var lv = (currentAlarm.level || "").toLowerCase()
        return lv === "critical" || currentAlarm.level === "紧急"
    }
    property real autoCloseProgress: 1.0  // 1.00.0

    signal confirmed(string alarmId)
    signal falseAlarm(string alarmId)
    signal silenced(string alarmId)
    signal replayRequested(string alarmId)

    // ═══ P2.2: 滑入/滑出动画 ═══
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 250; easing.type: Easing.OutBack }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 200; easing.type: Easing.InCubic }
        }
    }

    function showAlarm(alarm) {
        currentAlarm = alarm
        autoCloseSeconds = 15
        autoCloseProgress = 1.0
        alarmPopup.open()
        autoCloseTimer.restart()
    }

    background: Rectangle {
        color: "#141420"; radius: 12
        border.color: alarmPopup.priorityColor; border.width: 2

        // P2.2: 高危告警边缘闪烁
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.color: alarmPopup.priorityColor
            border.width: 3
            opacity: 0
            SequentialAnimation on opacity {
                running: alarmPopup.isCritical && alarmPopup.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 0.4; duration: 400 }
                NumberAnimation { from: 0.4; to: 0; duration: 400 }
            }
        }
    }

    // [FIX 2026-06-28] 移除了 Component.onCompleted { refreshAlarms(1) } 和
    //   Connections { onAlarmsUpdated / onNewAlarm } — 这些会导致:
    //   1. 应用启动时自动弹出第一条告警 (refreshAlarms → onAlarmsUpdated → open)
    //   2. 每条新告警弹窗两次 (main.qml onNewAlarm 调 showAlarm, 这里又 open)
    //   正确路径: main.qml Connections → alarmPopup.showAlarm(alarm)

    // ── 自动关闭倒计时 + 进度条 ═══
    Timer {
        id: autoCloseTimer
        interval: 100; repeat: true; running: false
        property real totalMs: 15000
        property real elapsedMs: 0
        onTriggered: {
            if (!isPaused) {
                elapsedMs += 100
                autoCloseProgress = Math.max(0, 1.0 - elapsedMs / totalMs)
                autoCloseSeconds = Math.ceil(autoCloseProgress * 15)
                countdownText.text = autoCloseSeconds + "s"
                if (autoCloseProgress <= 0) {
                    stop()
                    alarmPopup.close()
                }
            }
        }
        onRunningChanged: {
            if (running) { elapsedMs = 0; autoCloseProgress = 1.0 }
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8

        // ── 头部 (P2.2: 优先级色编码) ──
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: Qt.rgba(
                alarmPopup.priorityColor.r * 0.1,
                alarmPopup.priorityColor.g * 0.04,
                alarmPopup.priorityColor.b * 0.06,
                1.0
            )
            radius: 6

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12

                Rectangle { width: 10; height: 10; radius: 5; color: alarmPopup.priorityColor
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: alarmPopup.isCritical ? 0.1 : 0.4; duration: alarmPopup.isCritical ? 300 : 600 }
                        NumberAnimation { from: alarmPopup.isCritical ? 0.1 : 0.4; to: 1; duration: alarmPopup.isCritical ? 300 : 600 }
                    }
                }
                Text { text: alarmPopup.isCritical ? "紧急告警" : "新告警"; font.pixelSize: 14; font.bold: true; color: alarmPopup.priorityColor }
                Item { Layout.fillWidth: true }
                Text { id: countdownText; text: "15s"; font.pixelSize: 12; color: "#E6A23C" }
                Button {
                    text: isPaused ? ">" : "||"; font.pixelSize: 12
                    background: Rectangle { color: "#F5F7FA"; radius: 4; width: 24; height: 24 }
                    contentItem: Text { text: parent.text; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: isPaused = !isPaused
                }
                Button {
                    text: "X"; font.pixelSize: 14
                    background: Rectangle { color: "transparent"; radius: 4; width: 24; height: 24 }
                    contentItem: Text { text: parent.text; color: "#909399"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: alarmPopup.close()
                }
            }
        }

        // ── 主内容 ──
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

            // 左侧: 视频回放区
            Rectangle {
                Layout.preferredWidth: 280; Layout.fillHeight: true
                color: "#0A0C10"; radius: 8

                Column {
                    anchors.fill: parent; spacing: 4

                    Rectangle {
                        width: parent.width; height: parent.height - 30
                        color: "#000"; radius: 4; clip: true

                        // 快照图片 (真实加载)
                        Image {
                            id: snapshotImage
                            anchors.fill: parent
                            source: currentAlarm.snapshot_url || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            cache: false
                        }

                        // 加载中指示器
                        BusyIndicator {
                            anchors.centerIn: parent
                            running: snapshotImage.status === Image.Loading
                            visible: running
                        }

                        // 无快照时显示检测框模拟
                        Canvas {
                            id: videoCanvas
                            anchors.fill: parent
                            visible: !snapshotImage.visible

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, width, height)

                                // 检测框
                                ctx.strokeStyle = "#F56C6C"; ctx.lineWidth = 2
                                ctx.strokeRect(width*0.3, height*0.2, width*0.4, height*0.5)

                                // 标签
                                ctx.fillStyle = "#F56C6C"; ctx.font = "bold 10px sans-serif"
                                ctx.fillRect(width*0.3, height*0.2-14, 80, 14)
                                ctx.fillStyle = "#FFF"
                                ctx.fillText(currentAlarm.algoType || "入侵检测", width*0.3+4, height*0.2-3)

                                // 置信度
                                ctx.fillStyle = "#67C23A"; ctx.font = "9px sans-serif"
                                ctx.fillText("置信度: " + (currentAlarm.confidence || "87%"), width*0.3, height*0.75)

                                // 时间戳
                                ctx.fillStyle = "#E6A23C"; ctx.font = "8px sans-serif"
                                ctx.fillText(currentAlarm.time || "--:--:--", 4, height - 4)
                            }

                            onVisibleChanged: if (visible) requestPaint()
                        }

                        // 检测框叠加层 (在快照图片上方绘制)
                        Canvas {
                            id: detectionOverlay
                            anchors.fill: parent
                            visible: snapshotImage.visible

                            property var boxes: currentAlarm.detection_boxes || []

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                for (var i = 0; i < boxes.length; i++) {
                                    var b = boxes[i]
                                    var bx = b.x * width, by = b.y * height
                                    var bw = b.width * width, bh = b.height * height
                                    ctx.strokeStyle = "#F56C6C"; ctx.lineWidth = 2
                                    ctx.strokeRect(bx, by, bw, bh)
                                    if (b.label) {
                                        ctx.fillStyle = "#F56C6C"
                                        ctx.fillRect(bx, by - 16, ctx.measureText(b.label).width + 8, 16)
                                        ctx.fillStyle = "#FFF"; ctx.font = "bold 9px sans-serif"
                                        ctx.fillText(b.label, bx + 4, by - 4)
                                    }
                                }
                            }
                            onBoxesChanged: requestPaint()
                        }
                    }

                    Row {
                        width: parent.width; height: 26; spacing: 4
                        Button {
                            text: "|<"; font.pixelSize: 12; width: 30; height: 22
                            background: Rectangle { color: "#F5F7FA"; radius: 3 }
                            contentItem: Text { text: parent.text; color: "#303133"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: alarmPopup.replayRequested(currentAlarm.id || "")
                        }
                        Text { text: "0:00 / 0:03"; font.pixelSize: 12; color: "#909399"; anchors.verticalCenter: parent.verticalCenter }
                        Item { width: 10 }
                        Button {
                            text: "截图"; font.pixelSize: 12; height: 22
                            background: Rectangle { color: "#F5F7FA"; radius: 3; width: 42 }
                            contentItem: Text { text: parent.text; color: "#303133"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: mediaController.snapshot(currentAlarm.channelId || "")
                        }
                        Button {
                            text: "对讲"; font.pixelSize: 12; height: 22
                            background: Rectangle { color: "#F5F7FA"; radius: 3; width: 42 }
                            contentItem: Text { text: parent.text; color: "#303133"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            // 右侧: 告警详情
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#FFFFFF"; radius: 8

                ScrollView {
                    anchors.fill: parent; anchors.margins: 8; clip: true

                    Column {
                        width: 220; spacing: 6

                        // 告警类型
                        Row {
                            spacing: 6
                            Rectangle { width: 28; height: 16; radius: 3; color: "#F56C6C"
                                Text { text: currentAlarm.level || "高"; font.pixelSize: 12; color: "#FFF"; font.bold: true; anchors.centerIn: parent }
                            }
                            Text { text: currentAlarm.type || "入侵检测"; font.pixelSize: 13; font.bold: true; color: "#303133" }
                        }

                        Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }

                        // 详细信息
                        Column { spacing: 3; width: parent.width
                            Row { Text { text: "通道: "; font.pixelSize: 12; color: "#909399" } Text { text: currentAlarm.channel || "CAM-01"; font.pixelSize: 12; color: "#3B82F6" } }
                            Row { Text { text: "时间: "; font.pixelSize: 12; color: "#909399" } Text { text: currentAlarm.time || "-"; font.pixelSize: 12; color: "#303133" } }
                            Row { Text { text: "区域: "; font.pixelSize: 12; color: "#909399" } Text { text: currentAlarm.zone || "A区围栏"; font.pixelSize: 12; color: "#303133" } }
                            Row { Text { text: "置信度: "; font.pixelSize: 12; color: "#909399" } Text { text: currentAlarm.confidence || "87%"; font.pixelSize: 12; color: "#67C23A" } }
                        }

                        Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }

                        // AI研判
                        Text { text: "AI研判"; font.pixelSize: 12; font.bold: true; color: "#303133" }
                        Column { spacing: 2; width: parent.width
                            Text { text: currentAlarm.aiVerdict || "检测到人员越界，非动物/树枝触发"; font.pixelSize: 12; color: "#909399"; wrapMode: Text.WordWrap; width: parent.width }
                            Text { text: "建议: " + (currentAlarm.suggestion || "立即派人现场确认"); font.pixelSize: 12; color: "#E6A23C"; wrapMode: Text.WordWrap; width: parent.width }
                        }

                        Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }

                        // 关联告警
                        Text { text: "关联告警 (" + (currentAlarm.relatedCount || 2) + ")"; font.pixelSize: 12; color: "#909399" }
                        Repeater {
                            model: Math.min(currentAlarm.relatedCount || 0, 3)
                            delegate: Text {
                                text: "  • " + (currentAlarm.relatedAlarms ? currentAlarm.relatedAlarms[index] : "同区域告警 " + (index+1))
                                font.pixelSize: 12; color: "#4A4D58"
                            }
                        }

                        // 联动状态
                        Rectangle { height: 1; color: "#F5F7FA"; width: parent.width }
                        Text { text: "联动状态"; font.pixelSize: 12; font.bold: true; color: "#303133" }
                        Column { spacing: 2; width: parent.width
                            Row { spacing: 4
                                Rectangle { width: 10; height: 10; radius: 5; color: currentAlarm.linkageStatus === "executed" ? "#67C23A" : "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "录像已触发"; font.pixelSize: 12; color: "#909399" }
                            }
                            Row { spacing: 4
                                Rectangle { width: 10; height: 10; radius: 5; color: currentAlarm.linkageSnapshot === "done" ? "#67C23A" : "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "抓图已执行"; font.pixelSize: 12; color: "#909399" }
                            }
                        }
                    }
                }
            }
        }

        // ── 底栏操作 ──
        Rectangle {
            Layout.fillWidth: true; height: 44; color: "#1A1D23"; radius: 6

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                Button {
                    text: "确认"; font.pixelSize: 12
                    background: Rectangle { color: "#67C23A"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#F5F7FA"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        alarmController.confirmAlarm(currentAlarm.id || "")
                        alarmPopup.confirmed(currentAlarm.id || "")
                        alarmPopup.close()
                    }
                }
                Button {
                    text: "误报"; font.pixelSize: 12
                    background: Rectangle { color: "#E6A23C"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#F5F7FA"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        alarmController.markFalseAlarm(currentAlarm.id || "")
                        alarmPopup.falseAlarm(currentAlarm.id || "")
                        alarmPopup.close()
                    }
                }
                Button {
                    text: "静音"; font.pixelSize: 12
                    background: Rectangle { color: "#F5F7FA"; radius: 6; width: 60; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        alarmPopup.silenced(currentAlarm.id || "")
                        isPaused = true
                    }
                }
                Button {
                    text: "回放"; font.pixelSize: 12
                    background: Rectangle { color: "#F5F7FA"; radius: 6; width: 60; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: alarmPopup.replayRequested(currentAlarm.id || "")
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "详情 "
                    font.pixelSize: 12; color: "#3B82F6"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: alarmPopup.close() }
                }
            }
        }

        // ═══ P2.2: 自动关闭进度条 ═══
        Rectangle {
            Layout.fillWidth: true; height: 3; radius: 1
            color: "#F5F7FA"
            Layout.topMargin: 2

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left
                height: 3; radius: 1
                width: parent.width * alarmPopup.autoCloseProgress
                color: alarmPopup.priorityColor
                Behavior on width { NumberAnimation { duration: 100 } }
            }
        }
    }
}
