// ========================================================================
// StadiumScene3D.qml — 体育场 3D 场景 [体育场3D] (Qt Quick 3D 真 3D)
// 与 Web 端 Scene3D.vue (three.js) 1:1 对应:
//   - 场景数据同源 box-sdk/config/scene_config.json (兜底 StadiumSceneData.js)
//   - 9 类形状: box/cylinder/disc/ring/shell/shell-cap/pylon/board/cone
//   - 设备状态色: online #0F9D58 / alarm #DB4437 / maintenance #F4B400 / offline #555555
//   - Orbit 相机: fov 50, 缩放 20~150, 阻尼 0.08; 单击选中/告警脉冲 30s/标签投影
// Canvas 2.5D 降级实现见 Locate3DPanel.qml (Quick3D 模块不可用时由 Loader 回退)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick3D
import "qrc:///StadiumSceneData.js" as SceneData

Item {
    id: panel

    // ── 对外信号: 与 Locate3DPanel 接口一致 ──
    signal gotoSituation()
    signal gotoVideoGrid()

    // ═══ 场景数据 (默认共享 JS 常量, 运行时可由 situationController 覆盖) ═══
    property var buildings: SceneData.BUILDINGS
    property var devices: SceneData.DEMO_DEVICES
    property var sceneMeta: SceneData.SCENE_META

    readonly property real groundW: (sceneMeta && sceneMeta.ground && sceneMeta.ground.width) || 160
    readonly property real groundH: (sceneMeta && sceneMeta.ground && sceneMeta.ground.height) || 130
    // [v1.9.2] periHalfW/periHalfD (周界围墙参数) 已随围墙移除
    readonly property bool decorOn: !(sceneMeta && sceneMeta.decor === false)

    // ── 状态 ──
    property string selectedDev: ""
    property var pulseDevs: ({})             // deviceId -> { until, sev }
    property var statusOverrides: ({})       // deviceId -> status (告警联动覆盖)
    property int tick: 0
    property bool showLabels: true
    property bool renderStatsDebug: false   // 性能护栏调试开关 (View3D.renderStats)

    // [设备兼容] legacy 软件渲染器 (QT_QUICK_BACKEND=software) 无 RHI, View3D 无法渲染:
    // 父级 Loader 检测到本属性为 true 时应回退 Locate3DPanel (Canvas 2.5D)
    readonly property bool quick3dUnavailable: GraphicsInfo.api === GraphicsInfo.Software

    function devStatus(d) { return statusOverrides[d.id] || d.status || "offline" }
    function devStatusColor(d) { return SceneData.statusColor(devStatus(d)) }
    // PrincipledMaterial.emissiveFactor 需要 vector3d(0~1): hex/颜色字符串 → 归一化向量
    function emiFactor(c) {
        if (!c || c === "transparent") return Qt.vector3d(0, 0, 0)
        var s = Qt.rgba(0, 0, 0, 1)
        try { s = Qt.lighter(c, 1) } catch (e) { return Qt.vector3d(0, 0, 0) }
        return Qt.vector3d(s.r, s.g, s.b)
    }
    readonly property var sevColors: ["#8B8FA3", "#3B82F6", "#3B82F6", "#FFB800", "#FF6B35", "#FF3D71"]

    // ═══ Orbit 相机 (与 Web OrbitControls 对齐: 阻尼 0.08, 距离 20~150) ═══
    // 初始位姿 = Web cameraPresets overview (70,55,85) target(0,4,0)
    readonly property vector3d camTarget: Qt.vector3d(0, 4, 0)
    property real targetYaw: 0.69
    property real targetPitch: 0.43
    property real targetDist: 121
    property real yaw: 0.69
    property real pitch: 0.43
    property real dist: 121

    function resetView() {
        targetYaw = 0.69; targetPitch = 0.43; targetDist = 121
    }
    function viewTop() { targetPitch = 1.5; targetYaw = 0; targetDist = 130 }
    function viewIso() { resetView() }

    // 阻尼插值 (Web dampingFactor 0.08)
    Timer {
        interval: 16; repeat: true; running: panel.visible
        onTriggered: {
            panel.yaw += (panel.targetYaw - panel.yaw) * 0.08
            panel.pitch += (panel.targetPitch - panel.pitch) * 0.08
            panel.dist += (panel.targetDist - panel.dist) * 0.08
        }
    }

    // ═══ 建筑按形状分组 (9 类形状各自 Repeater, 避免 Loader 在 3D 场景的兼容问题) ═══
    function groupByShape() {
        var groups = { "box": [], "cylinder": [], "disc": [], "ring": [],
                       "shell": [], "shell-cap": [], "pylon": [], "board": [], "cone": [] }
        for (var i = 0; i < panel.buildings.length; i++) {
            var b = panel.buildings[i]
            if (!b || b.shape === "anchor") continue   // anchor 不可见, 仅设备挂载锚点
            var s = b.shape || "box"
            if (groups[s] !== undefined) groups[s].push(b)
            else groups["box"].push(b)
        }
        return groups
    }
    property var shapeGroups: groupByShape()
    onBuildingsChanged: shapeGroups = groupByShape()
    onSceneMetaChanged: shapeGroups = groupByShape()

    // 世界坐标 → 屏幕坐标 (热力图叠加/外部投影用, 等价 Web CSS2DRenderer)
    function projectPoint(wx, wy, wz) {
        return view.mapFrom3DScene(Qt.vector3d(wx, wy, wz))
    }

    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: "#0B1220"; radius: 8
        border.color: "#252830"; border.width: 1

        View3D {
            id: view
            anchors.fill: parent
            anchors.margins: 4
            environment: SceneEnvironment {
                backgroundMode: SceneEnvironment.Color
                clearColor: "#0B1220"
                antialiasingMode: SceneEnvironment.MSAA
                antialiasingQuality: SceneEnvironment.Medium   // 软件渲染性能护栏 (枚举仅 Medium/High/VeryHigh)
            }

            // ── 相机 (fov 50, 与 Web PerspectiveCamera 一致) ──
            camera: PerspectiveCamera {
                id: cam
                fieldOfView: SceneData.CAMERA.fov
                clipNear: SceneData.CAMERA.near
                clipFar: SceneData.CAMERA.far
                position: Qt.vector3d(
                    panel.camTarget.x + panel.dist * Math.cos(panel.pitch) * Math.sin(panel.yaw),
                    panel.camTarget.y + panel.dist * Math.sin(panel.pitch),
                    panel.camTarget.z + panel.dist * Math.cos(panel.pitch) * Math.cos(panel.yaw))
                eulerRotation: Qt.vector3d(-panel.pitch * 57.2958, panel.yaw * 57.2958, 0)
            }

            DirectionalLight { eulerRotation: Qt.vector3d(-50, -30, 0); brightness: 1.0 }
            // Qt Quick 3D 无 AmbientLight 类型: 用反向低强度补光模拟 Web 端 AmbientLight(0.35)
            DirectionalLight { eulerRotation: Qt.vector3d(40, 150, 0); brightness: 0.35 }

            // ═══ 地面 (对齐 Web 地面参数) ═══
            Model {
                source: "#Rectangle"
                eulerRotation: Qt.vector3d(-90, 0, 0)
                scale: Qt.vector3d(panel.groundW / 100, panel.groundH / 100, 1)
                materials: [ PrincipledMaterial { baseColor: "#0B1220"; roughness: 0.9 } ]
            }
            // [v1.9.2] 周界围墙 4 面已移除 (用户反馈): 参数化模式遗留的半透明
            // 围墙圈住体育场四周, 属"残留背景", 与 Web 端 Scene3D.vue 同步移除。

            // ═══ box (含 stack 错位叠层 / cap 尖顶 / edgeGlow 发光边线) ═══
            Repeater3D {
                model: panel.shapeGroups["box"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Repeater3D {
                        model: Math.max(1, b.stack || 1)
                        delegate: Node {
                            property real fi: index
                            position: Qt.vector3d(fi * 1.2, 0, fi * 0.8)
                            scale: Qt.vector3d(1 - fi * 0.12, 1 - fi * 0.12, 1 - fi * 0.12)
                            Model {
                                source: "#Cube"
                                position: Qt.vector3d(0, (b.h || 4) / 2, 0)
                                scale: Qt.vector3d((b.w || 8) / 100, (b.h || 4) / 100, (b.d || 8) / 100)
                                materials: [ PrincipledMaterial {
                                    baseColor: b.color || "#4A5A75"
                                    opacity: b.opacity !== undefined ? b.opacity : 0.35
                                    roughness: 0.7
                                    alphaMode: PrincipledMaterial.Blend
                                } ]
                            }
                        }
                    }
                    // cap 尖顶 (红瓦小屋)
                    Model {
                        visible: b.cap === true
                        source: "#Cone"
                        position: Qt.vector3d(0, (b.h || 4) + (b.w || 4) * 0.3, 0)
                        scale: Qt.vector3d((b.w || 4) * 0.75 / 50, (b.w || 4) * 0.6 / 100, (b.d || 4) * 0.75 / 50)
                        materials: [ PrincipledMaterial { baseColor: "#B05C44"; roughness: 0.8 } ]
                    }
                    // edgeGlow 发光边线 (停车场 LED 描边)
                    Model {
                        visible: b.edgeGlow !== undefined
                        source: "#Cube"
                        position: Qt.vector3d(0, (b.h || 0.5) + 0.08, 0)
                        scale: Qt.vector3d(((b.w || 8) + 0.8) / 100, 0.12 / 100, ((b.d || 8) + 0.8) / 100)
                        materials: [ PrincipledMaterial {
                            baseColor: b.edgeGlow || "#2E8FFF"; emissiveFactor: panel.emiFactor(b.edgeGlow || "#2E8FFF")
                            opacity: 0.9; alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                }
            }

            // ═══ cylinder (含 cap 半球顶: 水滴形演艺厅) ═══
            Repeater3D {
                model: panel.shapeGroups["cylinder"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 6) / 2, 0)
                        scale: Qt.vector3d((b.rx || 4) / 50, (b.h || 6) / 100, (b.rz || 4) / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: b.color || "#4A5A75"; opacity: 0.35; roughness: 0.7
                            alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                    Model {
                        visible: b.cap === true
                        source: "#Sphere"
                        position: Qt.vector3d(0, b.h || 6, 0)
                        scale: Qt.vector3d((b.rx || 4) / 50, (b.rx || 4) * 0.6 / 50, (b.rz || 4) / 50)
                        materials: [ PrincipledMaterial { baseColor: b.color || "#4A5A75"; opacity: 0.5; alphaMode: PrincipledMaterial.Blend } ]
                    }
                }
            }

            // ═══ disc (扁圆柱; 旗杆/喷泉水柱/草坪标线) ═══
            Repeater3D {
                model: panel.shapeGroups["disc"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 0.2) / 2, 0)
                        scale: Qt.vector3d((b.rx || 4) / 50, (b.h || 0.2) / 100, (b.rz || 4) / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: b.color || "#3A4356"
                            emissiveFactor: panel.emiFactor(b.emissive)
                            roughness: 0.8
                        } ]
                    }
                    // 喷泉水柱 (jet)
                    Model {
                        visible: b.jet === true
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 0.5) + 1, 0)
                        scale: Qt.vector3d(0.5 / 50, 2 / 100, 0.5 / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: "#2E8FFF"; emissiveFactor: panel.emiFactor("#2E8FFF")
                            opacity: 0.8; alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                    // 旗杆 (flagpoles 根)
                    Repeater3D {
                        model: b.flagpoles || 0
                        delegate: Model {
                            source: "#Cylinder"
                            position: Qt.vector3d((index - (Math.max(1, b.flagpoles || 1) - 1) / 2) * 1.6, 3, -((b.rz || 4) * 0.5))
                            scale: Qt.vector3d(0.12 / 50, 6 / 100, 0.12 / 50)
                            materials: [ PrincipledMaterial { baseColor: "#C8CDD6" } ]
                        }
                    }
                    // 草坪标线 (pitchLines: 中线 + 中圈, 对齐 Web addPitchLines)
                    Node {
                        visible: b.pitchLines === true
                        Model { // 中线
                            source: "#Cube"
                            position: Qt.vector3d(0, (b.h || 0.3) + 0.03, 0)
                            scale: Qt.vector3d(0.3 / 100, 0.04 / 100, (b.rz || 4) * 1.7 / 100)
                            materials: [ PrincipledMaterial { baseColor: "#FFFFFF"; opacity: 0.5; alphaMode: PrincipledMaterial.Blend } ]
                        }
                        Model { // 中圈 (白色扁 disc)
                            source: "#Cylinder"
                            position: Qt.vector3d(0, (b.h || 0.3) + 0.03, 0)
                            scale: Qt.vector3d(2.8 / 50, 0.04 / 100, 2.8 / 50)
                            materials: [ PrincipledMaterial { baseColor: "#FFFFFF"; opacity: 0.5; alphaMode: PrincipledMaterial.Blend } ]
                        }
                        Model { // 中圈内心 (回填草坪色)
                            source: "#Cylinder"
                            position: Qt.vector3d(0, (b.h || 0.3) + 0.05, 0)
                            scale: Qt.vector3d(2.5 / 50, 0.04 / 100, 2.5 / 50)
                            materials: [ PrincipledMaterial { baseColor: b.color || "#1F7A3D" } ]
                        }
                    }
                }
            }

            // ═══ ring (大 disc + 内芯 disc 叠色: 跑道红/内芯地面色) ═══
            Repeater3D {
                model: panel.shapeGroups["ring"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 0.25) / 2, 0)
                        scale: Qt.vector3d((b.rx || 6) / 50, (b.h || 0.25) / 100, (b.rz || 6) / 50)
                        materials: [ PrincipledMaterial { baseColor: b.color || "#B0432F"; roughness: 0.8 } ]
                    }
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 0.25) / 2 + 0.06, 0)
                        scale: Qt.vector3d((b.innerRx || 4) / 50, (b.h || 0.25) / 100, (b.innerRz || 4) / 50)
                        materials: [ PrincipledMaterial { baseColor: "#0B1220"; roughness: 0.9 } ]
                    }
                }
            }

            // ═══ shell (看台碗体: tiers 三色环带逐层叠放) ═══
            Repeater3D {
                model: panel.shapeGroups["shell"]
                delegate: Node {
                    property var b: modelData
                    property var tierColors: b.tiers || [b.color || "#3E5C8F"]
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Repeater3D {
                        model: tierColors.length
                        delegate: Model {
                            source: "#Cylinder"
                            property real layerH: (b.h || 12) / tierColors.length
                            property real inset: 1 - index * 0.08
                            position: Qt.vector3d(0, layerH * (index + 0.5), 0)
                            scale: Qt.vector3d(((b.rx || 20) * inset) / 50, layerH / 100, ((b.rz || 16) * inset) / 50)
                            materials: [ PrincipledMaterial {
                                baseColor: tierColors[index] || b.color || "#3E5C8F"
                                opacity: 0.5; roughness: 0.7
                                alphaMode: PrincipledMaterial.Blend
                            } ]
                        }
                    }
                }
            }

            // ═══ shell-cap (花瓣屋盖: 半球壳 scale 成椭圆, thetaDeg 控制朝向) ═══
            Repeater3D {
                model: panel.shapeGroups["shell-cap"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    eulerRotation: Qt.vector3d(0, b.thetaDeg || 0, 0)
                    Model {
                        source: "#Sphere"
                        position: Qt.vector3d(0, 0, 0)   // 下半球沉入地面以下被地面遮挡
                        scale: Qt.vector3d((b.rx || 10) / 50, (b.h || 8) / 50, (b.rz || 10) / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: b.color || "#C8CDD6"
                            opacity: 0.55; roughness: 0.4
                            alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                }
            }

            // ═══ pylon (塔桅: 细柱 + 发光顶球 + 向上光束) ═══
            Repeater3D {
                model: panel.shapeGroups["pylon"]
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Model { // 塔身
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 22) / 2, 0)
                        scale: Qt.vector3d(0.35 / 50, (b.h || 22) / 100, 0.35 / 50)
                        materials: [ PrincipledMaterial { baseColor: b.color || "#E8EEF7" } ]
                    }
                    Model { // 顶部发光球
                        source: "#Sphere"
                        position: Qt.vector3d(0, b.h || 22, 0)
                        scale: Qt.vector3d(0.9 / 50, 0.9 / 50, 0.9 / 50)
                        materials: [ PrincipledMaterial { baseColor: "#FFF6D8"; emissiveFactor: panel.emiFactor("#FFE9A8") } ]
                    }
                    Model { // 向上光束 (emissive 半透明)
                        visible: b.beam === true
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (b.h || 22) + 4, 0)
                        scale: Qt.vector3d(0.45 / 50, 8 / 100, 0.45 / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: "#CFE3FF"; emissiveFactor: panel.emiFactor("#9FC5FF")
                            opacity: 0.25; alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                }
            }

            // ═══ board (LED 大屏/引导屏: 悬浮薄板 + emissive 发光面 + 支撑立柱) ═══
            Repeater3D {
                model: panel.shapeGroups["board"]
                delegate: Node {
                    property var b: modelData
                    property real baseY: b.y !== undefined ? b.y : 6
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    // [v1.9.0] LED 大屏绕 Y 朝向角: Quick3D 官方文档 Node.eulerRotation
                    // "This property contains the Euler rotations of the node in degrees"
                    // (度制, 与 Web 端 thetaDeg 同源; Web 端 m.rotation.y 需 ×π/180);
                    // 屏面 + 2 根立柱均为本 Node 子级, 整体旋转不错位
                    eulerRotation.y: b.thetaDeg || 0
                    Model { // 发光屏面
                        source: "#Cube"
                        position: Qt.vector3d(0, baseY + (b.h || 3) / 2, 0)
                        scale: Qt.vector3d((b.w || 6) / 100, (b.h || 3) / 100, 0.3 / 100)
                        materials: [ PrincipledMaterial {
                            baseColor: b.color || "#0B1220"
                            emissiveFactor: panel.emiFactor(b.emissive || "#2A6BFF")
                        } ]
                    }
                    Repeater3D { // 支撑立柱 (2 根)
                        model: baseY > 1.5 ? 2 : 0
                        delegate: Model {
                            source: "#Cylinder"
                            position: Qt.vector3d((index === 0 ? -1 : 1) * (b.w || 6) * 0.35, baseY / 2, 0)
                            scale: Qt.vector3d(0.2 / 50, baseY / 100, 0.2 / 50)
                            materials: [ PrincipledMaterial { baseColor: "#3E4A60" } ]
                        }
                    }
                }
            }

            // ═══ cone (树簇装饰层, 受 decor 开关控制) ═══
            Repeater3D {
                model: panel.decorOn ? panel.shapeGroups["cone"] : []
                delegate: Node {
                    property var b: modelData
                    position: Qt.vector3d(b.x || 0, 0, b.z || 0)
                    Repeater3D {
                        model: b.count || 3
                        delegate: Model {
                            source: "#Cone"
                            position: Qt.vector3d((index - (Math.max(1, b.count || 3) - 1) / 2) * (2 * (b.rx || 4) / Math.max(1, b.count || 3)), (b.h || 3) / 2, 0)
                            scale: Qt.vector3d(1.3 / 50, (b.h || 3) / 100, 1.3 / 50)
                            materials: [ PrincipledMaterial { baseColor: b.color || "#2E5D3A"; roughness: 0.8 } ]
                        }
                    }
                }
            }

            // ═══ 设备节点 (圆柱机身 + 状态色发光镜头球 + 底座环 + 脉冲) ═══
            Repeater3D {
                id: devRepeater
                model: panel.devices
                delegate: Node {
                    id: devNode
                    property var d: modelData
                    property int deviceIndex: index
                    position: Qt.vector3d(d.x || 0, 0, d.z || 0)

                    // 底座环 (扁平 disc, 状态色)
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, 0.08, 0)
                        scale: Qt.vector3d(2.2 / 50, 0.16 / 100, 2.2 / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: panel.devStatusColor(d)
                            opacity: 0.35; alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                    // 立杆
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0, (d.y || 4) / 2, 0)
                        scale: Qt.vector3d(0.15 / 50, (d.y || 4) / 100, 0.15 / 50)
                        materials: [ PrincipledMaterial { baseColor: "#8B8FA3" } ]
                    }
                    // 机身 + 状态色发光镜头球
                    Node {
                        position: Qt.vector3d(0, d.y || 4, 0)
                        Model {
                            source: "#Sphere"
                            scale: Qt.vector3d(0.6 / 50, 0.6 / 50, 0.6 / 50)
                            materials: [ PrincipledMaterial { baseColor: "#8B8FA3" } ]
                        }
                        Model {
                            source: "#Sphere"
                            position: Qt.vector3d(0, 0.7, 0)
                            scale: Qt.vector3d(0.38 / 50, 0.38 / 50, 0.38 / 50)
                            materials: [ PrincipledMaterial {
                                baseColor: panel.devStatusColor(d)
                                emissiveFactor: panel.emiFactor(panel.devStatusColor(d))
                            } ]
                        }
                        // [v1.9.1] FOV 视锥已移除: 19 个半透明锥体叠加横跨球场上空,
                        // 形成"球场铺一层东西"观感, 干扰体育场整体还原 (与 Web 端
                        // Scene3D.vue 同步移除, 用户反馈); fov/rotation 数据保留
                    }
                    // 告警脉冲扩散环 (30s 时限, 与 Web 一致)
                    Model {
                        id: pulseRing
                        property var pulse: panel.pulseDevs[d.id]
                        property bool pulsing: pulse !== undefined && pulse.until > Date.now() - 200
                        property real phase: (panel.tick % 16) / 16
                        visible: pulsing
                        source: "#Cylinder"
                        position: Qt.vector3d(0, 0.2, 0)
                        scale: Qt.vector3d((2.5 + phase * 5) / 50, 0.15 / 100, (2.5 + phase * 5) / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: panel.sevColors[pulseRing.pulse ? pulseRing.pulse.sev : 5] || "#FF3D71"
                            emissiveFactor: panel.emiFactor(panel.sevColors[pulseRing.pulse ? pulseRing.pulse.sev : 5] || "#FF3D71")
                            opacity: 0.85 - pulseRing.phase * 0.7
                            alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                    // 选中高亮白圈
                    Model {
                        visible: panel.selectedDev === d.id
                        source: "#Cylinder"
                        position: Qt.vector3d(0, 0.12, 0)
                        scale: Qt.vector3d(3.2 / 50, 0.1 / 100, 3.2 / 50)
                        materials: [ PrincipledMaterial {
                            baseColor: "#FFFFFF"; opacity: 0.7; alphaMode: PrincipledMaterial.Blend
                        } ]
                    }
                }
            }
        }

        // ═══ 2D 标签覆盖层 (mapFrom3DScene 投影, 等价 Web CSS2DRenderer) ═══
        Item {
            id: labelLayer
            anchors.fill: view

            Repeater {
                model: panel.showLabels ? panel.devices : []
                delegate: Text {
                    property var d: modelData
                    property var sp: {
                        // 依赖项: 相机状态/尺寸变化时重新投影
                        panel.yaw; panel.pitch; panel.dist; labelLayer.width; labelLayer.height
                        view.mapFrom3DScene(Qt.vector3d(d.x || 0, (d.y || 4) + 1.6, d.z || 0))
                    }
                    x: sp.x - width / 2; y: sp.y - height
                    visible: sp.x > -50 && sp.x < labelLayer.width + 50 && sp.y > -50 && sp.y < labelLayer.height + 50
                    text: d.name || ""
                    font.pixelSize: panel.selectedDev === d.id ? 11 : 10
                    font.bold: panel.selectedDev === d.id
                    color: panel.selectedDev === d.id ? "#FFFFFF"
                         : (panel.pulseDevs[d.id] && panel.pulseDevs[d.id].until > Date.now() - 200) ? "#FF6B35" : "#8B8FA3"
                    style: Text.Outline; styleColor: "#0B1220"
                }
            }

            Repeater {
                model: panel.showLabels ? panel.buildings : []
                delegate: Text {
                    property var b: modelData
                    property bool show: b && b.shape !== "anchor" && (b.h || 0) >= 3 && (!b.decor || panel.decorOn)
                    property var sp: {
                        panel.yaw; panel.pitch; panel.dist; labelLayer.width; labelLayer.height
                        view.mapFrom3DScene(Qt.vector3d(b.x || 0, (b.y !== undefined ? b.y : 0) + (b.h || 4) + 1.5, b.z || 0))
                    }
                    visible: show && sp.x > -50 && sp.x < labelLayer.width + 50 && sp.y > -50 && sp.y < labelLayer.height + 50
                    x: sp.x - width / 2; y: sp.y - height
                    text: b ? (b.name || "") : ""
                    font.pixelSize: 10; color: "#C9D4E5"
                    style: Text.Outline; styleColor: "#0B1220"
                }
            }
        }

        // ── 交互: 拖拽旋转 / 滚轮缩放 / 点击选中 (view.pick + 投影兜底) ──
        MouseArea {
            id: sceneMa
            anchors.fill: view
            acceptedButtons: Qt.LeftButton
            property real lastX: 0
            property real lastY: 0
            property bool moved: false

            onPressed: function (mouse) { lastX = mouse.x; lastY = mouse.y; moved = false }
            onPositionChanged: function (mouse) {
                if (!sceneMa.pressed) return
                var dx = mouse.x - lastX, dy = mouse.y - lastY
                if (Math.abs(dx) + Math.abs(dy) > 3) moved = true
                panel.targetYaw += dx * 0.008
                panel.targetPitch = Math.max(0.1, Math.min(1.5, panel.targetPitch + dy * 0.004))
                lastX = mouse.x; lastY = mouse.y
            }
            onWheel: function (wheel) {
                var f = wheel.angleDelta.y > 0 ? (1 / 1.12) : 1.12
                panel.targetDist = Math.max(SceneData.CAMERA.minDistance,
                                   Math.min(SceneData.CAMERA.maxDistance, panel.targetDist * f))
            }
            onClicked: function (mouse) {
                if (moved) return
                // 优先 view.pick 命中设备节点
                var hit = ""
                var res = view.pick(mouse.x, mouse.y)
                if (res.objectHit) {
                    var node = res.objectHit
                    for (var lvl = 0; lvl < 6 && node; lvl++) {
                        if (node.deviceIndex !== undefined && node.d !== undefined) {
                            hit = node.d.id; break
                        }
                        node = node.parent
                    }
                }
                // 兜底: 2D 投影最近设备 (与 Locate3DPanel 一致)
                if (hit === "") {
                    var bestDist = 24
                    for (var i = 0; i < panel.devices.length; i++) {
                        var d = panel.devices[i]
                        var p = view.mapFrom3DScene(Qt.vector3d(d.x || 0, d.y || 4, d.z || 0))
                        var dist2 = Math.sqrt(Math.pow(mouse.x - p.x, 2) + Math.pow(mouse.y - p.y, 2))
                        if (dist2 < bestDist) { bestDist = dist2; hit = d.id }
                    }
                }
                panel.selectedDev = hit
            }
        }

        // ═══ 工具栏 (左上悬浮: 等轴测/俯视/复位 + 图例) ═══
        Rectangle {
            z: 5
            anchors.top: parent.top; anchors.left: parent.left
            anchors.margins: 10
            width: toolRow.width + 20; height: 34
            color: "#141720"; radius: 6; border.color: "#252830"; border.width: 1

            Row {
                id: toolRow
                anchors.centerIn: parent; spacing: 12

                Button { text: "等轴测"; width: 52; height: 24
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: panel.viewIso()
                }
                Button { text: "俯视"; width: 44; height: 24
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: panel.viewTop()
                }
                Button { text: "复位"; width: 44; height: 24
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: panel.resetView()
                }

                Rectangle { width: 1; height: 18; color: "#252830"; anchors.verticalCenter: parent.verticalCenter }

                // 图例 (状态色与 Web 一致)
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#0F9D58"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "在线"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#DB4437"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "告警"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#F4B400"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "维保"; font.pixelSize: 10; color: "#8B8FA3" }
                }
                Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 4; color: "#555555"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "离线"; font.pixelSize: 10; color: "#8B8FA3" }
                }

                Text { text: "设备 " + panel.devices.length; font.pixelSize: 10; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "拖拽旋转 · 滚轮缩放"; font.pixelSize: 10; color: "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ═══ 设备信息卡 (右上悬浮, 与 Locate3DPanel 一致) ═══
        Rectangle {
            id: devInfo
            z: 5
            visible: panel.selectedDev !== ""
            anchors.top: parent.top; anchors.right: parent.right
            anchors.margins: 10
            width: 230; height: infoCol.height + 24
            color: "#141720"; radius: 8; border.color: "#3B82F6"; border.width: 1

            property var dev: {
                for (var i = 0; i < panel.devices.length; i++)
                    if (panel.devices[i].id === panel.selectedDev) return panel.devices[i]
                return null
            }

            Column {
                id: infoCol
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 12; spacing: 6

                Row { width: parent.width; spacing: 6
                    Rectangle { width: 8; height: 8; radius: 4; color: devInfo.dev ? panel.devStatusColor(devInfo.dev) : "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: devInfo.dev ? devInfo.dev.name : ""; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Item { width: 4 }
                    Text { text: devInfo.dev ? (panel.devStatus(devInfo.dev) === "online" ? "在线" : panel.devStatus(devInfo.dev) === "alarm" ? "告警中" : panel.devStatus(devInfo.dev) === "maintenance" ? "维保中" : "离线") : ""
                        font.pixelSize: 11; color: devInfo.dev ? panel.devStatusColor(devInfo.dev) : "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: 10 }
                    Button { text: "X"; width: 22; height: 22
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.selectedDev = ""
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#252830" }

                Grid { columns: 2; columnSpacing: 10; rowSpacing: 4; width: parent.width
                    Text { text: "设备ID:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? devInfo.dev.id : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "安装位置:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? (devInfo.dev.location || "") : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "坐标:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: devInfo.dev ? ("(" + devInfo.dev.x + ", " + devInfo.dev.z + ")") : ""; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "当前告警:"; font.pixelSize: 11; color: "#8B8FA3"; visible: devInfo.dev && devInfo.dev.alarmType }
                    Text { text: devInfo.dev && devInfo.dev.alarmType ? devInfo.dev.alarmType : ""; font.pixelSize: 11; color: "#FF6B35"; visible: devInfo.dev && devInfo.dev.alarmType }
                }

                Row { spacing: 8; layoutDirection: Qt.RightToLeft; width: parent.width
                    Button { text: "查看态势"; width: 74; height: 26
                        background: Rectangle { color: "#3B82F6"; radius: 4 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.gotoSituation()
                    }
                    Button { text: "实时预览"; width: 74; height: 26
                        background: Rectangle { color: "#252830"; radius: 4; border.color: "#3B82F6"; border.width: 1 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: panel.gotoVideoGrid()
                    }
                }
            }
        }

        // renderStats 调试输出 (性能护栏)
        Text {
            visible: panel.renderStatsDebug
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 10
            z: 99
            text: view.renderStats
                  ? "Quick3D fps=" + view.renderStats.fps
                    + " frame=" + view.renderStats.frameTime.toFixed(1) + "ms"
                    + " draws=" + view.renderStats.drawCallCount
                  : "Quick3D renderStats: n/a"
            font.pixelSize: 10; color: "#4A4D58"
        }
    }

    // ═══ 告警联动: 告警列表 location 模糊匹配设备 → 30s 脉冲 (与 Locate3DPanel 同款) ═══
    function refreshPulse() {
        if (typeof alarmController === "undefined" || !alarmController) return
        var alarms = alarmController.alarms
        var now = Date.now()
        var obj = pulseDevs
        var ovr = statusOverrides
        for (var i = 0; i < alarms.length; i++) {
            var loc = alarms[i].location || alarms[i].channel_id || ""
            var lvl = alarms[i].level
            for (var j = 0; j < devices.length; j++) {
                var d = devices[j]
                if (loc && (loc.indexOf(d.location || "") >= 0 || loc.indexOf(d.name || "") >= 0)) {
                    obj[d.id] = { until: now + 30000, sev: lvl === "critical" ? 5 : lvl === "warning" ? 4 : 3 }
                    ovr[d.id] = "alarm"
                }
            }
        }
        pulseDevs = obj
        statusOverrides = ovr
    }

    Connections {
        target: (typeof alarmController !== "undefined") ? alarmController : null
        ignoreUnknownSignals: true
        function onAlarmsUpdated() { panel.refreshPulse() }
    }

    // WebSocket 实时定位推送
    Connections {
        target: (typeof wsRouter !== "undefined") ? wsRouter : null
        ignoreUnknownSignals: true
        function onMapMarkerReceived(payload) {
            if (!payload) return
            var now = Date.now()
            var obj = panel.pulseDevs
            var sev = payload.severity || 3
            var matched = false
            for (var i = 0; i < panel.devices.length; i++) {
                if (payload.device_id && panel.devices[i].id === payload.device_id) { matched = true; break }
            }
            obj[matched ? payload.device_id : panel.devices[0].id] = { until: now + 30000, sev: sev }
            panel.pulseDevs = obj
        }
    }

    // 脉冲动画驱动 (面板可见时)
    Timer {
        interval: 100; repeat: true; running: panel.visible
        onTriggered: {
            panel.tick++
            var now = Date.now(), any = false
            for (var k in panel.pulseDevs) { if (panel.pulseDevs[k].until > now) { any = true; break } }
            if (!any && panel.pulseDevs !== undefined) {
                // 清理过期脉冲
                var cleaned = false, obj = {}
                for (var kk in panel.pulseDevs) { if (panel.pulseDevs[kk].until > now) obj[kk] = panel.pulseDevs[kk]; else cleaned = true }
                if (cleaned) panel.pulseDevs = obj
            }
        }
    }

    Component.onCompleted: {
        if (quick3dUnavailable)
            console.log("[StadiumScene3D] GraphicsInfo.api=Software (legacy renderer, no RHI) → 通知父级回退 Canvas 2.5D")
        refreshPulse()
    }
}
