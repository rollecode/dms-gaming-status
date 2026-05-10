#!/usr/bin/env bash
# Gaming Mode helper for the dms-gaming-status DMS plugin.
#
#   gaming-mode.sh on      - run the configured pre-game cleanup
#   gaming-mode.sh off     - restart anything 'on' stopped
#   gaming-mode.sh status  - print memory + governor + VRAM
#
# Edit KILL_APPS and VRAM_SERVICES below to taste.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dms-gaming-status"
mkdir -p "$STATE_DIR"

# Edit this list. Empty by default - the plugin works fine without it,
# but on a low-VRAM box you typically want to free a few GB for the game.
VRAM_SERVICES=()

print_status() {
    free -h | awk '/Mem:/ {printf "  RAM:  %s used / %s total, %s available\n", $3, $2, $7}'
    free -h | awk '/Swap:/ {printf "  SWAP: %s used / %s total\n", $3, $2}'
    echo "  GOV:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=memory.used,memory.total,memory.free --format=csv,noheader 2>/dev/null \
            | awk -F', ' '{printf "  VRAM: %s used / %s total, %s free\n", $1, $2, $3}'
    fi
}

stop_vram_services() {
    : > "$STATE_DIR/restored-services"
    for svc in "${VRAM_SERVICES[@]}"; do
        if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
            echo "Stopping $svc (VRAM headroom)..."
            systemctl --user stop "$svc" || true
            echo "$svc" >> "$STATE_DIR/restored-services"
        fi
    done
}

restore_services() {
    local list="$STATE_DIR/restored-services"
    [ -s "$list" ] || return 0
    while read -r svc; do
        [ -z "$svc" ] && continue
        echo "Starting $svc..."
        systemctl --user start "$svc" || true
    done < "$list"
    : > "$list"
}

case "${1:-status}" in
    on)
        echo "Entering gaming focus mode..."
        pkill -f "spotify"  2>/dev/null || true
        pkill -f "slack"    2>/dev/null || true
        pkill -f "telegram" 2>/dev/null || true
        stop_vram_services
        sleep 1
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
        echo "Gaming mode ON."
        print_status
        ;;
    off)
        echo "Leaving gaming mode..."
        restore_services
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
