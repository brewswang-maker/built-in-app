# ShieldBox Built-in App

ShieldBox 内置应用是运行在边缘网关上的本地 Qt/QML GUI 程序，提供实时监控、告警管理、AI 对话、算法配置等功能的可视化操作界面。

## 架构

```
┌─────────────────────────────────────────────┐
│                  UI Layer (QML)              │
│   MainView / AlarmPopup / AIChat / Settings │
└──────────────────┬──────────────────────────┘
                   │ QML ↔ C++ Bridge
┌──────────────────▼──────────────────────────┐
│             Controller Layer (C++)           │
│   CameraController / AlarmController / ...   │
└──────────────────┬──────────────────────────┘
                   │ HTTP REST
┌──────────────────▼──────────────────────────┐
│           box-sdk REST API                   │
│              localhost:8080                  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         ShieldBox Edge Gateway              │
│          (视频分析 / AI推理)                  │
└─────────────────────────────────────────────┘
```

## 功能列表

| 功能 | 说明 |
|------|------|
| 宫格预览 | 支持 1/4/9/16 宫格实时视频预览 |
| 告警弹窗 | 实时告警推送，支持确认/误报标记 |
| AI 对话 | 与本地 AI 模型交互，查询分析结果 |
| 算法配置 | 配置 AI 分析算法参数和策略 |
| 系统设置 | 网络、存储、设备管理等系统级配置 |
| 统计 | 告警统计、设备状态、分析报告 |

## 构建要求

- **Qt**: 6.5 或更高版本
- **CMake**: 3.20 或更高版本
- **编译器**: 支持 C++17 的编译器 (GCC 9+, Clang 10+, MSVC 2019+)

## 构建步骤

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
```

### 交叉编译 (ARM64 / 算能 BM1684X)

```bash
# 设置 aarch64 工具链
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir build-arm64 && cd build-arm64
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchains/aarch64-linux-gnu.cmake
make -j$(nproc)
```

## 目录结构

```
built-in-app/
├── CMakeLists.txt          # 顶层构建配置
├── main.cpp                # 应用入口
├── README.md               # 本文件
├── resources/
│   ├── icons/              # SVG 图标资源
│   │   └── README.md       # 图标规范
│   ├── qml/                # QML 界面文件
│   │   ├── MainView.qml
│   │   ├── AlarmPopup.qml
│   │   ├── AIChat.qml
│   │   ├── AlgorithmConfig.qml
│   │   ├── Statistics.qml
│   │   └── Settings.qml
│   ├── translations/       # 国际化翻译
│   │   └── zh_CN.ts
│   └── resources.qrc       # Qt 资源文件
├── src/
│   ├── controllers/        # 业务控制器
│   ├── models/             # 数据模型
│   ├── utils/              # 工具函数
│   └── bridge/             # QML-C++ 桥接层
└── toolchains/             # 交叉编译工具链文件
```

## 安装

构建产物默认安装到 `/opt/shieldbox/bin/`:

```bash
sudo make install
```

## 开发

```bash
# 使用 Qt Creator 打开
qtcreator CMakeLists.txt

# 或命令行开发
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
```

## License

Proprietary - ShieldBox Internal Use Only
