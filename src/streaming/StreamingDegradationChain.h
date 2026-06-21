#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QHash>

/**
 * @brief StreamingDegradationChain
 *
 * Static helpers for the canonical 5-protocol streaming degradation
 * chain. Default order (high → low quality / compatibility):
 *
 *   rtsp -> flv -> ws-flv -> hls -> webrtc
 *
 * The chain is consulted in order by the QML video tile when the
 * primary protocol fails to deliver frames within the allowed
 * timeout. The stateful per-device cursor lives in
 * StreamingDegradationChainController.
 */
class StreamingDegradationChain {
public:
    /// Canonical protocol identifiers, in preferred order.
    static QStringList defaultOrder();

    /// Returns the lower-cased, deduplicated, validated list of
    /// protocols. Accepts "rtsp", "flv", "ws-flv" (or "ws_flv"),
    /// "hls", "webrtc". Unknown entries are dropped.
    static QStringList normalize(const QStringList& input);

    /// Returns true when @p protocol is a known streaming protocol.
    static bool isKnown(const QString& protocol);

    /// Returns the priority index (0 = highest). Unknown -> -1.
    static int priorityOf(const QString& protocol);

    /// Picks the first protocol in @p chain that has a non-empty URL.
    static QString selectActive(const QStringList& chain,
                                const QVariantMap& urls);

    /// JSON-friendly view of {protocol: url} trimmed to @p chain.
    static QVariantMap toVariantMap(const QStringList& chain,
                                    const QVariantMap& urls);
};

/**
 * @brief StreamingDegradationChainController
 *
 * QML-facing controller. Owns the per-device state (active chain +
 * URL map) and emits protocolFailed() so the QML tile can advance to
 * the next protocol in the chain.
 */
class StreamingDegradationChainController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList defaultOrder READ defaultOrder CONSTANT)
public:
    explicit StreamingDegradationChainController(QObject* parent = nullptr);

    QStringList defaultOrder() const;

    /// Configures the degradation chain for a single device/channel.
    /// Pass an empty list to fall back to the default order.
    Q_INVOKABLE void setChain(const QString& deviceId,
                              const QStringList& protocols);

    /// Returns the active chain for a device (default order if unset).
    Q_INVOKABLE QStringList chain(const QString& deviceId) const;

    /// Stores the URL map returned by the server for a device.
    Q_INVOKABLE void setUrls(const QString& deviceId,
                             const QVariantMap& urls);

    /// Returns the URL map for a device.
    Q_INVOKABLE QVariantMap urls(const QString& deviceId) const;

    /// Returns the URL for a single protocol (empty string if unknown).
    Q_INVOKABLE QString urlFor(const QString& deviceId,
                               const QString& protocol) const;

    /// Returns the currently selected protocol for a device.
    Q_INVOKABLE QString activeProtocol(const QString& deviceId) const;

    /// Returns the URL the QML tile should bind to (active protocol).
    Q_INVOKABLE QString activeUrl(const QString& deviceId) const;

    /// Advances the active protocol by one step, wrapping at the end.
    /// Emits protocolFailed() with the failing protocol so the QML
    /// tile can present a "switch to ws-flv" toast.
    Q_INVOKABLE bool advance(const QString& deviceId,
                             const QString& failedProtocol);

    /// Resets the cursor to the highest-priority protocol with a URL.
    Q_INVOKABLE void reset(const QString& deviceId);

signals:
    void protocolFailed(const QString& deviceId,
                        const QString& failedProtocol,
                        const QString& nextProtocol);
    void activeProtocolChanged(const QString& deviceId,
                               const QString& protocol);
    void chainChanged(const QString& deviceId);

private:
    struct DeviceState {
        QStringList chain;          // normalized, ordered
        QVariantMap urls;           // protocol -> url
        int cursor = 0;             // index into chain
    };

    DeviceState& state(const QString& deviceId);
    DeviceState state(const QString& deviceId) const;

    QHash<QString, DeviceState> m_states;
};
