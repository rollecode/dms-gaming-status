import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "GameDetector.js" as Detector
import "SteamLibrary.js" as Steam

PluginComponent {
    id: root

    // Hardcoded - real-time process detection on Linux needs root (eBPF/netlink),
    // and 3 seconds is plenty fast for games that run for minutes/hours.
    readonly property int pollInterval: 3

    // Settings
    property bool showLabel: pluginData.showLabel !== undefined ? pluginData.showLabel : true
    property bool showMemBadge: pluginData.showMemBadge !== undefined ? pluginData.showMemBadge : true
    property var customGames: pluginData.customGames || []

    // Steam library auto-discovery: lazily populated and refreshed every hour.
    // Steam-derived entries are passed into the detector as additional matchers
    // so any installed Steam game gets recognized by name without manual entry.
    property var steamGames: []

    // Toggle state - persisted across restarts
    property bool gamingModeOn: pluginData.gamingModeOn === true

    // Live monitoring state
    property var activeGame: null
    property bool optimizationDaemonActive: false
    property var memInfo: ({ totalMb: 0, usedMb: 0, availMb: 0, swapTotalMb: 0, swapUsedMb: 0 })
    property string cpuGovernor: "unknown"

    Component.onCompleted: {
        pollTimer.start()
        steamScanTimer.start()
        runAllPolls()
        steamScan.running = true
    }

    // Re-scan Steam library every hour (cheap; library rarely changes).
    Timer {
        id: steamScanTimer
        interval: 3600 * 1000
        repeat: true
        running: false
        onTriggered: steamScan.running = true
    }

    // Discover all installed Steam games across every library folder.
    // sh oneliner: parse libraryfolders.vdf for paths, then for each path's
    // appmanifest_*.acf print "<name>\t<installdir>" lines.
    Process {
        id: steamScan
        command: ["sh", "-c", "vdf=\"$HOME/.local/share/Steam/steamapps/libraryfolders.vdf\"; [ -f \"$vdf\" ] || exit 0; awk -F'\"' '/\"path\"/{print $4}' \"$vdf\" | while read p; do for f in \"$p\"/steamapps/appmanifest_*.acf; do [ -f \"$f\" ] || continue; awk -F'\"' '/^\\t\"name\"/{n=$4} /^\\t\"installdir\"/{i=$4} END{if(n && i) printf \"%s\\t%s\\n\", n, i}' \"$f\"; done; done"]
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => { steamScan.buffer += data + "\n" } }
        onExited: (exitCode, exitStatus) => {
            var entries = []
            var lines = steamScan.buffer.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("\t")
                if (parts.length >= 2 && parts[0].trim() && parts[1].trim()) {
                    entries.push({ name: parts[0].trim(), installdir: parts[1].trim() })
                }
            }
            root.steamGames = Steam.toGameEntries(entries)
            steamScan.buffer = ""
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollInterval * 1000
        repeat: true
        running: true
        onTriggered: runAllPolls()
    }

    function runAllPolls() {
        gameScan.running = true
        daemonCheck.running = true
        memScan.running = true
        govScan.running = true
    }

    function toggleGamingMode() {
        var next = !root.gamingModeOn
        root.gamingModeOn = next
        if (root.pluginService && root.pluginService.savePluginData) {
            root.pluginService.savePluginData(root.pluginId, "gamingModeOn", next)
        }
        toggleProcess.command = ["sh", "-c", "$HOME/Games/gaming-mode.sh " + (next ? "on" : "off")]
        toggleProcess.running = true
    }

    // One-click "Add this game" from the popout when an unidentified Wine .exe
    // is currently running. Saves into pluginData.customGames so the plugin
    // recognizes it from now on.
    function addCurrentAsCustom() {
        if (!root.activeGame || !root.activeGame.exe) return
        var exe = String(root.activeGame.exe).toLowerCase()
        var displayName = exe.replace(/\.exe$/i, "")

        var current = root.customGames.slice()
        for (var i = 0; i < current.length; i++) {
            if (current[i].match === exe) return
        }
        current.push({ name: displayName, match: exe })

        root.customGames = current
        if (root.pluginService && root.pluginService.savePluginData) {
            root.pluginService.savePluginData(root.pluginId, "customGames", current)
        }
    }

    Process {
        id: toggleProcess
        command: ["true"]
        running: false
    }

    Process {
        id: gameScan
        command: ["sh", "-c", "ps -e -o pid=,args= 2>/dev/null"]
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => { gameScan.buffer += data + "\n" } }
        onExited: (exitCode, exitStatus) => {
            // Tag user-custom entries (no source) explicitly, then concat Steam
            // entries (which already have source: "steam"). The detector keeps
            // entry order = priority, so user-custom names win over Steam.
            var customs = root.customGames.map(c => Object.assign({}, c, { source: "custom" }))
            var combined = customs.concat(root.steamGames)
            root.activeGame = Detector.detectGameFromCmdlines(gameScan.buffer, combined)
            gameScan.buffer = ""
        }
    }

    Process {
        id: daemonCheck
        command: ["sh", "-c", "gamemoded -s 2>/dev/null || echo 'gamemoded not running'"]
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => { daemonCheck.buffer += data + "\n" } }
        onExited: (exitCode, exitStatus) => {
            root.optimizationDaemonActive = Detector.isGamemodeActive(daemonCheck.buffer)
            daemonCheck.buffer = ""
        }
    }

    Process {
        id: memScan
        command: ["free", "-m"]
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => { memScan.buffer += data + "\n" } }
        onExited: (exitCode, exitStatus) => {
            root.memInfo = Detector.parseFree(memScan.buffer)
            memScan.buffer = ""
        }
    }

    Process {
        id: govScan
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null"]
        running: false
        stdout: SplitParser { onRead: data => { root.cpuGovernor = data.trim() || "unknown" } }
    }

    function pressureLevel() {
        return Detector.memoryPressureLevel(root.memInfo)
    }

    function pillIcon() {
        return "sports_esports"
    }

    function pillLabel() {
        if (root.activeGame) return root.activeGame.name
        return root.gamingModeOn ? "Gaming on" : "Gaming off"
    }

    function pillColor() {
        if (root.gamingModeOn || root.activeGame) return Theme.primary
        var p = pressureLevel()
        if (p === 2) return Theme.error
        if (p === 1) return Theme.warning
        return Theme.surfaceVariantText
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: root.pillIcon()
                size: Theme.barIconSize(root.barThickness)
                color: root.pillColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showLabel
                text: root.pillLabel()
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                color: root.pillColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            // Memory badge appears only when the system is actually under pressure
            // or a game is detected - keeps the bar tidy in idle state.
            StyledText {
                visible: root.showMemBadge && (root.activeGame !== null || root.pressureLevel() >= 1)
                text: "RAM " + Detector.formatPercent(root.memInfo.usedMb, root.memInfo.totalMb)
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                color: root.pressureLevel() >= 1 ? root.pillColor() : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                name: root.pillIcon()
                size: Theme.barIconSize(root.barThickness)
                color: root.pillColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Gaming mode"
            detailsText: root.gamingModeOn ? "ON - background apps minimised" : "OFF - normal desktop"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                // Toggle card
                StyledRect {
                    width: parent.width
                    height: toggleRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: toggleRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: toggleRow.width - toggleSwitch.width - Theme.spacingM

                            StyledText {
                                text: "Gaming mode"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Closes Spotify, Slack, Telegram and frees RAM caches. Discord stays open for voice."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: toggleSwitch
                            checked: root.gamingModeOn
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: isChecked => {
                                if (isChecked !== root.gamingModeOn) {
                                    root.toggleGamingMode()
                                }
                            }
                        }
                    }
                }

                // Active game card
                StyledRect {
                    width: parent.width
                    height: gameCardCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: gameCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            id: gameRow
                            width: parent.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: root.activeGame ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: root.activeGame ? root.activeGame.name : "No game running"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: root.activeGame ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    text: root.activeGame ? "PID " + root.activeGame.pid + " - " + root.activeGame.exe : "Detector polls every " + root.pollInterval + "s"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        // Show "Add to my games" only when an unidentified Wine
                        // game is running. One click saves it as a custom game
                        // so it gets recognized properly from now on.
                        DankButton {
                            visible: root.activeGame !== null && root.activeGame.source === "wine"
                            text: "Add to my games"
                            iconName: "add"
                            onClicked: root.addCurrentAsCustom()
                        }
                    }
                }

                // Memory card
                StyledRect {
                    width: parent.width
                    height: memCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: memCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Memory"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            width: parent.width
                            spacing: 0

                            Column {
                                width: parent.width / 2
                                spacing: 2
                                StyledText {
                                    text: Detector.formatMb(root.memInfo.usedMb) + " / " + Detector.formatMb(root.memInfo.totalMb)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: root.pressureLevel() === 2 ? Theme.error : root.pressureLevel() === 1 ? Theme.warning : Theme.surfaceText
                                }
                                StyledText {
                                    text: "RAM (" + Detector.formatPercent(root.memInfo.usedMb, root.memInfo.totalMb) + " used)"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            Column {
                                width: parent.width / 2
                                spacing: 2
                                StyledText {
                                    text: Detector.formatMb(root.memInfo.swapUsedMb) + " / " + Detector.formatMb(root.memInfo.swapTotalMb)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: root.memInfo.swapTotalMb > 0 && (root.memInfo.swapUsedMb / root.memInfo.swapTotalMb) > 0.5 ? Theme.warning : Theme.surfaceText
                                }
                                StyledText {
                                    text: "Swap (" + Detector.formatPercent(root.memInfo.swapUsedMb, root.memInfo.swapTotalMb) + " used)"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }

                // System info row
                StyledRect {
                    width: parent.width
                    height: sysRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: sysRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: "speed"
                                size: Theme.iconSize - 6
                                color: root.optimizationDaemonActive ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: root.optimizationDaemonActive ? "Optimization daemon: active" : "Optimization daemon: ready"
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.optimizationDaemonActive ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: "memory"
                                size: Theme.iconSize - 6
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "Governor: " + root.cpuGovernor
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

            }
        }
    }
}
