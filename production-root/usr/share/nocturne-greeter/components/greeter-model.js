.pragma library

// Pure parsers for the pre-login identity model. Inputs come from root-owned
// files (/etc/passwd, /etc/login.defs, the session catalog written by
// nocturne-greeter-sessions) and the greeter's own state file. Nothing here
// executes anything; callers decide what to launch.

const NON_LOGIN_SHELLS = ["/usr/bin/nologin", "/sbin/nologin", "/usr/sbin/nologin", "/bin/false", "/usr/bin/false", "/bin/true", "/usr/bin/true"];
const NAME_PATTERN = /^[a-z_][a-z0-9_.-]{0,31}\$?$/;
const ID_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;
const DESKTOP_NAME_PATTERN = /^[A-Za-z0-9._-]{1,64}$/;

function parseLoginDefs(text) {
    const range = { uidMin: 1000, uidMax: 60000 };
    const lines = (text || "").split("\n");
    for (let i = 0; i < lines.length; ++i) {
        const match = /^\s*(UID_MIN|UID_MAX)\s+(\d+)\s*$/.exec(lines[i]);
        if (!match)
            continue;
        const value = Number(match[2]);
        if (match[1] === "UID_MIN")
            range.uidMin = value;
        else
            range.uidMax = value;
    }
    if (range.uidMin < 1 || range.uidMax < range.uidMin)
        return { uidMin: 1000, uidMax: 60000 };
    return range;
}

function parsePasswd(text, uidMin, uidMax) {
    const users = [];
    const seen = {};
    const lines = (text || "").split("\n");
    for (let i = 0; i < lines.length; ++i) {
        const fields = lines[i].split(":");
        if (fields.length !== 7)
            continue;
        const name = fields[0];
        const uid = Number(fields[2]);
        const shell = fields[6].trim();
        if (!NAME_PATTERN.test(name) || seen[name])
            continue;
        if (!Number.isInteger(uid) || uid < uidMin || uid > uidMax)
            continue;
        if (shell.length === 0 || NON_LOGIN_SHELLS.indexOf(shell) !== -1)
            continue;
        const gecos = fields[4].split(",")[0].trim();
        seen[name] = true;
        users.push({ id: name, displayName: gecos.length > 0 && gecos.length <= 64 ? gecos : name });
    }
    return users;
}

function validSession(entry) {
    if (!entry || typeof entry !== "object")
        return false;
    if (typeof entry.id !== "string" || !ID_PATTERN.test(entry.id))
        return false;
    if (typeof entry.name !== "string" || entry.name.length === 0 || entry.name.length > 80 || entry.name.indexOf("\n") !== -1)
        return false;
    if (!Array.isArray(entry.command) || entry.command.length === 0 || entry.command.length > 64)
        return false;
    for (let i = 0; i < entry.command.length; ++i) {
        const arg = entry.command[i];
        if (typeof arg !== "string" || arg.length === 0 || arg.length > 4096 || arg.indexOf("\0") !== -1)
            return false;
    }
    if (entry.command[0].charAt(0) !== "/")
        return false;
    const names = entry.desktopNames || [];
    if (!Array.isArray(names))
        return false;
    for (let j = 0; j < names.length; ++j) {
        if (typeof names[j] !== "string" || !DESKTOP_NAME_PATTERN.test(names[j]))
            return false;
    }
    return entry.type === undefined || entry.type === "wayland";
}

function parseSessionCatalog(text) {
    let data;
    try {
        data = JSON.parse(text || "");
    } catch (error) {
        return [];
    }
    if (!data || data.version !== 1 || !Array.isArray(data.sessions))
        return [];
    const sessions = [];
    for (let i = 0; i < data.sessions.length; ++i) {
        const entry = data.sessions[i];
        if (!validSession(entry))
            continue;
        sessions.push({
            id: entry.id,
            name: entry.name,
            command: entry.command.slice(),
            desktopNames: (entry.desktopNames || []).slice()
        });
    }
    return sessions;
}

function sessionEnvironment(session) {
    if (!session)
        return [];
    const environment = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + session.id];
    if (session.desktopNames && session.desktopNames.length > 0)
        environment.push("XDG_CURRENT_DESKTOP=" + session.desktopNames.join(":"));
    return environment;
}

// The session's stdio is the VT; a root-owned prefix (systemd-cat) keeps
// launcher output such as uwsm's unit summary off the screen.
function sessionCommand(session, prefix) {
    if (!session || !session.command || session.command.length === 0)
        return [];
    return (prefix || []).concat(session.command);
}

function parseState(text) {
    try {
        const data = JSON.parse(text || "");
        return {
            user: typeof data.user === "string" && NAME_PATTERN.test(data.user) ? data.user : "",
            session: typeof data.session === "string" && ID_PATTERN.test(data.session) ? data.session : ""
        };
    } catch (error) {
        return { user: "", session: "" };
    }
}

function serializeState(user, session) {
    return JSON.stringify({ version: 1, user: user || "", session: session || "" }) + "\n";
}

function indexOfId(list, id) {
    for (let i = 0; i < list.length; ++i) {
        if (list[i].id === id)
            return i;
    }
    return list.length > 0 ? 0 : -1;
}

function firstLine(text) {
    const line = (text || "").split("\n")[0].trim();
    return /^[A-Za-z0-9.-]{1,64}$/.test(line) ? line : "";
}

// PAM's generic password prompt is shown with Umbra's own wording; other
// prompts (OTP, security key) keep the text PAM supplied.
function displayPrompt(text) {
    const normalized = (text || "").trim().replace(/:$/, "").trim().toLowerCase();
    if (normalized === "password" || normalized === "senha" || normalized === "enter your password")
        return "Enter your password";
    return (text || "").trim();
}

// Text a wake key contributes to the response field. Space and control keys
// only wake; command-modified keys never type.
function wakeSeedText(text, hasCommandModifier) {
    if (hasCommandModifier || !text || text.length === 0)
        return "";
    return text.charCodeAt(0) > 32 && text.charCodeAt(0) !== 127 ? text : "";
}
