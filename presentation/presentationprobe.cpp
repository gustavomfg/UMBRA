#include "presentationprobe.h"

#include <QGuiApplication>
#include <QQuickWindow>
#include <qpa/qplatformnativeinterface.h>

#include <wayland-client.h>

#include "presentation-time-client-protocol.h"

namespace {
const wl_registry_listener registryListener = {
    &PresentationProbe::handleGlobal,
    &PresentationProbe::handleGlobalRemove,
};

const wp_presentation_listener presentationListener = {
    &PresentationProbe::handleClockId,
};

const wp_presentation_feedback_listener feedbackListener = {
    &PresentationProbe::handleSyncOutput,
    &PresentationProbe::handlePresented,
    &PresentationProbe::handleDiscarded,
};
} // namespace

PresentationProbe::PresentationProbe(QObject *parent)
    : QObject(parent)
{
    m_dispatchTimer.setInterval(4);
    connect(&m_dispatchTimer, &QTimer::timeout, this, &PresentationProbe::dispatch);
    connectToCompositor();
}

PresentationProbe::~PresentationProbe()
{
    m_dispatchTimer.stop();
    if (m_feedback)
        wp_presentation_feedback_destroy(m_feedback);
    if (m_presentation)
        wp_presentation_destroy(m_presentation);
    if (m_registry)
        wl_registry_destroy(m_registry);
    if (m_displayWrapper)
        wl_proxy_wrapper_destroy(m_displayWrapper);
    if (m_queue)
        wl_event_queue_destroy(m_queue);
}

void PresentationProbe::connectToCompositor()
{
    if (QGuiApplication::platformName() != QLatin1String("wayland")) {
        m_unavailableReason = QStringLiteral("platform is not wayland");
        return;
    }

    auto *waylandApp = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    m_display = waylandApp ? waylandApp->display() : nullptr;
    if (!m_display) {
        m_unavailableReason = QStringLiteral("no wl_display");
        return;
    }

    // A private queue keeps these events away from Qt's own dispatch.
    m_queue = wl_display_create_queue(m_display);
    m_displayWrapper = wl_proxy_create_wrapper(m_display);
    wl_proxy_set_queue(static_cast<wl_proxy *>(m_displayWrapper), m_queue);
    m_registry = wl_display_get_registry(static_cast<wl_display *>(m_displayWrapper));
    wl_registry_add_listener(m_registry, &registryListener, this);

    if (wl_display_roundtrip_queue(m_display, m_queue) < 0) {
        m_unavailableReason = QStringLiteral("registry roundtrip failed");
        return;
    }
    if (!m_presentation) {
        m_unavailableReason = QStringLiteral("compositor does not advertise wp_presentation");
        return;
    }
    m_unavailableReason.clear();
}

void PresentationProbe::handleGlobal(void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    auto *self = static_cast<PresentationProbe *>(data);
    if (qstrcmp(interface, wp_presentation_interface.name) != 0 || self->m_presentation)
        return;
    self->m_presentationName = name;
    self->m_presentation = static_cast<wp_presentation *>(
        wl_registry_bind(registry, name, &wp_presentation_interface, qMin<uint32_t>(version, 1)));
    wp_presentation_add_listener(self->m_presentation, &presentationListener, self);
}

void PresentationProbe::handleGlobalRemove(void *data, wl_registry *, uint32_t name)
{
    auto *self = static_cast<PresentationProbe *>(data);
    if (!self->m_presentation || name != self->m_presentationName)
        return;
    const int token = self->m_token;
    self->finishFeedback();
    wp_presentation_destroy(self->m_presentation);
    self->m_presentation = nullptr;
    self->m_unavailableReason = QStringLiteral("wp_presentation global removed");
    emit self->availableChanged();
    if (token)
        emit self->failed(token, self->m_unavailableReason);
}

void PresentationProbe::handleClockId(void *, wp_presentation *, uint32_t)
{
}

int PresentationProbe::arm(QWindow *window)
{
    if (!m_presentation || !window || m_feedback)
        return 0;

    auto *native = QGuiApplication::platformNativeInterface();
    auto *surface = native ? native->nativeResourceForWindow(QByteArrayLiteral("surface"), window) : nullptr;
    if (!surface)
        return 0;

    m_window = window;
    m_surface = surface;
    m_token = m_nextToken++;
    // The feedback object inherits m_presentation's private queue and binds to
    // the next commit of this exact surface.
    m_feedback = wp_presentation_feedback(m_presentation, static_cast<wl_surface *>(surface));
    wp_presentation_feedback_add_listener(m_feedback, &feedbackListener, this);
    wl_display_flush(m_display);
    emit pendingChanged();

    m_dispatchTimer.start();
    if (auto *quickWindow = qobject_cast<QQuickWindow *>(window))
        quickWindow->update();
    else
        window->requestUpdate();
    return m_token;
}

void PresentationProbe::disarm()
{
    finishFeedback();
}

void PresentationProbe::dispatch()
{
    if (!m_display || !m_queue)
        return;
    if (m_window.isNull() && m_feedback) {
        const int token = m_token;
        finishFeedback();
        emit failed(token, QStringLiteral("window destroyed"));
        return;
    }
    if (wl_display_dispatch_queue_pending(m_display, m_queue) < 0) {
        const int token = m_token;
        finishFeedback();
        emit failed(token, QStringLiteral("wayland connection error"));
    }
}

void PresentationProbe::finishFeedback()
{
    m_dispatchTimer.stop();
    const bool wasPending = m_feedback != nullptr;
    if (m_feedback)
        wp_presentation_feedback_destroy(m_feedback);
    m_feedback = nullptr;
    m_surface = nullptr;
    m_window.clear();
    m_token = 0;
    if (wasPending)
        emit pendingChanged();
}

void PresentationProbe::handleSyncOutput(void *, struct wp_presentation_feedback *, struct wl_output *)
{
}

void PresentationProbe::handlePresented(void *data, struct wp_presentation_feedback *feedback, uint32_t, uint32_t, uint32_t,
                                        uint32_t, uint32_t, uint32_t, uint32_t flags)
{
    auto *self = static_cast<PresentationProbe *>(data);
    if (feedback != self->m_feedback)
        return;
    const int token = self->m_token;
    self->finishFeedback();
    emit self->presented(token, flags);
}

void PresentationProbe::handleDiscarded(void *data, struct wp_presentation_feedback *feedback)
{
    auto *self = static_cast<PresentationProbe *>(data);
    if (feedback != self->m_feedback)
        return;
    const int token = self->m_token;
    self->finishFeedback();
    emit self->discarded(token);
}
