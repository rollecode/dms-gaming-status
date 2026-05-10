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
        text: "Real-time gaming telemetry for your DankBar. Detects active games (Wine + native), Gaming mode toggle in popout, RAM/swap pressure, and CPU governor."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    SliderSetting {
        settingKey: "pollInterval"
        label: "Poll interval"
        description: "How often to scan for games and refresh memory stats"
        defaultValue: 5
        minimum: 2
        maximum: 30
        unit: "s"
    }

    ToggleSetting {
        settingKey: "showLabel"
        label: "Show label"
        description: "Display 'Gaming on/off' or active game name next to the icon"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showMemBadge"
        label: "Show RAM badge"
        description: "Show RAM% next to the pill when a game is running or memory is tight"
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ListSettingWithInput {
        settingKey: "customGames"
        label: "Custom games"
        description: "Add your own games to detect. Built-in entries (Sims 4, BG3, Overwatch, Factorio, Minecraft, etc.) are always active in addition. Match string is a lowercase substring matched against the running process binary path. Icon is any Material Symbols name."
        defaultValue: []
        fields: [
            { id: "name",  label: "Name",         placeholder: "e.g. Cyberpunk 2077",   required: true,  width: 220 },
            { id: "match", label: "Match string", placeholder: "e.g. cyberpunk2077.exe", required: true,  width: 220 },
            { id: "icon",  label: "Icon",         placeholder: "videogame_asset",       required: false, width: 160, default: "videogame_asset" }
        ]
    }
}
