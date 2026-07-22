#!/usr/bin/env bash
# Gaming Mode helper. Toggled by the dms-gaming-status plugin's bar pill
# (auto-toggles on game detection). Customized for infinity:
#
#   gaming-mode.sh on      - pre-game cleanup: stop VRAM services, sweep VRAM hogs
#   gaming-mode.sh off     - restart everything 'on' stopped
#   gaming-mode.sh status  - print memory + governor + VRAM
#
# SAFETY RULES (do not weaken):
#   - Kills target exact leaf PIDs from nvidia-smi only, SIGTERM, never -9.
#   - NEVER systemctl-stop a unit derived from a process cgroup; only units
#     listed by name in VRAM_SERVICES are touched (scope-aware, user/system).
#   - The whitelist + protected-PID check keep the session (driftwm, DMS,
#     Xwayland) and the game stack unkillable. The session is sacred.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dms-gaming-status"
mkdir -p "$STATE_DIR"

KILL_APPS=("spotify" "slack" "telegram")

# Dedicated leaf services to stop for VRAM headroom (confirmed by name; the
# voice daemon is a SYSTEM unit - scope is auto-detected below).
VRAM_SERVICES=("voice-daemon.service")

# Any process holding >= this much VRAM (MiB) gets SIGTERM on 'on',
# unless whitelisted. 2048 = 2 GB.
VRAM_KILL_MB=2048

# Never kill: compositor/shell/session and the whole game stack.
# Matched case-insensitively against the full cmdline.
WHITELIST_RE='driftwm|quickshell|(^|/| )qs( |$)|dank|xwayland|swaybg|hyprlock|steam|proton|wine|pressure-vessel|reaper|gamescope|gamemoded|\.exe|steamapps|lutris|heroic'

print_status() {
    free -h | awk '/Mem:/ {printf "  RAM:  %s used / %s total, %s available\n", $3, $2, $7}'
    free -h | awk '/Swap:/ {printf "  SWAP: %s used / %s total\n", $3, $2}'
    echo "  GOV:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=memory.used,memory.total,memory.free --format=csv,noheader 2>/dev/null \
            | awk -F', ' '{printf "  VRAM: %s used / %s total, %s free\n", $1, $2, $3}'
    fi
}

svc_scope() {
    # echo user|system|none for a unit name
    if systemctl --user is-active --quiet "$1" 2>/dev/null; then echo user
    elif systemctl is-active --quiet "$1" 2>/dev/null; then echo system
    else echo none; fi
}

stop_vram_services() {
    # NO truncate here: 'on' can run twice (the DMS pill double-fires); a
    # truncate would erase the first run's restore record while the service
    # is already stopped. Only restore_services clears the file.
    local list="$STATE_DIR/restored-services"
    touch "$list"
    local svc scope
    for svc in "${VRAM_SERVICES[@]}"; do
        scope=$(svc_scope "$svc")
        case "$scope" in
            user)
                echo "Stopping $svc (user, VRAM headroom)..."
                systemctl --user stop "$svc" || true
                grep -qxF "user $svc" "$list" || echo "user $svc" >> "$list"
                ;;
            system)
                echo "Stopping $svc (system, VRAM headroom)..."
                sudo -n systemctl stop "$svc" || true
                grep -qxF "system $svc" "$list" || echo "system $svc" >> "$list"
                ;;
            *) ;;
        esac
    done
}

restore_services() {
    local list="$STATE_DIR/restored-services" scope svc
    [ -s "$list" ] || return 0
    while read -r scope svc; do
        [ -z "$svc" ] && continue
        echo "Starting $svc ($scope)..."
        if [ "$scope" = "system" ]; then
            sudo -n systemctl start "$svc" || true
        else
            systemctl --user start "$svc" || true
        fi
    done < "$list"
    : > "$list"
}

DRIFTWM_CONF="$HOME/.config/driftwm/config.toml"

realm_supports_pause() {
    # True when the RUNNING compositor binary knows [background]
    # animate_paused (our patch). Checked against /proc/<pid>/exe, not the
    # on-disk binary: after an install the old binary can still be running
    # (deleted inode), and it rejects unknown config keys with an error bar.
    local pid
    pid=$(pgrep -x driftwm | head -1)
    [ -n "$pid" ] && grep -aq 'animate_paused' "/proc/$pid/exe" 2>/dev/null
}

