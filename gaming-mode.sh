#!/usr/bin/env bash
# Gaming Mode helper script for the dms-gaming-status DMS plugin.
#
# The plugin's bar pill toggle calls this script as:
#   $HOME/Games/gaming-mode.sh on    -> close non-essential apps, drop pagecache
#   $HOME/Games/gaming-mode.sh off   -> no-op (the CPU governor is left alone)
#   $HOME/Games/gaming-mode.sh status
#
# Apps killed when entering gaming mode (edit the list to taste):
#   - Spotify, Slack, Telegram (music + work chat that competes with the game)
#
# Apps NOT killed (typically essential or user choice):
#   - Discord (voice chat for multiplayer)
#   - Browsers, terminals, editors
#
# This script does NOT change the CPU governor. If you want the governor
# pinned to "performance", create a one-shot systemd unit instead - the
# plugin's "gamemode" daemon (auto-activated by gamemoderun) will also set
# performance for the lifetime of any libgamemode-aware game.

set -euo pipefail

MODE="${1:-status}"

print_status() {
    free -h | awk '/Mem:/ {printf "  RAM:  %s used / %s total, %s available\n", $3, $2, $7}'
    free -h | awk '/Swap:/ {printf "  SWAP: %s used / %s total\n", $3, $2}'
    echo "  GOV:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
}

case "$MODE" in
    on)
        echo "Entering gaming focus mode..."
        pkill -f "spotify"  2>/dev/null || true
        pkill -f "slack"    2>/dev/null || true
        pkill -f "telegram" 2>/dev/null || true
        sleep 1
        sync
        # Drop pagecache, dentries and inodes to free memory.
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
        echo "Gaming mode ON."
        print_status
        ;;
    off)
        echo "Gaming mode OFF."
        print_status
        ;;
    status|*)
        echo "Status:"
        print_status
        echo
        echo "Usage: $0 {on|off|status}"
        ;;
esac
