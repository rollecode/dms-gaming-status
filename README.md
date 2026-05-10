<h1 align="center">Gaming Status</h1>

<p align="center">
  <strong>Real-time gaming telemetry for DankMaterialShell</strong>
</p>

<p align="center">
  <a href="#what-is-gaming-status">What is it?</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#configuration">Configuration</a> &bull;
  <a href="#how-it-works">How it works</a>
</p>

---

## What is Gaming Status?

Gaming Status is a DankMaterialShell plugin that puts a small gaming-aware pill in your DankBar. It tells you at a glance:

- whether a game is running (Wine, Proton, native), and which one
- whether `gamemode` is active
- how much RAM and swap is in use
- the current CPU governor

It is built for the same use case as Agent Notch (this repo's sibling): a non-intrusive top-bar indicator that surfaces system state without launching a separate monitor.

## Features

### Active game detection

Matches running processes against a list of known game executables (`TS4_x64.exe`, `bg3.exe`, `Overwatch.exe`, `cs2`, `factorio`, `minecraft`, etc.). Unknown Wine `.exe` processes show as a generic "Wine game" with the binary name.

### Gamemode awareness

Polls `gamemoded -s` and shows whether `gamemode` is currently optimising the CPU/IO for a game.

### Memory pressure

Reads `free -m` and computes a 3-level pressure indicator (healthy / warning / critical) based on available RAM and swap usage. The bar pill turns orange or red when pressure crosses thresholds, even if no game is running.

### CPU governor

Reads `/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` and shows the current governor in the popout. Useful on machines that lock to `performance` system-wide.

### Native popout

Click the bar pill for a popout with the full breakdown: active game, PID, exe name, RAM/swap usage with absolute and percentage values, gamemode state, governor.

### Lightweight

No daemons, no extra processes. Polls a few `ps`/`free`/`gamemoded` commands every N seconds (default 5 s, configurable 2-30 s).

## Installation

DMS reads plugins from `~/.config/DankMaterialShell/plugins/`. Clone or symlink the repo there as `gamingStatus` (the id from `plugin.json`):

```bash
git clone https://github.com/rollecode/dms-gaming-status.git ~/Projects/dms-gaming-status
ln -s ~/Projects/dms-gaming-status ~/.config/DankMaterialShell/plugins/gamingStatus
```

Then open DMS Settings -> Plugins and enable "Gaming Status".

## Configuration

In DMS settings -> Plugins -> Gaming Status:

- **Poll interval** (default 5 s) - how often to scan
- **Show game name** (default on) - display the active game name in the bar
- **Show RAM badge** (default on) - show a compact RAM% badge when a game runs or memory pressure rises

## How it works

Three QML `Process` jobs poll on a timer:

1. `ps -e -o pid=,args=` - find game processes by matching cmdline against `KNOWN_GAMES` in `GameDetector.js`.
2. `gamemoded -s` - check if gamemode is currently active.
3. `free -m` and `cat /sys/.../scaling_governor` - memory and governor state.

Results feed into a few QML properties; the bar pill and popout rebind reactively. No persistent process is started.

## Auto-discovery (zero-touch)

The plugin discovers installed games from every common launcher on Linux, so you don't have to type process names by hand. Sources scanned every hour:

- **Steam** (native, .deb / Arch package install) - `~/.local/share/Steam` and `~/.steam/steam`
- **Steam (Flatpak)** - `~/.var/app/com.valvesoftware.Steam/data/Steam`
- **Lutris** - `~/.config/lutris/games/*.yml` (and the Flatpak path)
- **Heroic** - `~/.config/heroic/store_cache/*.json` (Epic, GOG, Amazon libraries; needs `python3`)

For each source the plugin pulls the user-friendly game title and the install path or executable name, so when you launch any installed game the bar pill shows the proper title automatically. If none of these match, the plugin falls back to the running .exe basename (`Wine game`).

## Adding more games manually (rarely needed)

If a game lives outside Steam/Lutris/Heroic, open DMS Settings -> Plugins -> Gaming Status -> click the caret next to "Gaming Status". The "Custom games" section has a form: **Display name** + **Process name**. Add a row and it's used immediately.

The easiest way to find the process name: launch the game once, click this plugin's bar pill, and the popout shows `PID #### - <process_name>` for whatever is running. There's also an **"Add to my games"** button in the popout when an unidentified Wine .exe is detected - one click saves it.

Custom games are saved per-user in `~/.config/DankMaterialShell/plugin_settings.json` under the `gamingStatus.customGames` key. Built-in games and auto-discovered ones are always active in addition.

## License

MIT - see [LICENSE](LICENSE).
