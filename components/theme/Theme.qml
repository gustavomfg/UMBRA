pragma Singleton
import QtQuick

// Design tokens from DESIGN.md. Components read colours and families from
// here instead of repeating literals.
QtObject {
    // Colour
    readonly property color black: "#000000"
    readonly property color text: "#F2F2F3"
    readonly property color secondary: "#A6A6B0"
    readonly property color quiet: "#777781"
    readonly property color placeholder: "#92929E"
    readonly property color lilac: "#A78BFA"
    readonly property color purple: "#8B5CF6"
    readonly property color graphite: "#111116"
    readonly property color menuActive: "#1C1C24"
    readonly property color outline: "#34343D"
    readonly property color surfaceEdge: "#292930"
    // Visible (echoed) PAM responses only.
    readonly property color selection: "#5F4C88"
    readonly property color selectedText: "#FFFFFF"

    // Type
    readonly property string sans: "Adwaita Sans"
    readonly property string display: "Noto Sans"
    readonly property string mono: "Adwaita Mono"
}
