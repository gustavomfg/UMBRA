#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "presentationprobe.h"

class NocturnePresentationPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<PresentationProbe>(uri, 1, 0, "PresentationProbe");
    }
};

#include "plugin.moc"
