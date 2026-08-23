// [体育场3D] 共享场景数据 — 与 box-sdk/config/scene_config.json 逐字段一致（单一数据源兜底）。
// Dashboard 3D 定位图与态势页共用，运行时以后端 GET /api/v1/scene/config 覆盖。
.pragma library

var SCENE_META = {
    ground: { width: 80, height: 55 },
    perimeter: { halfW: 35, halfD: 25 },
    rotationDeg: 0,
    decor: true
};

// 形状: box|cylinder|disc|ring|shell|shell-cap|pylon|board|cone|anchor(anchor 不可见，仅设备挂载锚点)
var BUILDINGS = [
    // [WEB-GLB 2026-08-21] v1.5.0: 完全依赖 GLB, 仅追加 4 LED 大屏
    // GLB = Al Wakrah Stadium (卡塔尔 2022 世界杯), 已含草坪+标线+球门+角旗+看台+更衣室
    // GLB 是碗型 (看台底 y=0 / 草皮 y=29 / 顶棚 y=47.6),
    // modelOffsetY=0 让看台底贴地, 草皮在 y=14.5 被看台环绕
    // 删除 player-tunnel-s (与 GLB cabin_2 重叠)
    {
        id: "stadium-glb-ref",
        name: "Al Wakrah 体育场 (GLB)",
        shape: "model",
        x: 0,
        z: 0,
        modelUrl: "/models/stadium.glb",
        modelScale: 0.5,
        modelOffsetY: 0,
        modelRotationDeg: 0
    },
    {
        id: "scoreboard-ne", name: "东北 LED 大屏", shape: "board",
        x: 28, z: 15, y: 18, w: 14, h: 7, color: "#0B1220", emissive: "#2A6BFF",
        thetaDeg: -103
    },
    {
        id: "scoreboard-nw", name: "西北 LED 大屏", shape: "board",
        x: -28, z: 15, y: 18, w: 14, h: 7, color: "#0B1220", emissive: "#2A6BFF",
        thetaDeg: 103
    },
    {
        id: "scoreboard-se", name: "东南 LED 大屏", shape: "board",
        x: 28, z: -15, y: 18, w: 14, h: 7, color: "#0B1220", emissive: "#2A6BFF",
        thetaDeg: -77
    },
    {
        id: "scoreboard-sw", name: "西南 LED 大屏", shape: "board",
        x: -28, z: -15, y: 18, w: 14, h: 7, color: "#0B1220", emissive: "#2A6BFF",
        thetaDeg: 77
    }
];
// [v1.9.0] thetaDeg: LED 大屏绕 Y 朝向角(度), 朝场心角 ±15° 偏向观众席
// (Quick3D Node.eulerRotation 单位为度; Web 端 m.rotation.y 弧度制, 双端同源)

