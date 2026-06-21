#include "StreamingDegradationChain.h"

#include <QSet>
#include <algorithm>

namespace {
constexpr const char* kRtsp   = "rtsp";
constexpr const char* kFlv    = "flv";
constexpr const char* kWsFlv  = "ws-flv";
constexpr const char* kHls    = "hls";
constexpr const char* kWebrtc = "webrtc";

QString canonicalize(QString protocol) {
    protocol = protocol.trimmed().toLower();
    protocol.replace('_', '-');
    return protocol;
}
}  // namespace

QStringList StreamingDegradationChain::defaultOrder() {
    return {QString::fromLatin1(kRtsp),
            QString::fromLatin1(kFlv),
            QString::fromLatin1(kWsFlv),
            QString::fromLatin1(kHls),
            QString::fromLatin1(kWebrtc)};
}

QStringList StreamingDegradationChain::normalize(const QStringList& input) {
    QStringList result;
    QSet<QString> seen;
    const QStringList def = defaultOrder();
    for (const QString& raw : input) {
        const QString p = canonicalize(raw);
        if (!isKnown(p)) continue;
        if (seen.contains(p)) continue;
        seen.insert(p);
        // Preserve user-supplied order, but unknown entries are dropped
        // by the guard above so we don't need to fall back to def here.
        result.append(p);
    }
    if (result.isEmpty())
        return def;
    return result;
}

bool StreamingDegradationChain::isKnown(const QString& protocol) {
    const QString p = canonicalize(protocol);
    return p == QLatin1String(kRtsp)  ||
           p == QLatin1String(kFlv)   ||
           p == QLatin1String(kWsFlv) ||
           p == QLatin1String(kHls)   ||
           p == QLatin1String(kWebrtc);
}

int StreamingDegradationChain::priorityOf(const QString& protocol) {
    const QString p = canonicalize(protocol);
    const QStringList def = defaultOrder();
    return def.indexOf(p);
}

QString StreamingDegradationChain::selectActive(const QStringList& chain,
                                                const QVariantMap& urls) {
    for (const QString& p : chain) {
        const QString url = urls.value(p).toString();
        if (!url.isEmpty())
            return p;
    }
    return {};
}

QVariantMap StreamingDegradationChain::toVariantMap(
    const QStringList& chain, const QVariantMap& urls) {
    QVariantMap out;
    for (const QString& p : chain)
        out.insert(p, urls.value(p));
    return out;
}

// ---------------------------------------------------------------------------
//  StreamingDegradationChainController
// ---------------------------------------------------------------------------

StreamingDegradationChainController::StreamingDegradationChainController(
    QObject* parent) : QObject(parent) {}

QStringList StreamingDegradationChainController::defaultOrder() const {
    return StreamingDegradationChain::defaultOrder();
}

StreamingDegradationChainController::DeviceState&
StreamingDegradationChainController::state(const QString& deviceId) {
    auto it = m_states.find(deviceId);
    if (it == m_states.end()) {
        it = m_states.insert(deviceId, DeviceState{});
        it->chain = StreamingDegradationChain::defaultOrder();
    }
    return it.value();
}

StreamingDegradationChainController::DeviceState
StreamingDegradationChainController::state(const QString& deviceId) const {
    auto it = m_states.find(deviceId);
    if (it == m_states.end()) {
        DeviceState s;
        s.chain = StreamingDegradationChain::defaultOrder();
        return s;
    }
    return it.value();
}

void StreamingDegradationChainController::setChain(
    const QString& deviceId, const QStringList& protocols) {
    DeviceState& s = state(deviceId);
    s.chain = StreamingDegradationChain::normalize(protocols);
    s.cursor = 0;
    emit chainChanged(deviceId);
    emit activeProtocolChanged(deviceId, s.chain.value(0));
}

QStringList StreamingDegradationChainController::chain(
    const QString& deviceId) const {
    return state(deviceId).chain;
}

void StreamingDegradationChainController::setUrls(
    const QString& deviceId, const QVariantMap& urls) {
    DeviceState& s = state(deviceId);
    s.urls = urls;
    s.cursor = 0;
    emit activeProtocolChanged(deviceId,
                               StreamingDegradationChain::selectActive(
                                   s.chain, s.urls));
}

QVariantMap StreamingDegradationChainController::urls(
    const QString& deviceId) const {
    return state(deviceId).urls;
}

QString StreamingDegradationChainController::urlFor(
    const QString& deviceId, const QString& protocol) const {
    return state(deviceId).urls.value(protocol).toString();
}

QString StreamingDegradationChainController::activeProtocol(
    const QString& deviceId) const {
    const DeviceState s = state(deviceId);
    if (s.chain.isEmpty()) return {};
    const int last = static_cast<int>(s.chain.size()) - 1;
    const int idx = std::clamp(s.cursor, 0, last);
    return s.chain.value(idx);
}

QString StreamingDegradationChainController::activeUrl(
    const QString& deviceId) const {
    const DeviceState s = state(deviceId);
    const QString p = activeProtocol(deviceId);
    if (p.isEmpty()) return {};
    return s.urls.value(p).toString();
}

bool StreamingDegradationChainController::advance(
    const QString& deviceId, const QString& failedProtocol) {
    DeviceState& s = state(deviceId);
    if (s.chain.isEmpty()) return false;

    // Start searching from cursor + 1 so we always move forward.
    const int start = s.cursor + 1;
    for (int i = start; i < s.chain.size(); ++i) {
        const QString& candidate = s.chain.at(i);
        if (s.urls.value(candidate).toString().isEmpty())
            continue;
        const QString previous = s.chain.value(s.cursor);
        s.cursor = i;
        emit protocolFailed(deviceId, failedProtocol, candidate);
        emit activeProtocolChanged(deviceId, candidate);
        return true;
    }

    // Wrapped around without finding a healthy protocol.
    emit protocolFailed(deviceId, failedProtocol, QString());
    return false;
}

void StreamingDegradationChainController::reset(const QString& deviceId) {
    DeviceState& s = state(deviceId);
    s.cursor = 0;
    emit activeProtocolChanged(deviceId,
                               StreamingDegradationChain::selectActive(
                                   s.chain, s.urls));
}
