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

This is a standard DMS plugin. Clone the repo somewhere DMS scans for plugins, or symlink it:

```bash
git clone https://github.com/rollecode/dms-gaming-status.git \
  ~/.config/quickshell/dms/plugins/gaming-status
```

Then enable the plugin from DMS settings.

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

## Adding more games

Edit `GameDetector.js`, append to `KNOWN_GAMES`:

```javascript
{ match: "yourgame.exe", name: "Your Game", icon: "videogame_asset" }
```

`match` is a lowercase substring matched against the cmdline. `icon` is any [Material Symbols](https://fonts.google.com/icons) name.

## License

MIT - see [LICENSE](LICENSE).
