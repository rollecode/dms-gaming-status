# 🕹️ Gaming Status

Gaming-mode toggle, auto-detection of running games, RAM/swap pressure and CPU governor — all in your DankBar.

## What it does

A single bar pill that:

- toggles **Gaming mode** on / off (closes Spotify / Slack / Telegram and drops RAM caches via a tiny shell helper)
- auto-detects the active game from running processes (Wine + native), with proper names pulled from your installed game launchers
- changes color when memory is tight (orange at >85% RAM, red at >95% or swap thrashing)
- exposes a popout with the active game card, RAM and swap usage, gamemode-daemon state and CPU governor

Click the pill to open the popout; the on/off switch lives there.

## Auto-discovery (zero-touch)

The plugin scans every common launcher on Linux every hour, so launching any installed game shows the proper title in the bar without any manual setup:

| Source | Path |
|---|---|
| Steam (native install) | `~/.local/share/Steam`, `~/.steam/steam` |
| Steam (Flatpak) | `~/.var/app/com.valvesoftware.Steam/data/Steam` |
| Lutris (native + Flatpak) | `~/.config/lutris/games/*.yml` |
| Heroic — Epic / GOG / Amazon | `~/.config/heroic/store_cache/*_library.json` |

Plus a built-in fallback list (The Sims 4, Baldur's Gate 3, Overwatch, Factorio, Stardew Valley, RimWorld, Civilization VI/VII, Minecraft, StarCraft, CS2, Dota 2). If a Wine `.exe` runs that no source recognizes, the bar shows it as the executable basename, and the popout offers a one-click **Add to my games** button.

## Installation

### Via the DMS plugin browser

DMS Settings → **Plugins** → **Browse**, find **Gaming Status**, install. (Once accepted into the [DMS plugin registry](https://github.com/AvengeMedia/danklinux-plugins).)

### Manually

```bash
git clone https://github.com/rollecode/dms-gaming-status.git \
    ~/.config/DankMaterialShell/plugins/gamingStatus
dms restart
```

### Gaming Mode toggle (zero-config, optional customisation)

The toggle in the popout works out of the box: when you flip it on, the plugin runs a minimal `sync && drop_caches` (frees RAM that the kernel was using for I/O cache). No apps are killed, no services touched.

If you want richer behaviour — close Spotify / Slack / Telegram, stop a local LLM that's hogging VRAM, etc. — drop a customised script at `~/Games/gaming-mode.sh` and the plugin will use that instead. A starter template is bundled with the plugin:

```bash
mkdir -p ~/Games
cp ~/.config/DankMaterialShell/plugins/gamingStatus/gaming-mode.sh ~/Games/
chmod +x ~/Games/gaming-mode.sh
$EDITOR ~/Games/gaming-mode.sh   # edit KILL_APPS and VRAM_SERVICES
```

The starter ships with `KILL_APPS=()` and `VRAM_SERVICES=()` empty — opinion-free. Anything that needs `sudo` (like `drop_caches`) requires passwordless sudo or it'll silently no-op.

### Optional companions

For the full reliable-gaming experience the plugin assumes you already have these (the toggle and detection still work without them):

- **gamescope, mangohud, gamemode** — `pacman -S gamescope mangohud lib32-mangohud gamemode goverlay` (Arch). Set `MANGOHUD=1` in `~/.config/environment.d/gaming.conf` so every Vulkan / OpenGL game shows the overlay automatically.
- **firejail** — for an "offline / sandboxed" launcher variant. Wrap a game's launch with `firejail --quiet --noprofile --net=none -- wine ...`.
- **earlyoom** — protect the running game from OOM kills. Add the game's binary name to `--avoid` and put browsers / chat in `--prefer`.
- **CPU governor pinned to performance** — a system-wide systemd unit; set once and forget.

## Settings

Settings → **Plugins** → click the caret next to **Gaming Status**:

- **Show label** — toggle the "Gaming on / off" or active-game text in the bar pill
- **Show RAM badge** — toggle the compact `RAM xx%` badge that appears when a game runs or memory pressure rises
- **Custom games** — add games that aren't covered by built-ins or auto-discovery. Two fields: **Display name** and **Process name**. Easiest way to find a process name: launch the game once, click the bar pill, the popout shows `PID #### – <process_name>`.

Custom-game entries are stored in `~/.config/DankMaterialShell/plugin_settings.json` under `gamingStatus.customGames`.

## How it works

A single QML widget polls four cheap commands every 3 seconds:

| Job | Command |
|---|---|
| Active game | `ps -e -o pid=,args=` filtered by built-in + custom + Steam / Lutris / Heroic library entries |
| Optimization daemon state | `gamemoded -s` |
| Memory | `free -m` |
| Governor | `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` |

Library scan runs at startup and every hour after that. Detection uses a regex with path / word boundaries, so neighbouring args like `earlyoom --avoid '(^|/)(...|TS4_x64.exe|...)'` don't false-match.

## Adding new games to the built-in list

Open `GameDetector.js`, append to `KNOWN_GAMES`:

```javascript
{ match: "yourgame.exe", name: "Your Game", icon: "videogame_asset" }
```

PRs welcome.
