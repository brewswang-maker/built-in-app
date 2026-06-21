# 内置应用端 (Built-in App) API 集成契约 — v5.1/v6.2 对齐

> **版本**: v1.0
> **日期**: 2026-06-19
> **状态**: 已实现，待回归
> **作者**: ShieldBox AI Team
> **关联**: docs/各端比对核实报告与开发计划.md / docs/华盾AI智能视频盒子v5.1-API接口设计文档.md

---

## 1. 范围

本文档定义 Qt GUI 内置应用端 (`clients/built-in-app/`) 与后端 box-sdk
(`box-sdk/src/core/RestApiHandlers.cpp`) 之间的 REST API 集成契约，
保证前后端接口畅通、可联调、可回归。

主要覆盖以下 8 个核心模块 + 联调测试规范：

| # | 模块 | Controller | QML 视图 |
|---|------|-----------|----------|
| 1 | 首页数据统计 | `StatisticsController` | `DashboardEnhancedView` |
| 2 | 设备管理 | `DeviceController` (扩展) | `DevicesView` |
| 3 | 实时预览 | `MediaController` + `StreamingController` | `VideoGridView` |
| 4 | 录像管理 | `RecordingController` | `RecordingView` |
| 5 | 流媒体管理 | `StreamingController` | `StreamManagementView` |
| 6 | AI 智能体 | `AIController` (扩展) | `AIChatView` |
| 7 | 事件规则 | `LinkageController` | `LinkageRuleView` |
| 8 | 系统管理 | `RbacController` + `AuditController` + `OTAController` | `SettingsView` |

---

## 2. 统一响应格式

所有 REST 端点必须返回：

```json
{
  "code": 0,
  "message": "success",
  "data": { ... },
  "request_id": "uuid",
  "timestamp": 1718700000.123
}
```

- `code = 0`：成功
- `code != 0`：失败（错误码见 `box-sdk/src/core/JsonUtils.cpp` ERR_*）
- 错误码样例：
  - `1001 ERR_PARAM` 参数错误
  - `1004 ERR_FORBIDDEN` 权限不足
  - `1005 ERR_TIMEOUT` 超时
  - `2002 ERR_DEVICE_OFFLINE` 设备离线

---

## 3. 端点清单（按模块）

### 3.1 首页数据统计（StatisticsController）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/stats/dashboard` | GET | 主看板：security_score / online_devices / today_alarms / by_level / hourly_trend / top_alarm_types / risk_zones |
| `/api/v1/stats/overview` | GET | 概览：total_devices / online_devices / today_alarms / security_score |
| `/api/v1/stats/false_alarm_baseline?days=30` | GET | 误报率基线 |
| `/api/v1/situation/hourly-stats` | GET | 24 小时告警趋势 |
| `/api/v1/situation/alarm-heatmap` | GET | 告警热力图 |
| `/api/v1/situation/overview` | GET | 态势总览 |
| `/api/v1/devices/stats` | GET | 设备统计（在线/离线/告警中） |
| `/api/v1/alarms/stats` | GET | 告警统计（含 by_level） |
| `/api/v1/alarms/history?limit=20` | GET | 最近事件流 |

### 3.2 设备管理（DeviceController 扩展）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/devices?page=&pageSize=&search=&protocol=` | GET | 列表（分页/搜索/筛选） |
| `/api/v1/devices/stats` | GET | 设备统计 |
| `/api/v1/devices/:id` | GET | 详情 |
| `/api/v1/devices/:id/channels` | GET | 设备通道 |
| `/api/v1/devices/:id/health` | GET | 健康检查 |
| `/api/v1/devices` | POST | 添加设备 |
| `/api/v1/devices/:id` | PUT | 更新设备（标签/分组） |
| `/api/v1/devices/:id` | DELETE | 删除设备 |
| `/api/v1/devices/discover` | POST | 设备发现 |
| `/api/v1/devices/:id/reboot` | POST | 重启 |
| `/api/v1/devices/:id/sync-time` | POST | 同步时间 |
| `/api/v1/config` | GET/PUT | 设备分组（device_groups 字段） |

