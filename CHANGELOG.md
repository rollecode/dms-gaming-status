### 1.3.2: 2026-07-07

* Remove the RAM% badge from the bar pill: dedicated RAM/VRAM widgets cover that now

### 1.3.1: 2026-07-07

* Remove the popout's "Gaming mode" header and "ON/OFF" status description, redundant with the toggle card below

### 1.3.0: 2026-05-10

* Gaming Mode toggle works zero-config (drops pagecache); ~/Games/gaming-mode.sh is opt-in for richer behaviour
* Show VRAM (used / total / %) in the popout's Memory card alongside RAM and Swap
* Widen popout to 540 px so the three columns fit cleanly
* Drop opinionated app names from popout description
* Bundled gaming-mode.sh: KILL_APPS and VRAM_SERVICES arrays both empty by default

### 1.2.0: 2026-05-10

* Auto-discover installed games from Steam (native + Flatpak), Lutris, Heroic (Epic/GOG/Amazon)
* Steam library: parse libraryfolders.vdf + appmanifest_*.acf for proper game names
* Lutris: parse ~/.config/lutris/games/*.yml for native + Wine games
* Heroic: parse store_cache/*.json (uses python3 if available)
* Filter out Proton runtimes and Steamworks redistributables
* Dedupe entries from symlinked Steam paths (~/.steam/steam vs ~/.local/share/Steam)
* Detection rescans library every hour
* Match boundary regex now allows trailing slash, so Steam install paths are recognized

### 1.1.0: 2026-05-10

* Convert plugin to Gaming mode on/off toggle: bar pill state plus a switch in the popout
* Single joystick icon (sports_esports) instead of per-game icons
* Use Theme.primary / Theme.warning / Theme.error - no hardcoded colors
* Match games only against the binary path, not full argv (fixes earlyoom and similar false matches)
* Rename "Gamemode active/idle" to clearer "Optimization daemon: active/ready"
* Persist toggle state across DMS restarts via plugin data

### 1.0.0: 2026-05-10

* Initial release
* Active game detection (Wine + native) via process matching against KNOWN_GAMES list
* Built-in game list: The Sims 4, Baldur's Gate 3, Overwatch, Battle.net, Dead Space, CS2, CS:GO, Dota 2, Factorio, Stardew Valley, RimWorld, Civilization VI/VII, Minecraft, StarCraft
* Generic Wine game detection for unknown .exe processes
* Gamemode active state via gamemoded -s
* Memory pressure indicator (3 levels: healthy, warning, critical) based on RAM and swap usage
* CPU governor display in popout
* Bar pill with optional game name and RAM% badge
* Popout with active game card, memory card, system card
* Settings: poll interval, game-name toggle, RAM-badge toggle, custom-games manager
* Add custom games via settings UI (no JS editing required)