realm_pause() {
    # Freeze the quantum realm during gaming. With the animate_paused patch
    # in the running compositor: full pause (zero ticks, realm stays visible,
    # pans still work). Fallback for an unpatched compositor: 1 fps throttle.
    # NOTE: animate_fps = 0 means UNCAPPED in driftwm, never write 0 here.
    [ -f "$DRIFTWM_CONF" ] || return 0
    local state="$STATE_DIR/realm-settings"
    # Never snapshot an already-paused config as "original": a missed resume
    # would then restore paused values forever.
    if [ ! -s "$state" ] && ! grep -q '^animate_paused = true' "$DRIFTWM_CONF"; then
        grep -E '^animate_fps = |^animate_blur = |^animate_paused = ' "$DRIFTWM_CONF" > "$state" || true
    fi
    sed -i -E 's/^animate_fps = [0-9]+/animate_fps = 1/; s/^animate_blur = true/animate_blur = false/' "$DRIFTWM_CONF"
    if realm_supports_pause; then
        if grep -q '^animate_paused = ' "$DRIFTWM_CONF"; then
            sed -i 's/^animate_paused = .*/animate_paused = true/' "$DRIFTWM_CONF"
        else
            sed -i '/^animate_fps = /a animate_paused = true' "$DRIFTWM_CONF"
        fi
        echo "Realm animations paused (fully frozen, blur static)."
    else
        echo "Realm animations paused (shader 1 fps, blur static; full pause after next login)."
    fi
}

realm_resume() {
    local state="$STATE_DIR/realm-settings"
    local line key
    if [ -s "$state" ]; then
        while IFS= read -r line; do
            key=${line%% =*}
            sed -i -E "s/^${key} = .*/${line}/" "$DRIFTWM_CONF"
        done < "$state"
        : > "$state"
    fi
    # Sanitize regardless of snapshot state: resume must always land on a
    # running realm, even after a lost or poisoned snapshot.
    sed -i 's/^animate_paused = true/animate_paused = false/' "$DRIFTWM_CONF"
    if grep -q '^animate_fps = 1$' "$DRIFTWM_CONF"; then
        sed -i 's/^animate_fps = 1$/animate_fps = 30/' "$DRIFTWM_CONF"
    fi
    echo "Realm animations restored."
}

vram_sweep() {
    # SIGTERM every non-whitelisted process holding >= VRAM_KILL_MB MiB.
    # Source list: nvidia-smi compute apps (pure-graphics processes like the
    # compositor never appear there at all).
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    : > "$STATE_DIR/killed-processes"

    # Belt and suspenders: explicit protected PIDs on top of the regex.
    local protected=" $$ "
    local p
    for p in $(pgrep -x driftwm; pgrep -x qs; pgrep -x dms; pgrep -x Xwayland; pgrep -x swaybg) ; do
        protected+="$p "
    done

    local pid mem rest cmdline
    while IFS=',' read -r pid mem rest; do
        pid=${pid// /}; mem=${mem// /}
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$mem" =~ ^[0-9]+$ ]] || continue
        (( mem >= VRAM_KILL_MB )) || continue
        [[ "$protected" == *" $pid "* ]] && continue
        cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
        [ -z "$cmdline" ] && continue
        if printf '%s' "$cmdline" | grep -qiE "$WHITELIST_RE"; then
            echo "  keep (whitelisted): pid=$pid ${mem}MiB ${cmdline:0:70}"
            continue
        fi
        echo "  kill: pid=$pid ${mem}MiB ${cmdline:0:80}"
        kill "$pid" 2>/dev/null || true
        echo "${mem}MiB pid=$pid ${cmdline:0:120}" >> "$STATE_DIR/killed-processes"
        # Informational only (never stop units from here): if the process was
        # service-managed, Restart= may resurrect it - tell the user to add
        # the service to VRAM_SERVICES instead.
        local unit
        unit=$(grep -oE '[^/]+\.service' "/proc/$pid/cgroup" 2>/dev/null | grep -v '^user@' | tail -1 || true)
        if [ -n "$unit" ]; then
            echo "  WARNING: pid $pid belongs to $unit and may auto-restart; add it to VRAM_SERVICES" | tee -a "$STATE_DIR/killed-processes"
        fi
    done < <(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null)

    if [ -s "$STATE_DIR/killed-processes" ]; then
        notify-send -a "Gaming mode" "Freed VRAM" "$(cat "$STATE_DIR/killed-processes")" 2>/dev/null || true
    fi
}

case "${1:-status}" in
    on)
        echo "Entering gaming focus mode..."
        for app in "${KILL_APPS[@]}"; do
            pkill -f "$app" 2>/dev/null || true
        done
        stop_vram_services
        realm_pause
        sleep 1
        vram_sweep
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
        echo "Gaming mode ON."
        print_status
        ;;
    off)
        echo "Leaving gaming mode..."
        restore_services
        realm_resume
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
