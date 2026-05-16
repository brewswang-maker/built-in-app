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
#include "models/DeviceListModel.h"
#include "models/AlarmListModel.h"
#include "utils/ThemeConfig.h"
#include "utils/ApiClient.h"

int main(int argc, char *argv[]) {
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QGuiApplication app(argc, argv);

    app.setOrganizationName("ShieldBox");
    app.setApplicationName("ShieldBox AI");
    app.setApplicationVersion("1.0.0");

    // 强制使用自定义QML风格
    QQuickStyle::setStyle("Basic");

    // 加载中文字体
    QFont font("Noto Sans CJK SC", 13);
    app.setFont(font);

    // ── API Client (连接本地box-sdk) ──
    ApiClient apiClient;
    apiClient.setBaseUrl("http://localhost:8080");
    apiClient.setTimeoutMs(5000);

    // ── Models ──
    DeviceListModel deviceModel;
    AlarmListModel alarmModel;

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

    // ── QML Engine ──
    QQmlApplicationEngine engine;

    // 注册controllers到QML上下文
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
    engine.rootContext()->setContextProperty("deviceModel", &deviceModel);
    engine.rootContext()->setContextProperty("alarmModel", &alarmModel);
    engine.rootContext()->setContextProperty("apiClient", &apiClient);

    // 注册QML类型
    qmlRegisterUncreatableType<DeviceController>("ShieldBox", 1, 0, "DeviceCtrl", "Cannot create");
    qmlRegisterUncreatableType<AlarmController>("ShieldBox", 1, 0, "AlarmCtrl", "Cannot create");
    qmlRegisterUncreatableType<MediaController>("ShieldBox", 1, 0, "MediaCtrl", "Cannot create");
    qmlRegisterUncreatableType<AIController>("ShieldBox", 1, 0, "AICtrl", "Cannot create");

    // 加载主QML
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