批量操作（按 ID 循环调用后端单点接口实现）：
- `batchDelete(deviceIds[])` → 循环 DELETE
- `batchSetGroup(deviceIds[], groupId)` → 循环 PUT `{group_id}`
- `batchAddTag(deviceIds[], tag)` → 循环 PUT `{tags: [...]}`

### 3.3 实时预览（MediaController + StreamingController）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/streams` | GET | 流列表 |
| `/api/v1/streams/:id/start` | POST | 启动推流 |
| `/api/v1/streams/:id/stop` | POST | 停止推流 |
| `/api/v1/streams/:id/switch` | POST | 切换协议 (WebRTC/FLV/HLS) |
| `/api/v1/streams/:id/quality` | POST | 切换码流 (HD/SD/LD) |
| `/api/v1/streams/:id/multi-urls` | GET | 多协议播放地址 |
| `/api/v1/streams/:id/hls-url` | GET | HLS 地址 |
| `/api/v1/streams/proxy` | POST | 拉流代理 |
| `/api/v1/streams/zlm-status` | GET | ZLMediaKit 状态 |
| `/api/v1/zlm/status` | GET | ZLM 状态 |
| `/api/v1/zlm/streams` | GET | ZLM 活跃流 |
| `/api/v1/zlm/stream/screenshot` | POST | 截图 |
| `/api/v1/zlm/webrtc/play` | POST | WebRTC 播放 |
| `/api/v1/channels/:id/snapshot` | GET/POST | 通道快照 |
| `/api/v1/channels/:id/stream` | GET | 通道流地址 |
| `/api/v1/channels/ptz` | POST | PTZ 云台控制 |
| `/api/v1/ptz/:id/presets` | GET/POST/DELETE | 预置位 |
| `/api/v1/ptz/:id/absolute` | POST | PTZ 绝对位置 |
| `/api/v1/media/health` | GET | 媒体服务健康 |

布局切换：
- 1 宫格 → `currentLayout = 1`
- 4 宫格 → `currentLayout = 4`
- 9 宫格 → `currentLayout = 9`

### 3.4 录像管理（RecordingController）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/recordings?page=&pageSize=` | GET | 录像列表 |
| `/api/v1/recordings/query` | POST | 复合查询（channel_id/start_time/end_time） |
| `/api/v1/recordings/:id/play` | POST | 回放（返回 call_id + urls） |
| `/api/v1/recordings/:id/stop` | POST | 停止回放 |
| `/api/v1/recordings/:id/control` | POST | 控制（pause/resume/speed） |
| `/api/v1/recordings/:id/seek` | POST | 跳转 |
| `/api/v1/recordings/:id/download` | GET | 下载 URL |
| `/api/v1/recordings/download` | POST | 批量下载 |
| `/api/v1/recordings/:id` | DELETE | 删除 |
| `/api/v1/recording/:id/start` | POST | 手动录像 |
| `/api/v1/recording/:id/stop` | POST | 停止录像 |

### 3.5 AI 智能体（AIController）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/ai/chat` | POST | 非流式对话 |
| `/api/v1/ai/chat/stream` | GET | 流式 SSE（含 thinking/tool_call/text 事件） |
| `/api/v1/ai/chat/json` | POST | 结构化 JSON 响应 |
| `/api/v1/ai/chat/multimodal` | POST | 多模态（文本+图片） |
| `/api/v1/ai/chat/history` | GET | 历史消息 |
| `/api/v1/ai/sessions` | GET | 会话列表 |
| `/api/v1/ai/sessions/:id` | GET | 会话详情 |
| `/api/v1/ai/sessions/:id` | DELETE | 删除会话 |
| `/api/v1/ai/suggestions` | GET | 快捷指令 |
| `/api/v1/ai/agents` | GET | 可用 Agents |
| `/api/v1/ai/agent/invoke` | POST | 调用 Agent |
| `/api/v1/ai/analyze/alarm` | POST | 告警分析 |
| `/api/v1/ai/report/generate` | POST | 报告生成 |
| `/api/v1/ai/tools` | GET | 工具列表 |
| `/api/v1/ai/tools` | POST | 调用工具 |
| `/api/v1/ai/models` | GET | 模型列表 |

