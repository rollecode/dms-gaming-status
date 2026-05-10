// SteamLibrary.js
//
// Parses Steam libraryfolders.vdf and per-game appmanifest_*.acf files to
// discover installed games. Returns an array of { name, match } entries that
// drop into the same KNOWN_GAMES shape used by GameDetector.js, where match
// is the install directory (which always appears in a Steam Proton process's
// command line).
//
// Pure JS - all I/O happens via QML Process in GamingStatusWidget.qml.

.pragma library

// Parse the multi-library libraryfolders.vdf to extract every Steam library
// root path. Steam stores games under <root>/steamapps/common/<installdir>/.
function parseLibraryFolders(vdfText) {
    if (!vdfText) return []
    var paths = []
    // Lines like:    "path"        "/home/rolle/.local/share/Steam"
    var re = /"path"\s*"([^"]+)"/g
    var m
    while ((m = re.exec(vdfText)) !== null) {
        paths.push(m[1])
    }
    return paths
}

// Parse a single appmanifest_*.acf file body. Returns { name, installdir }
// or null if the file is missing required fields.
function parseAppManifest(acfText) {
    if (!acfText) return null
    var nameM = acfText.match(/"name"\s*"([^"]+)"/)
    var installM = acfText.match(/"installdir"\s*"([^"]+)"/)
    if (!nameM || !installM) return null
    return { name: nameM[1], installdir: installM[1] }
}

// Convert an array of { name, installdir } entries into the KNOWN_GAMES
// shape expected by GameDetector. Skips Proton runtimes and Steamworks
// Common Redistributables which aren't actual games.
function toGameEntries(steamGames) {
    if (!Array.isArray(steamGames)) return []
    var out = []
    for (var i = 0; i < steamGames.length; i++) {
        var g = steamGames[i]
        if (!g || !g.name || !g.installdir) continue
        if (isUtility(g.name) || isUtility(g.installdir)) continue
        out.push({
            match: g.installdir.toLowerCase(),
            name: g.name,
            icon: "videogame_asset",
            source: "steam"
        })
    }
    return out
}

function isUtility(name) {
    var lower = name.toLowerCase()
    if (lower.indexOf("proton") !== -1) return true
    if (lower.indexOf("steamworks") !== -1) return true
    if (lower.indexOf("steam linux runtime") !== -1) return true
    if (lower.indexOf("steam runtime") !== -1) return true
    if (lower.indexOf("redistributable") !== -1) return true
    return false
}
