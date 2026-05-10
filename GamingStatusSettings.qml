import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "gamingStatus"

    StyledText {
        width: parent.width
        text: "Gaming Status"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Real-time gaming telemetry for your DankBar. Detects active games (Wine + native), gamemode state, RAM/swap pressure, and CPU governor. Click the bar pill to expand a popout with detail."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "pollInterval"
        label: "Poll interval"
        description: "How often to scan for games and refresh memory stats (seconds)"
        defaultValue: 5
        minimum: 2
        maximum: 30
        unit: "s"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "showGameName"
        label: "Show game name"
        description: "Display the active game name in the bar (Sims 4, BG3, etc.)"
        defaultValue: true
        leftIcon: "label"
    }

    ToggleSetting {
        settingKey: "showMemBadge"
        label: "Show RAM badge"
        description: "Show a compact RAM% badge when a game is running or memory pressure is high"
        defaultValue: true
        leftIcon: "memory"
    }

    StyledText {
        width: parent.width
        text: "Detected games are matched by process name (TS4_x64.exe, bg3.exe, Overwatch.exe, etc.). Unknown Wine .exe processes are shown as 'Wine game'. To add more games, edit GameDetector.js's KNOWN_GAMES list."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
