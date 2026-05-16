# Icon Resources

ShieldBox 内置应用所需的图标资源。

## 规范

- **格式**: SVG (可缩放矢量图形)
- **基准尺寸**: 64x64px (viewBox)
- **颜色**: 单色，使用 `currentColor` 以支持主题切换
- **命名**: 小写 + 连字符，如 `camera.svg`

## 图标清单

### 监控相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| 📷 | `camera.svg` | 摄像头 / 视频源 |
| ▶️ | `play.svg` | 播放 |
| ⏹️ | `stop.svg` | 停止 |
| 🔴 | `record.svg` | 录制 |
| 📸 | `snapshot.svg` | 截图 |
| 🔼 | `ptz-up.svg` | 云台向上 |
| 🔽 | `ptz-down.svg` | 云台向下 |
| ◀️ | `ptz-left.svg` | 云台向左 |
| ▶️ | `ptz-right.svg` | 云台向右 |

### 布局相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| ⛶ | `fullscreen.svg` | 全屏 |
| ▦ | `grid-1.svg` | 单画面 |
| ▦ | `grid-4.svg` | 4宫格 |
| ▦ | `grid-9.svg` | 9宫格 |
| ▦ | `grid-16.svg` | 16宫格 |

### 告警相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| 🚨 | `alarm.svg` | 告警 |
| ✅ | `confirm.svg` | 确认告警 |
| ❌ | `false-alarm.svg` | 标记误报 |
| 🔇 | `mute.svg` | 静音告警 |

### AI 相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| 🤖 | `ai.svg` | AI 对话 |
| 📤 | `send.svg` | 发送消息 |

### 算法相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| ⚙️ | `algorithm.svg` | 算法配置 |

### 系统相关
| 图标 | 文件名 | 说明 |
|------|--------|------|
| ⚙️ | `settings.svg` | 系统设置 |
| 📊 | `stats.svg` | 统计数据 |
| ⬇️ | `download.svg` | 下载 |
| ⬆️ | `upload.svg` | 上传 |

## 使用方式

图标通过 Qt 资源系统 (QRC) 加载，在 QML 中使用:

```qml
Image {
    source: "qrc:/icons/camera.svg"
    width: 32
    height: 32
}
```

## 添加新图标

1. 将 SVG 文件放入此目录
2. 更新 `resources.qrc` 资源清单
3. 更新本 README 的图标清单
