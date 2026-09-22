// tests/TestHttpStub.h
//
// [api-contract 2026-09-22] 测试共享 HTTP/1.1 stub (从 test_ota_bootid.cpp 抽取并增强):
//   - 记录请求(method/path/body) → 用于断言契约(路径前缀/方法/请求体)
//   - body 感知: 按 Content-Length 收全 body 后再响应(修复并发分片问题)
//   - envelopeData 助手: 与后端 makeOkResponse 同构的信封 {code,data,message,timestamp}
//     (data 支持对象/数组两种形态 — linkage/stats 等端点的 data 是数组)
//   - responder 返回空 QByteArray → 直接断链(模拟设备重启期/服务不可达)
//
// 用法:
//   StubHttpServer srv;
//   srv.responder = [](const QString& m, const QString& p, const QByteArray& b) {
//       if (p == "/api/v1/xxx") return envelopeData(QJsonObject{{"k", 1}});
//       return QByteArray();
//   };
//   srv.listen(QHostAddress::LocalHost, 0);
//   ApiClient api; api.setBaseUrl(QString("http://127.0.0.1:%1").arg(srv.serverPort()));
//
#pragma once

#include <QByteArray>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QList>
#include <QTcpServer>
#include <QTcpSocket>
#include <QVector>

#include <functional>

namespace teststub {

struct StubRequest {
    QString method;
    QString path;
    QByteArray body;
};

/// 标准信封 {code:0, message:"success", data:<任意>, timestamp} (与 makeOkResponse 同构)
inline QByteArray envelopeData(const QJsonValue& data) {
    QJsonObject o;
    o["code"] = 0;
    o["data"] = data;
    o["message"] = "success";
    o["timestamp"] = double(QDateTime::currentMSecsSinceEpoch());
    return QJsonDocument(o).toJson(QJsonDocument::Compact);
}

inline QByteArray envelope(const QJsonObject& data) {
    return envelopeData(QJsonValue(data));
}

}  // namespace teststub

/// 最小 HTTP/1.1 stub 服务: 单连接-单响应; responder 返回空 → 断链
class StubHttpServer : public QTcpServer {
public:
    std::function<QByteArray(const QString& method, const QString& path,
                             const QByteArray& body)> responder;

    /// 已收到的请求 (按到达顺序)
    QVector<teststub::StubRequest> requests;

    /// 路径前缀计数 (锚定式: p.startsWith(prefix), 不含子串误判)
    int requestCount(const QString& pathPrefix) const {
        int n = 0;
        for (const auto& r : requests)
            if (r.path.startsWith(pathPrefix)) ++n;
        return n;
    }

    void clearRequests() { requests.clear(); }

protected:
    void incomingConnection(qintptr socketDescriptor) override {
        auto* sock = new QTcpSocket(this);
        sock->setSocketDescriptor(socketDescriptor);
        auto* buf = new QByteArray;
        connect(sock, &QTcpSocket::readyRead, sock, [this, sock, buf]() {
            buf->append(sock->readAll());
            const int headEnd = buf->indexOf("\r\n\r\n");
            if (headEnd < 0) return;  // 头部未收全

            const QByteArray head = buf->left(headEnd);
            const QList<QByteArray> lines = head.split('\n');
            const QList<QByteArray> first =
                lines.value(0).trimmed().split(' ');
            const QString method = QString::fromUtf8(first.value(0));
            const QString path = QString::fromUtf8(first.value(1));

            // Content-Length 感知: 等 body 收全再响应 (POST/PUT 请求体可能跨包)
            int contentLen = 0;
            for (const QByteArray& line : lines) {
                const QByteArray t = line.trimmed();
                if (t.toLower().startsWith("content-length:"))
                    contentLen = t.mid(t.indexOf(':') + 1).trimmed().toInt();
            }
            if (buf->size() < headEnd + 4 + contentLen) return;  // body 未收全

            const QByteArray body = buf->mid(headEnd + 4, contentLen);
            requests.append({method, path, body});

            const QByteArray resp = responder ? responder(method, path, body)
                                              : QByteArray();
            if (resp.isEmpty()) {  // 空响应 → 直接断开 (QNetworkReply 得 RemoteHostClosedError)
                sock->disconnectFromHost();
                return;
            }
            QByteArray out = "HTTP/1.1 200 OK\r\n"
                             "Content-Type: application/json\r\n"
                             "Content-Length: " +
                             QByteArray::number(resp.size()) +
                             "\r\n"
                             "Connection: close\r\n\r\n" +
                             resp;
            sock->write(out);
            sock->flush();
            sock->disconnectFromHost();
        });
        connect(sock, &QTcpSocket::disconnected, sock, &QObject::deleteLater);
    }
};
