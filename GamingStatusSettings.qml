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

    StyledText {
        width: parent.width
        text: "Custom games"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Built-in games (Sims 4, BG3, Overwatch, Factorio, Minecraft, etc.) are always detected. Add your own here.\n\nHow to find a process name: launch the game once, then click this plugin's bar pill - the popout shows 'PID #### - <process_name>' for whatever is running. Copy that into the Process name field."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ListSettingWithInput {
        settingKey: "customGames"
        label: ""
        description: ""
        defaultValue: []
        fields: [
            { id: "name",  label: "Display name", placeholder: "e.g. Cyberpunk 2077",     required: true, width: 240 },
            { id: "match", label: "Process name", placeholder: "e.g. cyberpunk2077.exe", required: true, width: 240 }
        ]
    }
}
