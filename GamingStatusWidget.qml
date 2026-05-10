import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "GameDetector.js" as Detector

PluginComponent {
    id: root

    // Settings
    property int pollInterval: pluginData.pollInterval || 5
    property bool showGameName: pluginData.showGameName !== undefined ? pluginData.showGameName : true
    property bool showMemBadge: pluginData.showMemBadge !== undefined ? pluginData.showMemBadge : true
    property var customGames: pluginData.customGames || []

    // Live state
    property var activeGame: null
    property bool gamemodeActive: false
    property var memInfo: ({ totalMb: 0, usedMb: 0, availMb: 0, swapTotalMb: 0, swapUsedMb: 0 })
    property string cpuGovernor: "unknown"

    property color activeColor: "#7C4DFF"
    property color warnColor: "#FF9800"
    property color critColor: "#F44336"

    Component.onCompleted: {
        pollTimer.start()
        runAllPolls()
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
        gamemodeCheck.running = true
        memScan.running = true
        govScan.running = true
    }

    // Game-process scan
    Process {
        id: gameScan
        command: ["sh", "-c", "ps -e -o pid=,args= 2>/dev/null"]
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                gameScan.buffer += data + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.activeGame = Detector.detectGameFromCmdlines(gameScan.buffer, root.customGames)
            gameScan.buffer = ""
        }
    }

    // gamemode active state
    Process {
        id: gamemodeCheck
        command: ["sh", "-c", "gamemoded -s 2>/dev/null || echo 'gamemoded not running'"]
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                gamemodeCheck.buffer += data + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.gamemodeActive = Detector.isGamemodeActive(gamemodeCheck.buffer)
            gamemodeCheck.buffer = ""
        }
    }

    // Memory snapshot
    Process {
        id: memScan
        command: ["free", "-m"]
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                memScan.buffer += data + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.memInfo = Detector.parseFree(memScan.buffer)
            memScan.buffer = ""
        }
    }

    // CPU governor
    Process {
        id: govScan
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.cpuGovernor = data.trim() || "unknown"
            }
        }
    }

    function pressureLevel() {
        return Detector.memoryPressureLevel(root.memInfo)
    }

    function isGameActive() {
        return root.activeGame !== null
    }

    function statusIcon() {
        if (isGameActive()) {
            return root.activeGame.icon || "sports_esports"
        }
        if (pressureLevel() >= 1) return "memory"
        return "sports_esports"
    }

    function statusText() {
        if (isGameActive() && root.showGameName) {
            return root.activeGame.name
        }
        if (isGameActive()) {
            return "Playing"
        }
        return "Idle"
    }

    function statusColor() {
        if (isGameActive()) return root.activeColor
        var p = pressureLevel()
        if (p === 2) return root.critColor
        if (p === 1) return root.warnColor
        return Theme.widgetTextColor
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: root.statusIcon()
                size: Theme.barIconSize(root.barThickness)
                color: root.statusColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.statusText()
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                color: root.statusColor()
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showGameName || root.pressureLevel() >= 1
            }

            // Compact memory badge: shows "RAMxx%" only when pressure or game active
            StyledText {
                text: "RAM " + Detector.formatPercent(root.memInfo.usedMb, root.memInfo.totalMb)
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                color: root.pressureLevel() >= 1 ? root.statusColor() : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showMemBadge && (root.isGameActive() || root.pressureLevel() >= 1)
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                name: root.statusIcon()
                size: Theme.barIconSize(root.barThickness)
                color: root.statusColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Gaming Status"
            detailsText: {
                if (root.isGameActive()) {
                    var parts = [root.activeGame.name]
                    if (root.gamemodeActive) parts.push("gamemode active")
                    return parts.join(" • ")
                }
                return root.gamemodeActive ? "Gamemode active" : "No game running"
            }
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                // Game card
                StyledRect {
                    width: parent.width
                    height: gameRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: gameRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: root.statusColor()
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: root.isGameActive() ? root.activeGame.name : "No game running"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: root.statusColor()
                            }

                            StyledText {
                                text: {
                                    if (root.isGameActive()) {
                                        return "PID " + root.activeGame.pid + " • " + root.activeGame.exe
                                    }
                                    return "Waiting for a game to launch"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
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
                                    color: root.pressureLevel() >= 1 ? root.statusColor() : Theme.surfaceText
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
                                    color: root.memInfo.swapTotalMb > 0 && (root.memInfo.swapUsedMb / root.memInfo.swapTotalMb) > 0.5 ? root.warnColor : Theme.surfaceText
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

                // System card: gamemode + governor
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
                                name: root.gamemodeActive ? "speed" : "speed"
                                size: Theme.iconSize - 6
                                color: root.gamemodeActive ? root.activeColor : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: root.gamemodeActive ? "Gamemode active" : "Gamemode idle"
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.gamemodeActive ? root.activeColor : Theme.surfaceVariantText
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
