import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "gamingStatus"

    // Local working copy of the user's custom-games list. Synced from saved
    // pluginData on load and on every external change; written back via
    // saveValue("customGames", ...).
    property var customGames: []

    Component.onCompleted: {
        customGames = root.loadValue("customGames", [])
        rebuildGamesModel()
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                root.customGames = root.loadValue("customGames", [])
                root.rebuildGamesModel()
            }
        }
    }

    function rebuildGamesModel() {
        gamesListModel.clear()
        for (var i = 0; i < customGames.length; i++) {
            gamesListModel.append(customGames[i])
        }
    }

    function addCustomGame(name, match, icon) {
        var entry = {
            name: String(name).trim(),
            match: String(match).trim().toLowerCase(),
            icon: String(icon).trim() || "videogame_asset"
        }
        if (!entry.name || !entry.match) {
            ToastService.showError("Both name and match string are required")
            return
        }
        // Disallow duplicates by match string
        for (var i = 0; i < customGames.length; i++) {
            if (customGames[i].match === entry.match) {
                ToastService.showError("A custom game with that match string already exists")
                return
            }
        }
        var next = customGames.slice()
        next.push(entry)
        customGames = next
        root.saveValue("customGames", next)
        rebuildGamesModel()
    }

    function removeCustomGame(index) {
        if (index < 0 || index >= customGames.length) return
        var next = customGames.slice()
        next.splice(index, 1)
        customGames = next
        root.saveValue("customGames", next)
        rebuildGamesModel()
    }

    ListModel {
        id: gamesListModel
    }

    StyledText {
        width: parent.width
        text: "Gaming Status"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Real-time gaming telemetry for your DankBar. Detects active games (Wine + native), gamemode state, RAM/swap pressure, and CPU governor. Click the bar pill for the full breakdown."
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
        description: "Display the active game name in the bar"
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

    // Custom games manager
    StyledRect {
        width: parent.width
        height: addGameColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: addGameColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Custom games"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Add your own games to detect. Built-in entries (Sims 4, BG3, Overwatch, etc.) are always active in addition to these."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Name *"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: nameField
                        width: parent.width
                        placeholderText: "e.g., Cyberpunk 2077"
                        keyNavigationTab: matchField
                        onFocusStateChanged: hasFocus => {
                            if (hasFocus) root.ensureItemVisible(nameField)
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Match string *"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: matchField
                        width: parent.width
                        placeholderText: "e.g., cyberpunk2077.exe"
                        keyNavigationBacktab: nameField
                        keyNavigationTab: iconField
                        onFocusStateChanged: hasFocus => {
                            if (hasFocus) root.ensureItemVisible(matchField)
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Icon (optional)"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: iconField
                        width: parent.width
                        placeholderText: "videogame_asset"
                        keyNavigationBacktab: matchField
                        onFocusStateChanged: hasFocus => {
                            if (hasFocus) root.ensureItemVisible(iconField)
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                text: "Match string is a lowercase substring matched against the running process command line. Icon names come from Material Symbols (https://fonts.google.com/icons)."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankButton {
                text: "Add game"
                iconName: "add"
                onClicked: {
                    root.addCustomGame(nameField.text, matchField.text, iconField.text)
                    nameField.text = ""
                    matchField.text = ""
                    iconField.text = ""
                }
            }
        }
    }

    // Existing custom-games list
    StyledRect {
        width: parent.width
        height: Math.max(80, gamesColumn.implicitHeight + Theme.spacingL * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: gamesColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            StyledText {
                text: "Configured custom games (" + gamesListModel.count + ")"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Repeater {
                model: gamesListModel

                delegate: StyledRect {
                    width: gamesColumn.width
                    height: row.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer

                    Row {
                        id: row
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingM

                        DankIcon {
                            name: model.icon || "videogame_asset"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: model.name
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "matches: " + model.match
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        Item {
                            width: row.width - x - removeButton.width - Theme.spacingS
                            height: 1
                        }

                        DankButton {
                            id: removeButton
                            text: "Remove"
                            iconName: "delete"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.removeCustomGame(index)
                        }
                    }
                }
            }

            StyledText {
                visible: gamesListModel.count === 0
                width: parent.width
                text: "No custom games yet. Add one above."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
