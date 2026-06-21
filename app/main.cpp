/**
 * @file main.cpp
 * @brief ShieldBox内置应用入口
 *
 * 初始化Qt应用引擎 + 注册Controllers + 加载主QML
 * 通信方式: Local REST API (http://localhost:8080) 连接 box-sdk
 */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QFont>

#include "controllers/DeviceController.h"
#include "controllers/MediaController.h"
#include "controllers/AlarmController.h"
#include "controllers/AIController.h"
#include "controllers/ConfigController.h"
#include "controllers/StatusController.h"
#include "controllers/LinkageController.h"
#include "controllers/PipelineController.h"
#include "controllers/OTAController.h"
#include "controllers/AuditController.h"
#include "controllers/FederationController.h"
#include "controllers/NotificationController.h"
#include "controllers/AlgorithmController.h"
#include "controllers/StatisticsController.h"
#include "controllers/RbacController.h"
#include "controllers/StreamingController.h"
#include "controllers/RecordingController.h"
#include "streaming/StreamingDegradationChain.h"
#include "models/DeviceListModel.h"
#include "models/AlarmListModel.h"
#include "models/AlgorithmListModel.h"
#include "models/ChannelListModel.h"
#include "models/StreamListModel.h"
#include "utils/ThemeConfig.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"

int main(int argc, char *argv[]) {
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QGuiApplication app(argc, argv);

    app.setOrganizationName("ShieldBox");
    app.setApplicationName("ShieldBox AI");
    app.setApplicationVersion("1.0.0");

    QQuickStyle::setStyle("Basic");

    QFont font("Noto Sans CJK SC", 13);
    app.setFont(font);

    // ── API Client (连接本地box-sdk) ──
    ApiClient apiClient;
    apiClient.setBaseUrl("http://localhost:8080");
    apiClient.setTimeoutMs(5000);

    // ── 统一 WebSocket 消息路由(规范 b4ced019 / 700c35a7) ──
    // 全应用共用单条长连接,按 9 type 路由给各 Controller
    WsMessageRouter* wsRouter = WsMessageRouter::instance();
    if (wsRouter) {
        wsRouter->bindApiClient(&apiClient);
    }

    // ── Models ──
    DeviceListModel deviceModel;
    AlarmListModel alarmModel;
    AlgorithmListModel algorithmModel;
    ChannelListModel channelModel;
    StreamListModel streamModel;

    // ── Controllers ──
    DeviceController deviceController(&apiClient);
    deviceController.setDeviceModel(&deviceModel);

    AlarmController alarmController(&apiClient);
    alarmController.setAlarmModel(&alarmModel);

    MediaController mediaController(&apiClient);
    AIController aiController(&apiClient);
    ConfigController configController(&apiClient);
    StatusController statusController(&apiClient);

    // ── New Controllers ──
    LinkageController linkageController(&apiClient);
    PipelineController pipelineController(&apiClient);
    OTAController otaController(&apiClient);
    AuditController auditController(&apiClient);
    FederationController federationController(&apiClient);
    NotificationController notificationController;
    ThemeConfig themeConfig;

    AlgorithmController algorithmController(&apiClient);
    algorithmController.setAlgorithmModel(&algorithmModel);

    // ── v5.1/v6.2 New Controllers ──
    StatisticsController statisticsController(&apiClient);
    RbacController rbacController(&apiClient);
    StreamingController streamingController(&apiClient);
    RecordingController recordingController(&apiClient);

    // ── QML Engine ──
    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("deviceController", &deviceController);
    engine.rootContext()->setContextProperty("alarmController", &alarmController);
    engine.rootContext()->setContextProperty("mediaController", &mediaController);
    engine.rootContext()->setContextProperty("aiController", &aiController);
    engine.rootContext()->setContextProperty("configController", &configController);
    engine.rootContext()->setContextProperty("statusController", &statusController);
    engine.rootContext()->setContextProperty("linkageController", &linkageController);
    engine.rootContext()->setContextProperty("pipelineController", &pipelineController);
    engine.rootContext()->setContextProperty("otaController", &otaController);
    engine.rootContext()->setContextProperty("auditController", &auditController);
    engine.rootContext()->setContextProperty("federationController", &federationController);
    engine.rootContext()->setContextProperty("notificationController", &notificationController);
    engine.rootContext()->setContextProperty("theme", &themeConfig);
    engine.rootContext()->setContextProperty("algorithmController", &algorithmController);
    engine.rootContext()->setContextProperty("algorithmModel", &algorithmModel);
    engine.rootContext()->setContextProperty("deviceModel", &deviceModel);
    engine.rootContext()->setContextProperty("alarmModel", &alarmModel);
    engine.rootContext()->setContextProperty("apiClient", &apiClient);
    // v5.1/v6.2 新增控制器
    engine.rootContext()->setContextProperty("statisticsController", &statisticsController);
    engine.rootContext()->setContextProperty("rbacController", &rbacController);
    engine.rootContext()->setContextProperty("streamingController", &streamingController);
    engine.rootContext()->setContextProperty("recordingController", &recordingController);
    engine.rootContext()->setContextProperty("channelModel", &channelModel);
    engine.rootContext()->setContextProperty("streamModel", &streamModel);
    // 统一 WS 路由器 (规范 b4ced019): QML 可订阅 stateString / reconnectAttempts
    if (wsRouter) {
        engine.rootContext()->setContextProperty("wsRouter", wsRouter);
    }

    // 注册QML类型
    qmlRegisterUncreatableType<DeviceController>("ShieldBox", 1, 0, "DeviceCtrl", "Cannot create");
    qmlRegisterUncreatableType<AlarmController>("ShieldBox", 1, 0, "AlarmCtrl", "Cannot create");
    qmlRegisterUncreatableType<MediaController>("ShieldBox", 1, 0, "MediaCtrl", "Cannot create");
    qmlRegisterUncreatableType<AIController>("ShieldBox", 1, 0, "AICtrl", "Cannot create");
    qmlRegisterUncreatableType<StreamingDegradationChainController>(
        "ShieldBox", 1, 0, "StreamingDegradationChainCtrl", "Cannot create");
    if (wsRouter) {
        qmlRegisterUncreatableType<WsMessageRouter>("ShieldBox", 1, 0, "WsRouter", "Cannot create");
    }

    // 应用退出时优雅关闭 WS (规范 700c35a7)
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [wsRouter]() {
        if (wsRouter) wsRouter->shutdown();
    });

    // 加载主QML
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url, wsRouter](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
        // QML 加载成功后启动统一 WS 连接 (规范 700c35a7)
        if (obj && url == objUrl && wsRouter) {
            wsRouter->openConnection();
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
