pragma Singleton
import QtQuick

// Interface copy in English and Brazilian Portuguese. The shell sets
// `language` from NOCTURNE_LANGUAGE (or LANG); PAM messages and user or
// session names are shown as received.
QtObject {
    property string language: "en"
    readonly property bool pt: language === "pt-BR"

    // Time-of-day greeting above the user name.
    function greeting(hour) {
        if (hour >= 5 && hour < 12)
            return pt ? "Bom dia," : "Good morning,";
        if (hour >= 12 && hour < 18)
            return pt ? "Boa tarde," : "Good afternoon,";
        return pt ? "Boa noite," : "Good evening,";
    }
    // The generic PAM password prompt; anything else is shown verbatim.
    function prompt(text) {
        return pt && text === "Enter your password" ? "Digite sua senha" : text;
    }
    function date(value) {
        if (!pt)
            return Qt.formatDateTime(value, "dddd, d MMMM");
        const text = Qt.locale("pt_BR").toString(value, "dddd, d 'de' MMMM");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    readonly property string pressKey: pt ? "Pressione uma tecla para entrar" : "Press a key to enter"
    readonly property string hint: pt ? "Enter para entrar  ·  Esc para voltar" : "Enter to sign in  ·  Esc to return"
    readonly property string preparing: pt ? "Preparando seu espaço" : "Preparing your space"
    readonly property string failed: pt ? "Não foi possível entrar. Tente de novo." : "Couldn't sign in. Try again."
    readonly property string capsLock: "Caps Lock"
    readonly property string signIn: pt ? "Entrar" : "Sign in"
    readonly property string peek: pt ? "Segure para mostrar a senha" : "Hold to show password"
    readonly property string power: pt ? "Energia" : "Power"
    readonly property string sleep: pt ? "Suspender" : "Sleep"
    readonly property string restart: pt ? "Reiniciar" : "Restart"
    readonly property string shutDown: pt ? "Desligar" : "Shut down"
    readonly property string unavailable: pt ? "Indisponível" : "Unavailable"
    readonly property string connected: pt ? "Conectado" : "Connected"
    readonly property string noConnection: pt ? "Sem conexão" : "No connection"
    readonly property string networkUnavailable: pt ? "Status da rede indisponível" : "Network status unavailable"
    readonly property string audioBeforeSignIn: pt ? "Áudio indisponível antes de entrar" : "Audio unavailable before sign-in"
    readonly property string session: pt ? "Sessão" : "Session"
    readonly property string user: pt ? "Usuário" : "User"
    readonly property string noUsers: pt ? "Nenhum usuário de login encontrado." : "No login users were found."
    readonly property string noSessions: pt ? "Nenhuma sessão disponível. Um administrador precisa executar nocturne-greeter-sessions." : "No sessions are available. An administrator must run nocturne-greeter-sessions."
    readonly property string presentationMissing: pt ? "Login indisponível: o módulo de apresentação não carregou. Recompile o nocturne-greeter." : "Sign-in is unavailable: the presentation module did not load. Rebuild nocturne-greeter."
}