SSE 事件类型（`/api/v1/ai/chat/stream`）：
- `text` / `content` — Token 流
- `thinking` — 思考步骤（ReAct）
- `tool_call` — 工具调用请求
- `tool_result` — 工具调用结果
- `session` — 会话 ID 变化
- `done` — 流结束

### 3.6 事件规则（LinkageController）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/linkage/rules?page=&page_size=&tag=` | GET | 规则列表 |
| `/api/v1/linkage/rules/:id` | GET | 规则详情 |
| `/api/v1/linkage/rules` | POST | 创建规则 |
| `/api/v1/linkage/rules/:id` | PUT | 更新规则 |
| `/api/v1/linkage/rules/:id` | DELETE | 删除规则 |
| `/api/v1/linkage/rules/batch-toggle` | POST | 批量启停 |
| `/api/v1/linkage/rules/dry-run` | POST | 干跑测试 |
| `/api/v1/linkage/rules/trigger-test` | POST | 触发测试 |
| `/api/v1/linkage/rules/rule-templates` | GET | 规则模板 |
| `/api/v1/linkage/rules/rule-templates/:id/apply` | POST | 应用模板 |
| `/api/v1/linkage/logs` | GET | 执行日志 |
| `/api/v1/linkage/stats` | GET | 统计 |
| `/api/v1/linkage/latency-stats` | GET | 延迟统计 |
| `/api/v1/linkage/action-types` | GET | 动作类型 |
| `/api/v1/linkage/action-log/:id/retry` | POST | 重试动作 |
| `/api/v1/linkage/time-templates` | GET/POST/PUT/DELETE | 时间模板 |

### 3.7 系统管理（RBAC + Audit + OTA + Notification）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/auth/login` | POST | 登录（JWT） |
| `/api/v1/auth/me` | GET | 当前用户 |
| `/api/v1/users` | GET | 用户列表 |
| `/api/v1/users/:id` | PUT/DELETE | 更新/删除 |
| `/api/v1/users/:id/reset-password` | POST | 重置密码 |
| `/api/v1/users/import` | POST | 批量导入 |
| `/api/v1/rbac/roles` | GET/POST | 角色 |
| `/api/v1/rbac/roles/:id` | GET/PUT/DELETE | 角色详情 |
| `/api/v1/rbac/permissions` | GET | 权限 |
| `/api/v1/rbac/permissions/tree` | GET | 权限树 |
| `/api/v1/rbac/users` | GET | RBAC 用户 |
| `/api/v1/rbac/users/:userId/roles` | POST | 分配角色 |
| `/api/v1/rbac/users/:userId/roles/:roleId` | DELETE | 撤销角色 |
| `/api/v1/audit/logs` | GET | 审计日志 |
| `/api/v1/audit/stats` | GET | 审计统计 |
| `/api/v1/audit/export` | POST | 导出审计 |
| `/api/v1/ota/firmwares` | GET/POST | 固件 |
| `/api/v1/ota/tasks` | GET/POST | 升级任务 |
| `/api/v1/ota/tasks/:id/execute` | POST | 执行升级 |
| `/api/v1/ota/tasks/:id/cancel` | POST | 取消 |
| `/api/v1/ota/tasks/:id/retry` | POST | 重试 |
| `/api/v1/ota/status` | GET | OTA 状态 |
| `/api/v1/notifications` | GET | 通知 |
| `/api/v1/export` | POST/GET | 数据导出 |
| `/api/v1/config/export` | POST | 配置导出 |
| `/api/v1/config/import` | POST | 配置导入 |

