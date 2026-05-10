// GameDetector.js
//
// Helpers for the Gaming Status DMS plugin.
//
// Detects whether a game is currently running, which game it is, and how
// memory/governor/gamemode look. Pure JS - all I/O happens via QML Process
// in GamingStatusWidget.qml.

.pragma library

// Known game executables (case-insensitive substring match against the
// process's binary path, NOT its full argv - that prevents false positives
// where another process mentions a game name in its arguments, e.g. earlyoom
// listing protected names in its --avoid regex).
var KNOWN_GAMES = [
    { match: "ts4_x64.exe",        name: "The Sims 4",      icon: "cottage" },
    { match: "bg3.exe",             name: "Baldur's Gate 3", icon: "auto_stories" },
    { match: "bg3_dx11.exe",        name: "Baldur's Gate 3", icon: "auto_stories" },
    { match: "overwatch.exe",       name: "Overwatch",       icon: "shield" },
    { match: "battle.net.exe",      name: "Battle.net",      icon: "shield" },
    { match: "deadspace2.exe",      name: "Dead Space 2",    icon: "rocket" },
    { match: "deadspace.exe",       name: "Dead Space",      icon: "rocket" },
    { match: "cs2",                 name: "CS2",             icon: "sports_esports" },
    { match: "csgo",                name: "CS:GO",           icon: "sports_esports" },
    { match: "dota2",               name: "Dota 2",          icon: "sports_esports" },
    { match: "factorio",            name: "Factorio",        icon: "factory" },
    { match: "stardew",             name: "Stardew Valley",  icon: "agriculture" },
    { match: "rimworld",            name: "RimWorld",        icon: "groups" },
    { match: "civ6",                name: "Civilization VI", icon: "public" },
    { match: "civ7",                name: "Civilization VII",icon: "public" },
    { match: "minecraft",           name: "Minecraft",       icon: "view_in_ar" },
    { match: "starcraft",           name: "StarCraft",       icon: "rocket_launch" }
]

// Generic fallbacks: if any of these is in cmdline and we haven't matched a
// specific game, treat the process as a generic Wine game.
var WINE_HINTS = ["TS4_x64", "wine64-preloader", "wineloader", ".exe"]

function detectGameFromCmdlines(cmdlinesText, customGames) {
    // cmdlinesText: newline-separated `pid args` lines from `ps -e -o pid=,args=`.
    // customGames: optional array of user-added games from plugin settings,
    //              same shape as KNOWN_GAMES entries: { match, name, icon }.
    // Returns: { name, icon, pid, exe } or null
    if (!cmdlinesText) return null

    // Build the combined list: user games take priority over built-ins so a
    // user can override a built-in match (e.g. rename "Overwatch" -> "OW2").
    var allGames = []
    if (Array.isArray(customGames)) {
        for (var x = 0; x < customGames.length; x++) {
            var c = customGames[x]
            if (c && c.match) {
                allGames.push({
                    match: String(c.match).toLowerCase(),
                    name: c.name || c.match,
                    icon: c.icon || "videogame_asset"
                })
            }
        }
    }
    for (var y = 0; y < KNOWN_GAMES.length; y++) {
        allGames.push(KNOWN_GAMES[y])
    }

    var lines = cmdlinesText.split("\n")
    var fallback = null

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!line || !line.trim()) continue

        var afterPid = line.replace(/^\s*\d+\s+/, "")
        var lowerLine = afterPid.toLowerCase()

        for (var j = 0; j < allGames.length; j++) {
            var g = allGames[j]
            // Match the game's exe name preceded by start/slash/whitespace and
            // followed by end/whitespace. This handles:
            //   /path/TS4_x64.exe                     direct Wine launch
            //   wine64-preloader /path/TS4_x64.exe    Steam Proton launch
            // but rejects:
            //   earlyoom --avoid '(^|/)(...|TS4_x64.exe|...)'   pipes/regex
            // because the exe substring is preceded by '|', not slash/space.
            var re = matchRegex(g.match)
            if (re.test(lowerLine)) {
                var pid = parsePid(line)
                var customCount = Array.isArray(customGames) ? customGames.length : 0
                var src = (j < customCount) ? "custom" : "builtin"
                return { name: g.name, icon: g.icon, pid: pid, exe: g.match, source: src }
            }
        }

        // Track first unknown wine .exe as fallback - any unmatched .exe path.
        if (!fallback) {
            var fallbackRe = /(^|[\s\/])([\w.-]+\.exe)(\s|$)/i
            var m = afterPid.match(fallbackRe)
            if (m && m[2]) {
                var exe = m[2]
                var pidF = parsePid(line)
                fallback = {
                    name: exe.replace(/\.exe$/i, ""),
                    icon: "videogame_asset",
                    pid: pidF,
                    exe: exe.toLowerCase(),
                    source: "wine"
                }
            }
        }
    }

    return fallback
}

// Cache of compiled regexes keyed by match string.
var _matchRegexCache = {}
function matchRegex(matchStr) {
    if (_matchRegexCache[matchStr]) return _matchRegexCache[matchStr]
    var escaped = matchStr.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    var re = new RegExp("(^|[\\s\\/])" + escaped + "(\\s|$)", "i")
    _matchRegexCache[matchStr] = re
    return re
}

function parsePid(line) {
    var m = line.match(/^\s*(\d+)/)
    return m ? parseInt(m[1]) : 0
}

function extractExeName(line) {
    var m = line.match(/([\w.\-]+\.exe)/i)
    return m ? m[1] : ""
}

// Parse `gamemoded -s` output. Returns true if "currently active".
function isGamemodeActive(output) {
    if (!output) return false
    return output.toLowerCase().indexOf("currently active") !== -1
}

// Parse `free -m` machine-readable output. Returns { totalMb, usedMb, availMb,
// swapTotalMb, swapUsedMb }.
function parseFree(output) {
    var result = { totalMb: 0, usedMb: 0, availMb: 0, swapTotalMb: 0, swapUsedMb: 0 }
    if (!output) return result

    var lines = output.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("Mem:") === 0) {
            var parts = line.split(/\s+/)
            result.totalMb = parseInt(parts[1]) || 0
            result.usedMb = parseInt(parts[2]) || 0
            result.availMb = parseInt(parts[6]) || result.totalMb - result.usedMb
        } else if (line.indexOf("Swap:") === 0) {
            var sparts = line.split(/\s+/)
            result.swapTotalMb = parseInt(sparts[1]) || 0
            result.swapUsedMb = parseInt(sparts[2]) || 0
        }
    }
    return result
}

function memoryPressureLevel(memInfo) {
    // 0 = healthy, 1 = warning, 2 = critical
    if (memInfo.totalMb === 0) return 0
    var availPct = (memInfo.availMb / memInfo.totalMb) * 100
    var swapPct = memInfo.swapTotalMb > 0 ? (memInfo.swapUsedMb / memInfo.swapTotalMb) * 100 : 0
    if (availPct < 5 || swapPct > 75) return 2
    if (availPct < 15 || swapPct > 50) return 1
    return 0
}

function formatMb(mb) {
    if (mb >= 1024) return (mb / 1024).toFixed(1) + " GiB"
    return mb + " MiB"
}

function formatPercent(num, denom) {
    if (denom === 0) return "0%"
    return Math.round((num / denom) * 100) + "%"
}