// 默认演示设备点位（与 Web 端 DEMO_SCENE_DEVICES / scene_config.json demoDevices 同名同坐标）
// [v1.9.5] 删 8 处场外配套区点位（喷泉广场/广告大屏/配套楼顶/停车场×2/
// 滨水步道/波浪馆/训练场）：对应场外建筑 v1.5.0 已删，设备悬空孤点；保留馆内 11 台。
var DEMO_DEVICES = [
    { id: "demo-cam1", name: "CAM_01 主入口", x: 0, y: 5, z: 24, status: "online", location: "主入口广场", fov: 70, rotation: 0 },
    { id: "demo-cam5", name: "CAM_05 看台A区", x: 0, y: 13, z: -32, status: "online", location: "看台A区高点", fov: 65, rotation: 0 },
    { id: "demo-cam6", name: "CAM_06 看台B区", x: 26, y: 13, z: -8, status: "alarm", location: "看台B区高点", alarmType: "人群聚集", fov: 65, rotation: -1.571 },
    { id: "demo-cam7", name: "CAM_07 看台C区", x: 0, y: 13, z: 16, status: "online", location: "看台C区高点", fov: 65, rotation: 3.142 },
    { id: "demo-cam8", name: "CAM_08 看台D区", x: -26, y: 13, z: -8, status: "online", location: "看台D区高点", fov: 65, rotation: 1.571 },
    { id: "demo-cam9", name: "CAM_09 内场", x: 0, y: 4, z: -8, status: "online", location: "内场草坪", fov: 80, rotation: 3.142 },
    { id: "demo-cam10", name: "CAM_10 塔桅全景", x: -16, y: 20, z: -30, status: "online", location: "塔桅2全景", fov: 90, rotation: 0 },
    // [v1.9.2] 球门 4 点位上移至屋盖灯光带 (±24, 27.5, ±14): 旧 y=16 在屋盖下表面
    // (实测 y≈26) 之下被完全遮挡不可见; y=27.5 设备底 26.9 高于屋盖上表面
    // (东 26.25/西 26.43, 间隙 0.47~0.65 不穿模), raycast 全几何求交验证;
    // rotation = atan2(dx, -dz) 朝场心; 四端 (scene_config/defaultSceneData/sceneDeviceMapper) 同源
    { id: "demo-cam16", name: "CAM_16 东球门南侧", x: 24, y: 27.5, z: -14, status: "online", location: "东球门灯光带南侧", fov: 70, rotation: -2.099 },
    { id: "demo-cam17", name: "CAM_17 东球门北侧", x: 24, y: 27.5, z: 14, status: "online", location: "东球门灯光带北侧", fov: 70, rotation: -1.043 },
    { id: "demo-cam18", name: "CAM_18 西球门南侧", x: -24, y: 27.5, z: -14, status: "maintenance", location: "西球门灯光带南侧", fov: 70, rotation: 2.099 },
    { id: "demo-cam19", name: "CAM_19 西球门北侧", x: -24, y: 27.5, z: 14, status: "alarm", alarmType: "禁区闯入", location: "西球门灯光带北侧", fov: 70, rotation: 1.043 }
];

// 设备状态色（与 Web 端完全一致）
var STATUS_COLORS = {
    online: "#0F9D58",
    alarm: "#DB4437",
    maintenance: "#F4B400",
    offline: "#555555"
};

// 相机参数（与 Web modelConfigs.json 对齐）
// [WEB-GLB 2026-08-21] v1.5.0 调近视野 + target 上移到草皮 (碗型中央)
var CAMERA = {
    fov: 50,
    near: 0.5,
    far: 800,
    minDistance: 20,
    maxDistance: 100,
    damping: 0.08,
    initPosition: { x: 45, y: 35, z: 55 },
    target: { x: 0, y: 8, z: 0 }
};

function statusColor(status) {
    return STATUS_COLORS[status] || STATUS_COLORS.offline;
}

// 真实设备状态合并 (对齐 Web 三路合并): 按名称/位置字段匹配 mapDevices
// 覆盖演示设备 status, 未匹配保留演示态
function mergeDeviceStatus(demo, real) {
    if (!real || real.length === 0) return demo;
    var out = [];
    for (var i = 0; i < demo.length; i++) {
        var d = demo[i];
        var copy = {};
        for (var k in d) copy[k] = d[k];
        for (var j = 0; j < real.length; j++) {
            var r = real[j];
            var rn = r.name || "";
            var rl = r.location || r.position || "";
            var nameHit = rn && dn(d.name, rn);
            var locHit = rl && d.location && (rl.indexOf(d.location) >= 0 || d.location.indexOf(rl) >= 0);
            if (nameHit || locHit) {
                if (r.status) copy.status = String(r.status);
                break;
            }
        }
        out.push(copy);
    }
    return out;
}

// 名称模糊匹配 (去空格/大小写包含)
function dn(a, b) {
    if (!a || !b) return false;
    var na = String(a).replace(/\s+/g, "").toLowerCase();
    var nb = String(b).replace(/\s+/g, "").toLowerCase();
    return na.indexOf(nb) >= 0 || nb.indexOf(na) >= 0;
}