---

## 4. Controller ↔ QML 绑定

```cpp
// app/main.cpp 注册示例
engine.rootContext()->setContextProperty("statisticsController", &statisticsController);
engine.rootContext()->setContextProperty("rbacController", &rbacController);
engine.rootContext()->setContextProperty("streamingController", &streamingController);
engine.rootContext()->setContextProperty("recordingController", &recordingController);
engine.rootContext()->setContextProperty("channelModel", &channelModel);
engine.rootContext()->setContextProperty("streamModel", &streamModel);
```

QML 中调用：
```qml
Button {
    onClicked: statisticsController.refreshDashboard()
}
Text {
    text: statisticsController.securityScore
}
```

---

## 5. 联调测试规范

### 5.1 测试入口

```bash
# 全部联调测试
pytest tests/integration/test_builtin_app_api.py -v

# 仅统计/RBAC/录像/AI 模块
pytest tests/integration/test_builtin_app_api.py -v -k "Statistics or Rbac or Recording or Agent"

# 跳过需要真实服务的测试
SKIP_LIVE=true pytest tests/integration/test_builtin_app_api.py -v
```

### 5.2 测试覆盖矩阵

| 模块 | 测试类 | 端点数 |
|------|--------|--------|
| 统计 | `TestBuiltinAppStatistics` | 8 |
| RBAC | `TestBuiltinAppRbac` | 4 |
| 流媒体 | `TestBuiltinAppStreaming` | 5 |
| 录像 | `TestBuiltinAppRecording` | 4 |
| AI | `TestBuiltinAppAIAgent` | 9 |
| 联动 | `TestBuiltinAppLinkage` | 6 |
| 设备 | `TestBuiltinAppDevice` | 7 |
| 告警 | `TestBuiltinAppAlarm` | 6 |
| 系统 | `TestBuiltinAppSystem` | 7 |
| 性能 | `TestBuiltinAppPerformance` | 3 |

### 5.3 关键校验

1. **响应格式**：`code/message/data/request_id/timestamp` 五字段齐全
2. **成功码**：`code == 0`
3. **分页**：`{ items, total, page, page_size }`
4. **错误码**：参数错误 1001，权限 1004，超时 1005，设备离线 2002
5. **SSE 流**：`/api/v1/ai/chat/stream` 必须返回 `data:` 事件流
6. **批量**：循环调用后端单点接口，前端聚合请求/响应
7. **并发**：≥ 10 并发请求成功率 ≥ 50%（其余可能受后端限流影响）

---

## 6. 已知差异与折中

| 差异 | 处理 |
|------|------|
| 后端无 `/api/v1/devices/batch` | 前端循环调用 `DELETE /api/v1/devices/:id` |
| 后端无 `/api/v1/devices/groups` 专用端点 | 通过 `/api/v1/config.device_groups` 维护 |
| 后端无 `/api/v1/recordings/:id/tags` | 通过 PUT `/api/v1/recordings/:id` 的 metadata 字段 |
| 后端 AI 会话模型字段差异 | 前端兼容 `messages/sessions/data.items` |
| 后端 `/api/v1/streams` 无分页字段 | 默认返回完整列表，前端不强制分页 |

---

## 7. 后续工作

| 任务 | 优先级 | 负责人 |
|------|--------|--------|
| 完善 `DashboardEnhancedView` 嵌入主导航 | 高 | 前端-B |
| 完善 `RbacView` (RBAC UI) | 高 | 前端-B |
| 完善 `StreamManagementView` 实时控制 | 中 | 前端-B |
| 完善 `RecordingView` 回放/下载/标签 | 中 | 前端-B |
| 完善 `AIChatView` ReAct 展示 | 中 | 前端-B |
| 增加 QML 单元测试 (Qt Test) | 低 | 测试 |
| 增加 e2e Playwright/Squish 测试 | 低 | 测试 |
