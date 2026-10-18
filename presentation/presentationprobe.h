#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QWindow>

struct wl_display;
struct wl_event_queue;
struct wl_registry;
struct wp_presentation;
struct wp_presentation_feedback;

// Correlates wp_presentation feedback with one exact Qt Wayland surface.
//
// arm() must only be called while the window already shows an immutable,
// fully opaque black scene and Qt has swapped at least one frame of it. The
// feedback object is attached to the next wl_surface.commit of that surface;
// only a `presented` event for that object is reported as success. Missing
// protocol support, a non-Wayland platform, a different window, `discarded`
// or a second arm while one is pending all fail closed.
class PresentationProbe : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool pending READ pending NOTIFY pendingChanged)
    Q_PROPERTY(QString unavailableReason READ unavailableReason NOTIFY availableChanged)

public:
    explicit PresentationProbe(QObject *parent = nullptr);
    ~PresentationProbe() override;

    bool available() const { return m_presentation != nullptr; }
    bool pending() const { return m_feedback != nullptr; }
    QString unavailableReason() const { return m_unavailableReason; }

    // Returns a positive token, or 0 when the request was refused.
    Q_INVOKABLE int arm(QWindow *window);
    Q_INVOKABLE void disarm();

signals:
    void availableChanged();
    void pendingChanged();
    void presented(int token, quint32 flags);
    void discarded(int token);
    void failed(int token, const QString &reason);

private:
    void connectToCompositor();
    void dispatch();
    void finishFeedback();

public:
    // libwayland listener callbacks; not part of the QML API.
    static void handleGlobal(void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t version);
    static void handleGlobalRemove(void *data, wl_registry *registry, uint32_t name);
    static void handleClockId(void *data, wp_presentation *presentation, uint32_t clockId);
    static void handleSyncOutput(void *data, struct wp_presentation_feedback *feedback, struct wl_output *output);
    static void handlePresented(void *data, struct wp_presentation_feedback *feedback, uint32_t tvSecHi, uint32_t tvSecLo,
                                uint32_t tvNsec, uint32_t refresh, uint32_t seqHi, uint32_t seqLo, uint32_t flags);
    static void handleDiscarded(void *data, struct wp_presentation_feedback *feedback);

private:

    wl_display *m_display = nullptr;
    wl_event_queue *m_queue = nullptr;
    void *m_displayWrapper = nullptr;
    wl_registry *m_registry = nullptr;
    wp_presentation *m_presentation = nullptr;
    uint32_t m_presentationName = 0;
    wp_presentation_feedback *m_feedback = nullptr;
    QPointer<QWindow> m_window;
    void *m_surface = nullptr;
    int m_token = 0;
    int m_nextToken = 1;
    QString m_unavailableReason;
    QTimer m_dispatchTimer;
};
